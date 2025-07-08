#!/bin/bash
set -e

cd "$(dirname "$0")"
source ../gcloud_utils.sh
load_vars "PROJECT" "CLIENT_APP_NAME" "REGION" "CLOUDRUN_CLIENT_SA_NAME" "CLOUDBUILD_SA_NAME" "VPC_NAME" "MESH_NAME" "MESH_SUBNET_NAME"

echo_and_run gcloud config set project $PROJECT

deploy_cloudrun_source \
  $CLIENT_APP_NAME \
  $REGION \
  "internal-and-cloud-load-balancing" \
  $PROJECT \
  $CLOUDRUN_CLIENT_SA_NAME \
  $CLOUDBUILD_SA_NAME \
  $MESH_NAME \
  $VPC_NAME \
  $MESH_SUBNET_NAME
