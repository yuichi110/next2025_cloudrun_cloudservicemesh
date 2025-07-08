#!/bin/bash
set -e

cd "$(dirname "$0")"
source ../gcloud_utils.sh
load_vars "PROJECT" "TARGET_APP_NAME" "MESH_NAME" "MESH_DOMAIN_NAME"

echo_and_run gcloud config set project $PROJECT

import_mesh_http_route \
  ${TARGET_APP_NAME}1 \
  $MESH_DOMAIN_NAME \
  $MESH_NAME \
  $PROJECT

echo_and_run gcloud network-services http-routes import route-target23 \
    --source=http_route_target23.yml \
    --location=global