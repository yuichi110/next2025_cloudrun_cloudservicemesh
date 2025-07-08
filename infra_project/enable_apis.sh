
#!/bin/bash
set -e

cd "$(dirname "$0")"
source ../gcloud_utils.sh
load_vars "PROJECT"

echo_and_run gcloud config set project $PROJECT

# Enable Service Mesh APIs
echo_and_run gcloud services enable \
    dns.googleapis.com \
    networkservices.googleapis.com \
    networksecurity.googleapis.com \
    trafficdirector.googleapis.com \
    vpcaccess.googleapis.com \
    mesh.googleapis.com

# Enable Cloud Run APIs
echo_and_run gcloud services enable \
    cloudbuild.googleapis.com \
    artifactregistry.googleapis.com \
    run.googleapis.com 
