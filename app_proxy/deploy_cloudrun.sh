#!/bin/bash
set -e

cd "$(dirname "$0")"
source ../gcloud_utils.sh
load_vars "PROJECT" "PROXY_APP_NAME" "REGION" "VPC_NAME" "MESH_NAME" "MESH_SUBNET_NAME"
load_vars "CLOUDRUN_CLIENT_SA_NAME" "CLOUDRUN_PROXY_SA_NAME" "CLOUDBUILD_SA_NAME"

echo_and_run gcloud config set project $PROJECT

deploy_cloudrun_source \
  $PROXY_APP_NAME \
  $REGION \
  "internal" \
  $PROJECT \
  $CLOUDRUN_SA_NAME \
  $CLOUDBUILD_SA_NAME \
  $MESH_NAME \
  $VPC_NAME \
  $MESH_SUBNET_NAME

add_cloudrun_invoker \
  $PROXY_APP_NAME \
  $CLOUDRUN_CLIENT_SA_NAME \
  $PROJECT \
  $REGION