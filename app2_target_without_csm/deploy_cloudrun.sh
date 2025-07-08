#!/bin/bash
set -e

cd "$(dirname "$0")"
source ../gcloud_utils.sh
load_vars "PROJECT" "REGION" "VPC_NAME" "MESH_SUBNET_NAME"
load_vars "ALL_RUNINVOKE_SA_NAME" "CLOUDBUILD_SA_NAME"

echo_and_run gcloud config set project $PROJECT

run_sa_email="${ALL_RUNINVOKE_SA_NAME}@${PROJECT}.iam.gserviceaccount.com"
build_sa_email="projects/${PROJECT}/serviceAccounts/${CLOUDBUILD_SA_NAME}@${PROJECT}.iam.gserviceaccount.com"

echo_and_run gcloud beta run deploy without-mesh-target \
  --source ./ \
  --platform managed \
  --region $REGION \
  --no-allow-unauthenticated \
  --ingress "internal" \
  --memory 2G \
  --min-instances 1 \
  --max-instances 1 \
  --concurrency 100 \
  --service-account "${run_sa_email}" \
  --build-service-account "${build_sa_email}" \
  --network "${VPC_NAME}" \
  --subnet "${MESH_SUBNET_NAME}" \
  --vpc-egress all 
