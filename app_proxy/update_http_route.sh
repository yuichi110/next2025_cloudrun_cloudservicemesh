#!/bin/bash
set -e

cd "$(dirname "$0")"
source ../gcloud_utils.sh
load_vars "PROJECT" "PROXY_APP_NAME" "MESH_NAME" "MESH_DOMAIN_NAME"

echo_and_run gcloud config set project $PROJECT

import_mesh_http_route \
  $PROXY_APP_NAME \
  $MESH_DOMAIN_NAME \
  $MESH_NAME \
  $PROJECT
