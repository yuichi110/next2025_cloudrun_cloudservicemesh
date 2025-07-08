#!/bin/bash
set -e

# Loads and validates required variables from a .env file.
load_vars() {
  # Get the directory of this script file itself, even when sourced.
  local utils_dir
  utils_dir="$(dirname "${BASH_SOURCE[0]}")"
  local env_file="$(realpath "${utils_dir}/.env")"

  # Check if the file exists.
  if [ ! -f "${env_file}" ]; then
    echo "❌ Error: .env file not found in ${utils_dir}" >&2
    exit 1
  fi

  # Source the .env file.
  source "${env_file}"

  # Validate that all required variables are now set.
  local required_vars=("$@")
  for var_name in "${required_vars[@]}"; do
    if [ -z "${!var_name}" ]; then
      echo "❌ Error: Required variable '$var_name' is not set or is empty in ${env_file} file." >&2
      exit 1
    fi
  done
}

# Echoes a command in a formatted block, then executes it.
echo_and_run() {
  # ANSI color codes and the argument list.
  local BLUE='\033[0;34m'
  local NC='\033[0m'
  local args=("$@")
  local base_command=""
  local i=0

  # 1. Extract the base command (all arguments until the first option).
  while [[ $i -lt ${#args[@]} && "${args[$i]}" != -* ]]; do
    base_command+="${args[$i]} "
    i=$((i + 1))
  done

  # --- Print the formatted command ---
  echo
  echo -e "${BLUE}#--- Executing command --------------------------------------${NC}"
  echo -e "${BLUE}#   ${base_command}${NC}"

  # 2. Loop through the remaining arguments, printing options and their values.
  while [[ $i -lt ${#args[@]} ]]; do
    local opt="${args[$i]}"
    local val=""

    # Check if the next argument is a value (doesn't start with -).
    if [[ $((i + 1)) -lt ${#args[@]} && "${args[$i+1]}" != -* ]]; then
      val="${args[$i+1]}"
      echo -e "${BLUE}#       ${opt} ${val}${NC}"
      i=$((i + 2)) # Advance past both the option and its value.
    else
      # The option is a flag with no value.
      echo -e "${BLUE}#       ${opt}${NC}"
      i=$((i + 1)) # Advance past the option.
    fi
  done

  echo -e "${BLUE}#------------------------------------------------------------${NC}"

  # --- Execute the original command ---
  "$@"

  # --- Print the bottom border ---
  echo -e "${BLUE}#------------------------------------------------------------${NC}"
}

#######################
### Service Account ###
#######################

# Creates a service account (if needed) and binds a variable number of IAM roles.
# Usage: create_sa_and_bind_roles <sa-name> <project-id> <role1> <role2> ...
create_sa_and_bind_roles() {
  # 1. Assign and validate the fixed arguments.
  local sa_name="$1"
  local project_id="$2"

  if [ -z "${sa_name}" ] || [ -z "${project_id}" ]; then
    echo "❌ Error: sa-name and project-id arguments are required." >&2
    echo "   Usage: create_sa_and_bind_roles <sa-name> <project-id> <role1> ..." >&2
    exit 1
  fi

  # Construct the full service account email address.
  local full_sa_email="${sa_name}@${project_id}.iam.gserviceaccount.com"

  # 2. Check for the service account and create it if it doesn't exist.
  echo "➡️  Checking for service account: ${full_sa_email}"
  if gcloud iam service-accounts list --filter="email=${full_sa_email}" --format="value(email)" | grep -q "."; then
    echo "Service account already exists."
  else
    echo "Service account not found. Creating..."
    echo_and_run gcloud iam service-accounts create "${sa_name}" \
      --display-name="${sa_name}" \
      --project="${project_id}"

    echo "Waiting for IAM propagation..."
    sleep 3
  fi

  # 3. Remove the first two arguments, leaving only the roles.
  shift 2
  if [ "$#" -eq 0 ]; then
      echo "No roles provided to bind. Exiting function."
      return 0
  fi

  # 4. Loop through the remaining arguments (the roles) and bind each one.
  for role in "$@"; do
    echo_and_run gcloud projects add-iam-policy-binding "${project_id}" \
      --member="serviceAccount:${full_sa_email}" \
      --role="${role}" \
      --quiet
  done

  echo
}

add_cloudrun_invoker() {
  local service_name="$1"
  local invoker_sa_name="$2"
  local project_id="$3"
  local region="$4"

  if [[ -z "$service_name" || -z "$invoker_sa_name" || -z "$project_id" || -z "$region" ]]; then
    echo "❌ Error in add_cloudrun_invoker: Missing required arguments." >&2
    echo "   Usage: add_cloudrun_invoker <service-name> <invoker-sa-name> <project-id> <region>" >&2
    return 1
  fi

  local invoker_sa_email="${invoker_sa_name}@${project_id}.iam.gserviceaccount.com"
  
  echo_and_run gcloud run services add-iam-policy-binding "${service_name}" \
    --project="${project_id}" \
    --region="${region}" \
    --member="serviceAccount:${invoker_sa_email}" \
    --role="roles/run.invoker" \
    --quiet
}


########################
### Deploy Cloud Run ###
########################

# Deploys a specific image to a Cloud Run service.
# Usage: deploy_cloudrun_image <app-name> <region> <image-uri> <sa-name> <project-id>
deploy_cloudrun_image() {
  # 1. Assign positional arguments to local variables.
  local app_name="$1"
  local region="$2"
  local image_uri="$3"
  local sa_name="$4"
  local project_id="$5"

  # 2. Validate that all required arguments were provided.
  if [ -z "${app_name}" ] || [ -z "${region}" ] || [ -z "${image_uri}" ] || [ -z "${sa_name}" ] || [ -z "${project_id}" ]; then
    echo "❌ Error: Missing required arguments." >&2
    echo "   Usage: deploy_cloudrun_image <app-name> <region> <image-uri> <sa-name> <project-id>" >&2
    exit 1
  fi

  # 3. Construct the full service account email.
  local full_sa_email="${sa_name}@${project_id}.iam.gserviceaccount.com"

  # 4. Execute the gcloud deploy command.
  echo_and_run gcloud beta run deploy "${app_name}" \
    --region "${region}" \
    --image "${image_uri}" \
    --service-account "${full_sa_email}" \
    --no-allow-unauthenticated \
    --ingress internal-and-cloud-load-balancing

  echo
}

# Deploys to Cloud Run from local source code.
# Usage: deploy_cloudrun_source <app-name> <region> <project-id> <run-sa> <build-sa> <mesh> <vpc> <subnet>
deploy_cloudrun_source() {
  # 1. Assign positional arguments to local variables.
  local app_name="$1"
  local region="$2"
  local ingress="$3"
  local project_id="$4"
  local run_sa_name="$5"
  local build_sa_name="$6"
  local mesh_name="$7"
  local vpc_name="$8"
  local subnet_name="$9"


  # 2. Validate that all required arguments were provided.
  if [ -z "${app_name}" ] || [ -z "${region}" ] || [ -z "${project_id}" ] || [ -z "${run_sa_name}" ] || \
     [ -z "${build_sa_name}" ] || [ -z "${mesh_name}" ] || [ -z "${vpc_name}" ] || [ -z "${subnet_name}" ]; then
    echo "❌ Error: Missing required arguments." >&2
    echo "   Usage: deploy_cloudrun_source <app-name> <region> <project-id> <run-sa> <build-sa> <mesh> <vpc> <subnet>" >&2
    exit 1
  fi

  # 3. Construct the full service account emails.
  local run_sa_email="${run_sa_name}@${project_id}.iam.gserviceaccount.com"
  local build_sa_email="projects/${project_id}/serviceAccounts/${build_sa_name}@${project_id}.iam.gserviceaccount.com"

  # 4. Execute the gcloud deploy command.
  echo_and_run gcloud beta run deploy "${app_name}" \
    --source ./ \
    --platform managed \
    --region "${region}" \
    --no-allow-unauthenticated \
    --ingress ${ingress} \
    --memory 2G \
    --min-instances 1 \
    --max-instances 1 \
    --concurrency 100 \
    --service-account "${run_sa_email}" \
    --build-service-account "${build_sa_email}" \
    --mesh "${mesh_name}" \
    --network "${vpc_name}" \
    --subnet "${subnet_name}" \
    --vpc-egress all 

  echo 
}

############################
### MESH BACKEND SERVICE ###
############################

# Deploys the service mesh backend components (NEG and Backend Service).
# Usage: deploy_mesh_backend <app-name> <project-id> <region>
deploy_mesh_backend() {
  # 1. Assign positional arguments to local variables.
  local app_name="$1"
  local project_id="$2"
  local region="$3"

  # 2. Validate that all required arguments were provided.
  if [ -z "${app_name}" ] || [ -z "${project_id}" ] || [ -z "${region}" ]; then
    echo "❌ Error: Missing required arguments." >&2
    echo "   Usage: deploy_mesh_backend <app-name> <project-id> <region>" >&2
    exit 1
  fi

  # 3. Define resource names based on the app name.
  local neg_name="${app_name}-mesh-neg"
  local backend_service_name="${app_name}-mesh-backendservice"

  # 4. Create the Serverless Network Endpoint Group (NEG).
  echo_and_run gcloud compute network-endpoint-groups create "${neg_name}" \
    --project="${project_id}" \
    --region="${region}" \
    --network-endpoint-type=serverless \
    --cloud-run-service="${app_name}"

  # 5. Create the global backend service.
  echo_and_run gcloud compute backend-services create "${backend_service_name}" \
    --project="${project_id}" \
    --global \
    --load-balancing-scheme=INTERNAL_SELF_MANAGED

  # 6. Bind the NEG to the backend service.
  echo_and_run gcloud compute backend-services add-backend "${backend_service_name}" \
    --project="${project_id}" \
    --global \
    --network-endpoint-group="${neg_name}" \
    --network-endpoint-group-region="${region}"

  echo 
}

#######################
### MESH HTTP ROUTE ###
#######################

# Imports an HTTP route from a dynamically generated YAML file.
# Usage: import_mesh_http_route <app-name> <domain-name> <mesh-name> <project-id>
import_mesh_http_route() {
  # 1. Assign positional arguments to local variables.
  local host_name="$1"
  local domain_name="$2"
  local mesh_name="$3"
  local project_id="$4"
  shift 4
  local app_names=("$@")

  # 2. Validate that all required arguments were provided.
  if [ -z "${host_name}" ] || [ -z "${domain_name}" ] || [ -z "${mesh_name}" ] || [ -z "${project_id}" ]; then
    echo "❌ Error: Missing required arguments." >&2
    echo "   Usage: import_mesh_http_route <app-name> <domain-name> <mesh-name> <project-id>" >&2
    exit 1
  fi

  # 3. Define resource names.
  local route_name="http-route-for-${host_name}"
  local full_host_name="${host_name}.${domain_name}"
  local mesh_resource="projects/${project_id}/locations/global/meshes/${mesh_name}"
  local backend_service_resource="projects/${project_id}/locations/global/backendServices/${app_name}-mesh-backendservice"
  local yaml_file="http_route_temp.yml"

  # 4.
  local destinations_yaml=""
  for app_name in "${app_names[@]}"; do
    destinations_yaml+="
    - serviceName: \"projects/${project_id}/locations/global/backendServices/${app_name}-mesh-backendservice\"
      weight: 1"
  done

  # 5. Create the YAML file using a here document.
  cat <<-EOF > "${yaml_file}"
name: "${route_name}"

hostnames:
- "${full_host_name}"

meshes:
- "${mesh_resource}"

rules:
- action:
    destinations:${destinations_yaml}
EOF

  echo_and_run cat ${yaml_file}

  # 5. Import the HTTP route using the generated file.
  echo_and_run gcloud network-services http-routes import "${route_name}" \
    --source="${yaml_file}" \
    --location=global

  # 6. Clean up the temporary file.
  rm "${yaml_file}"

  echo
}

#####################
### Load Balancer ###
#####################

# Creates a full Regional Internal Load Balancer stack for a Cloud Run service.
# Usage: create_regional_ilb <app-name> <region> <project-id> <vpc-name> <subnet-name>
create_regional_ilb() {
  # 1. Assign positional arguments to local variables.
  local app_name="$1"
  local region="$2"
  local project_id="$3"
  local vpc_name="$4"
  local subnet_name="$5"

  # 2. Validate that all required arguments were provided.
  if [ -z "${app_name}" ] || [ -z "${region}" ] || [ -z "${project_id}" ] || [ -z "${vpc_name}" ] || [ -z "${subnet_name}" ]; then
    echo "❌ Error: Missing required arguments." >&2
    echo "   Usage: create_regional_ilb <app-name> <region> <project-id> <vpc-name> <subnet-name>" >&2
    exit 1
  fi

  # 3. Define resource names to use throughout the function.
  local neg_name="${app_name}-ilb-neg-${region}"
  local backend_service_name="${app_name}-ilb-backendservice-${region}"
  local url_map_name="${app_name}-ilb-urlmap-${region}"
  local proxy_name="${app_name}-ilb-targetproxy-${region}"
  local forwarding_rule_name="${app_name}-ilb-forwarding-rule-${region}" # Forwarding rule name should be unique

  # 4. Create the Regional Serverless NEG.
  echo_and_run gcloud compute network-endpoint-groups create "${neg_name}" \
    --project="${project_id}" \
    --region="${region}" \
    --network-endpoint-type=serverless \
    --cloud-run-service="${app_name}"

  # 6. Create the Backend Service.
  echo_and_run gcloud compute backend-services create "${backend_service_name}" \
    --project="${project_id}" \
    --load-balancing-scheme=INTERNAL_MANAGED \
    --protocol=HTTP \
    --region="${region}" 

  # 7. Add the NEG as a backend to the Backend Service.
  echo_and_run gcloud compute backend-services add-backend "${backend_service_name}" \
    --project="${project_id}" \
    --region="${region}" \
    --network-endpoint-group="${neg_name}" \
    --network-endpoint-group-region="${region}"

  # 8. Create the URL Map.
  echo_and_run gcloud compute url-maps create "${url_map_name}" \
    --project="${project_id}" \
    --region="${region}" \
    --default-service="${backend_service_name}"

  # 9. Create the Target HTTP Proxy.
  echo_and_run gcloud compute target-http-proxies create "${proxy_name}" \
    --project="${project_id}" \
    --url-map="${url_map_name}" \
    --url-map-region="${region}" \
    --region="${region}"

  # 10. Create the Forwarding Rule to expose the ILB.
  echo_and_run gcloud compute forwarding-rules create "${forwarding_rule_name}" \
    --project="${project_id}" \
    --region="${region}" \
    --load-balancing-scheme=INTERNAL_MANAGED \
    --network="${vpc_name}" \
    --subnet="${subnet_name}" \
    --address-region="${region}" \
    --target-http-proxy="${proxy_name}" \
    --target-http-proxy-region="${region}" \
    --ports=80 \
    --allow-global-access

  echo
}

# Creates a full Global External Load Balancer stack for a Cloud Run service.
# Usage: create_global_elb <app-name> <region> <project-id>
# Note: The 'region' parameter is still required for the backend Serverless NEG.
create_global_elb() {
  # 1. Assign positional arguments to local variables.
  local app_name="$1"
  local region="$2"
  local project_id="$3"

  # 2. Validate that all required arguments were provided.
  if [ -z "${app_name}" ] || [ -z "${region}" ] || [ -z "${project_id}" ]; then
    echo "❌ Error: Missing required arguments." >&2
    echo "   Usage: create_global_elb <app-name> <region> <project-id>" >&2
    exit 1
  fi

  # 3. Define resource names to use throughout the function.
  # "gelb" stands for Global External Load Balancer
  local neg_name="${app_name}-gelb-neg-${region}"
  local backend_service_name="${app_name}-gelb-backendservice-global"
  local url_map_name="${app_name}-gelb-urlmap-global"
  local proxy_name="${app_name}-gelb-targetproxy-global"
  local forwarding_rule_name="${app_name}-gelb-forwarding-rule-global"

  # 4. Create the Regional Serverless NEG (NEGs are always regional).
  echo_and_run gcloud compute network-endpoint-groups create "${neg_name}" \
    --project="${project_id}" \
    --region="${region}" \
    --network-endpoint-type=serverless \
    --cloud-run-service="${app_name}"

  # 5. Create the Global Backend Service.
  echo_and_run gcloud compute backend-services create "${backend_service_name}" \
    --project="${project_id}" \
    --load-balancing-scheme=EXTERNAL_MANAGED \
    --protocol=HTTP \
    --global

  # 6. Add the Regional NEG as a backend to the Global Backend Service.
  echo_and_run gcloud compute backend-services add-backend "${backend_service_name}" \
    --project="${project_id}" \
    --global \
    --network-endpoint-group="${neg_name}" \
    --network-endpoint-group-region="${region}"

  # 7. Create the Global URL Map.
  echo_and_run gcloud compute url-maps create "${url_map_name}" \
    --project="${project_id}" \
    --default-service="${backend_service_name}" \
    --global

  # 8. Create the Global Target HTTP Proxy.
  echo_and_run gcloud compute target-http-proxies create "${proxy_name}" \
    --project="${project_id}" \
    --url-map="${url_map_name}" \
    --global

  # 9. Create the Global Forwarding Rule to expose the ELB.
  #    An ephemeral IP address will be automatically assigned.
  echo_and_run gcloud compute forwarding-rules create "${forwarding_rule_name}" \
    --project="${project_id}" \
    --load-balancing-scheme=EXTERNAL_MANAGED \
    --target-http-proxy="${proxy_name}" \
    --ports=80 \
    --global

  # 10. Get and display the assigned ephemeral IP address.
  local ip_address
  ip_address=$(gcloud compute forwarding-rules describe "${forwarding_rule_name}" \
    --project="${project_id}" \
    --global \
    --format="value(IPAddress)")

  echo
  echo "✅ Global External Load Balancer created successfully!"
  echo "   IP Address: ${ip_address}"
  echo "   You can now access your service at: http://${ip_address}"
  echo "   Note: It may take several minutes for the configuration to propagate."
}