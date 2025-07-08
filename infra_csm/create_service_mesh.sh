#!/bin/bash
set -e

cd "$(dirname "$0")"
source ../gcloud_utils.sh
load_vars "PROJECT" "MESH_NAME"

echo_and_run gcloud config set project $PROJECT 

YAML_FILE="mesh_temp.yml"
echo "name: ${MESH_NAME}" > "${YAML_FILE}"

echo_and_run gcloud network-services meshes import "${MESH_NAME}" \
    --source="${YAML_FILE}" \
    --location=global
    
rm "${YAML_FILE}"
