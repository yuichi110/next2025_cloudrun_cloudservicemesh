#!/bin/bash
set -e

cd "$(dirname "$0")"
source ../gcloud_utils.sh
load_vars "PROJECT" "VPC_NAME" "REGION" "MESH_SUBNET_NAME" "ALL_RUNINVOKE_SA_NAME"

echo_and_run gcloud config set project $PROJECT 

ZONE=$(gcloud compute zones list --filter="name~^${REGION}" --format="value(name)" | head -n 1)
echo_and_run gcloud compute instances create jumpbox \
    --project="${PROJECT}" \
    --zone="${ZONE}" \
    --machine-type="e2-micro" \
    --network-interface="network=${VPC_NAME},subnet=${MESH_SUBNET_NAME},no-address" \
    --image-family="ubuntu-2204-lts" \
    --image-project="ubuntu-os-cloud" \
    --service-account="${ALL_RUNINVOKE_SA_NAME}@${PROJECT}.iam.gserviceaccount.com" \
    --scopes="https://www.googleapis.com/auth/cloud-platform" \
    --shielded-secure-boot