#!/bin/bash
set -e

cd "$(dirname "$0")"
source ../gcloud_utils.sh
load_vars "PROJECT" "PROXY_APP_NAME" "REGION"

deploy_mesh_backend \
  $PROXY_APP_NAME \
  $PROJECT \
  $REGION
