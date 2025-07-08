#!/bin/bash
set -e

cd "$(dirname "$0")"
source ../gcloud_utils.sh
load_vars "PROJECT" "TARGET_APP_NAME" "REGION" "VPC_NAME" "MESH_NAME" "MESH_SUBNET_NAME"
load_vars "CLOUDRUN_CLIENT_SA_NAME" "CLOUDRUN_PROXY_SA_NAME" "CLOUDRUN_TARGET_SA_NAME" "CLOUDBUILD_SA_NAME"
echo_and_run gcloud config set project $PROJECT

# Create Target 1,2,3
for i in 1 2 3
do
  deploy_cloudrun_source \
    ${TARGET_APP_NAME}${i} \
    $REGION \
    "internal" \
    $PROJECT \
    $CLOUDRUN_TARGET_SA_NAME \
    $CLOUDBUILD_SA_NAME \
    $MESH_NAME \
    $VPC_NAME \
    $MESH_SUBNET_NAME
done

# Allow Proxy to Access Target1
add_cloudrun_invoker \
  ${TARGET_APP_NAME}1 \
  $CLOUDRUN_PROXY_SA_NAME \
  $PROJECT \
  $REGION

# Allow Client to Access Target2
add_cloudrun_invoker \
  ${TARGET_APP_NAME}2 \
  $CLOUDRUN_CLIENT_SA_NAME \
  $PROJECT \
  $REGION

# Allow Client to Access Target3
add_cloudrun_invoker \
  ${TARGET_APP_NAME}3 \
  $CLOUDRUN_CLIENT_SA_NAME \
  $PROJECT \
  $REGION