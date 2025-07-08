#!/bin/bash
set -e

# Move to the script's directory
cd "$(dirname "$0")"
source ../gcloud_utils.sh
load_vars "PROJECT" "CLOUDRUN_CLIENT_SA_NAME" "CLOUDRUN_PROXY_SA_NAME" "CLOUDRUN_TARGET_SA_NAME"
load_vars "CLOUDBUILD_SA_NAME" "ALL_RUNINVOKE_SA_NAME" 
load_vars "TAG_KEY" "TAG_VALUE_PROXY" "TAG_VALUE_TARGET1" "TAG_VALUE_TARGET23"

echo_and_run gcloud config set project $PROJECT 

for sa_name in $CLOUDRUN_CLIENT_SA_NAME $CLOUDRUN_PROXY_SA_NAME $CLOUDRUN_TARGET_SA_NAME
do
  create_sa_and_bind_roles $sa_name $PROJECT \
    "roles/trafficdirector.client" \
    "roles/cloudtrace.agent" \
    "roles/meshconfig.viewer" \
    "roles/monitoring.metricWriter"
done

create_sa_and_bind_roles "${CLOUDBUILD_SA_NAME}" "${PROJECT}" \
  "roles/storage.objectCreator" \
  "roles/storage.objectViewer" \
  "roles/artifactregistry.writer" \
  "roles/cloudbuild.builds.editor" \
  "roles/logging.logWriter" \
  "roles/run.admin"

create_sa_and_bind_roles "${ALL_RUNINVOKE_SA_NAME}" "${PROJECT}" \
  "roles/iam.serviceAccountTokenCreator" \
  "roles/run.invoker" \
  "roles/run.viewer"
