#!/bin/bash
set -e


cd "$(dirname "$0")"
source ../gcloud_utils.sh
load_vars "PROJECT" "MESH_NAME" "MESH_DOMAIN_NAME" "VPC_NAME" "MESH_DNS_A_RECORD_IP"

echo_and_run gcloud config set project $PROJECT 

echo_and_run gcloud dns managed-zones create "${MESH_NAME}" \
  --description="Domain for ${MESH_DOMAIN_NAME} service mesh routes" \
  --dns-name="${MESH_DOMAIN_NAME}." \
  --networks="${VPC_NAME}" \
  --visibility=private \
  --project="${PROJECT}"

echo_and_run gcloud dns record-sets create "*.${MESH_DOMAIN_NAME}." \
  --type=A \
  --zone="${MESH_NAME}" \
  --rrdatas="${MESH_DNS_A_RECORD_IP}" \
  --ttl=3600 \
  --project="${PROJECT}"
