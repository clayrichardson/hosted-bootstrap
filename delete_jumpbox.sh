#!/usr/bin/env bash
set -ex

if [ $# -eq 0 ]
then
  echo "No ENVIRONMENT arguments supplied"
  exit 1
fi

export ENVIRONMENT=$1

source ./bootstrap_env.sh
source ./azure_helpers.sh

source ${OUTPUT_DIR}/${ENVIRONMENT}_env.sh

echo "Trying to delete jumpbox for ${ENVIRONMENT}"

JUMPBOX_NIC=${ENVIRONMENT}-jumpbox-nic
JUMPBOX_USER=vcap
JB_SUBNET_NAME=jumpbox1

# Destroy the Azure VM
function delete_azure_vm(){
azure vm delete \
  --name jumpbox1 \
  --subscription $SUBSCRIPTION_ID \
  --resource-group $RESOURCE_GROUP_NAME \
  --quiet \
  --verbose
}

# Destroy jumpbox nic
function delete_jumpbox_nic() {
azure network nic delete \
  --resource-group $RESOURCE_GROUP_NAME \
  --subscription $SUBSCRIPTION_ID \
  --name $JUMPBOX_NIC \
  --quiet \
  --verbose
}

env_check
azure_login

delete_azure_vm || {
   echo "Destroying jumpbox failed"
   exit 1
}

delete_jumpbox_nic || {
   echo "Destroying jumpbox nic failed"
   exit 1
}

