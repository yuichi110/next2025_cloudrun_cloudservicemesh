#!/bin/bash
set -e

cd "$(dirname "$0")"
source ../gcloud_utils.sh
load_vars "PROJECT" "VPC_NAME" "REGION" "MESH_SUBNET_NAME" "MESH_IP_RANGE" "PROXY_SUBNET_NAME" "PROXY_IP_RANGE"
echo_and_run gcloud config set project $PROJECT

# Create VPC
echo_and_run gcloud compute networks create $VPC_NAME \
    --subnet-mode=custom

# Create subnet
echo_and_run gcloud compute networks subnets create $MESH_SUBNET_NAME \
    --network=$VPC_NAME \
    --range=$MESH_IP_RANGE \
    --region=$REGION \
    --enable-private-ip-google-access

echo_and_run gcloud compute networks subnets create $PROXY_SUBNET_NAME \
    --purpose=REGIONAL_MANAGED_PROXY \
    --role=ACTIVE \
    --region=$REGION \
    --network=$VPC_NAME \
    --range=$PROXY_IP_RANGE

# Create firewall rules
echo_and_run gcloud compute firewall-rules create allow-internal-traffic-within-mesh \
    --network=$VPC_NAME \
    --action=ALLOW \
    --direction=INGRESS \
    --rules=all \
    --source-ranges=${MESH_IP_RANGE},${PROXY_IP_RANGE} \
    --description="Allow all internal traffic"

echo_and_run gcloud compute firewall-rules create allow-iap-tcp-forwarding \
    --network=$VPC_NAME \
    --action=ALLOW \
    --direction=INGRESS \
    --source-ranges=35.235.240.0/20 \
    --rules=tcp \
    --description="Allow IAP traffic from Google Cloud"

echo_and_run gcloud compute firewall-rules create allow-health-checks \
    --network=$VPC_NAME \
    --action=ALLOW \
    --direction=INGRESS \
    --source-ranges=35.191.0.0/16,130.211.0.0/22 \
    --rules=tcp \
    --description="Allow health checks from Google Cloud"

