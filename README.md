# Cloud Run with Cloud Service Mesh Demo

This repository demonstrates how to build a microservices architecture using **Google Cloud Run** and **Cloud Service Mesh**.

The setup involves three services:
* `app-client`: A client application that makes requests.
* `app-proxy`: A proxy service that sits between the client and the target service.
* `app-target`: The final target service that processes the request.

Traffic flow is managed by Cloud Service Mesh, which controls routing between the services. An external load balancer is set up to expose the client application to the internet.

## Prerequisites

Before you begin, ensure you have the following installed and configured:
* Google Cloud SDK (`gcloud` command-line tool)
* A Google Cloud Project with billing enabled
* Permissions to create and manage the resources defined in the scripts (e.g., Project Owner, Editor)

## Setup

1.  **Clone the repository:**
    ```bash
    git clone [https://github.com/yuichi110/next2025_cloudrun_cloudservicemesh.git](https://github.com/yuichi110/next2025_cloudrun_cloudservicemesh.git)
    cd next2025_cloudrun_cloudservicemesh
    ```

2.  **Configure Environment Variables:**
    Copy the example `.env` file and edit it with your specific project details.
    ```bash
    cp .env.example .env
    ```
    Open the `.env` file and set the values for `PROJECT_ID`, `REGION`, `ZONE`, etc.

3.  **Create new project**
    Please test it on new project for avoiding useless trouble and ease of cleanup.


## Deployment Steps

Execute the following scripts in the specified order to deploy the complete infrastructure and application stack.

### 1. Foundational Infrastructure (`infra_project`)
These scripts set up the basic project configuration, including APIs, service accounts, and networking.

```bash
# Enable necessary Google Cloud APIs
./infra_project/enable_apis.sh

# Create IAM Service Accounts for the applications
./infra_project/create_service_accounts.sh

# Create a VPC, subnet, and firewall rules
./infra_project/create_vpc_subnet_firewalls.sh
```

### 2. Cloud Service Mesh (`infra_csm`)
These scripts configure the service mesh and associated DNS settings.

```bash
# Create the Cloud Service Mesh
./infra_csm/create_service_mesh.sh

# Create a private DNS zone and records for service discovery
./infra_csm/create_dns_zone_records.sh
```

### 3. Target Application (`app_target`)
Deploy the target service and configure its network routing within the mesh.

```bash
# Deploy the 'target' application to Cloud Run
./app_target/deploy_cloudrun.sh

# Create a Serverless NEG and Backend Service for the 'target' app
./app_target/create_neg_backendservice.sh

# Update the HTTP route to direct traffic to the 'target' service
./app_target/update_http_route.sh
```

### 4. Proxy Application (`app_proxy`)
Deploy the proxy service and configure its network routing.

```bash
# Deploy the 'proxy' application to Cloud Run
./app_proxy/deploy_cloudrun.sh

# Create a Serverless NEG and Backend Service for the 'proxy' app
./app_proxy/create_neg_backendservice.sh

# Update the HTTP route to direct traffic to the 'proxy' service
./app_proxy/update_http_route.sh
```

### 5. Client Application (`app_client`)
Deploy the client service and expose it via an external load balancer.

```bash
# Deploy the 'proxy' application to Cloud Run
./app_proxy/deploy_cloudrun.sh

# Create a Serverless NEG and Backend Service for the 'proxy' app
./app_proxy/create_neg_backendservice.sh

# Update the HTTP route to direct traffic to the 'proxy' service
./app_proxy/update_http_route.sh
```

After completing these steps, the demo environment will be fully deployed and accessible.

## Cleanup
Please shutdown the project.
