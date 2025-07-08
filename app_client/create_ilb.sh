#!/bin/bash
set -e

cd "$(dirname "$0")"
source ../gcloud_utils.sh
load_vars "PROJECT" "CLIENT_APP_NAME" "REGION" "VPC_NAME" "MESH_SUBNET_NAME"

echo_and_run gcloud config set project $PROJECT

create_regional_ilb \
  $CLIENT_APP_NAME \
  $REGION \
  $PROJECT \
  $VPC_NAME \
  $MESH_SUBNET_NAME
