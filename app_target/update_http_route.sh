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
  $PROJECT \
  ${TARGET_APP_NAME}1

import_mesh_http_route \
  ${TARGET_APP_NAME}23 \
  $MESH_DOMAIN_NAME \
  $MESH_NAME \
  $PROJECT \
  ${TARGET_APP_NAME}2 \
  ${TARGET_APP_NAME}3