#!/bin/bash
set -e

cd "$(dirname "$0")"
source ../gcloud_utils.sh
load_vars "PROJECT" "TARGET_APP_NAME" "REGION"

# Create Neg and BackendService for Clous Mesh
for i in 1 2 3
do
  deploy_mesh_backend \
    ${TARGET_APP_NAME}${i} \
    $PROJECT \
    $REGION
done