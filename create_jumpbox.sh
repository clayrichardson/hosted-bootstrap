#!/usr/bin/env bash
set -ex

export ENVIRONMENT=$1

provision_script=$2

source ./bootstrap_env.sh
source ./azure_helpers.sh

source ${OUTPUT_DIR}/${ENVIRONMENT}_env.sh

echo "Trying to create a new Jumpbox VM..."

JUMPBOX_NIC=${ENVIRONMENT}-jumpbox-nic
JUMPBOX_USER=vcap
JUMPBOX_PASSWORD=$SECRET_JUMPBOX_PASSWORD
JB_SUBNET_NAME=jumpbox1
JB_IMAGE='Canonical:UbuntuServer:14.04.2-LTS:latest'
JB_VM_SIZE=Standard_D2_v2

# ssh -A $JUMPBOX_USER@$DOMAIN_LABEL.$LOCATION.cloudapp.azure.com

#Create the Azure VM
cat $SSH_PUBLIC_CERTIFICATE_FILE
function create_azure_vm(){
azure vm create \
  --name jumpbox1 \
  --nic-name $JUMPBOX_NIC \
  --location $LOCATION \
  --os-type Linux \
  --image-urn $JB_IMAGE \
  --admin-username $JUMPBOX_USER \
  --admin-password $JUMPBOX_PASSWORD \
  --vm-size $JB_VM_SIZE \
  --vnet-name $VIRTUAL_NETWORK_NAME \
  --vnet-subnet-name $JB_SUBNET_NAME \
  --storage-account-name $STORAGE_ACCOUNT_NAME \
  --subscription $SUBSCRIPTION_ID \
  --resource-group $RESOURCE_GROUP_NAME \
  --ssh-publickey-file $SSH_PUBLIC_CERTIFICATE_FILE \
  --verbose \
  --json
}


#Connect new VM's nic to the external IP
# args : name of public_ip
function connect_vm_nic_to_external_ip() {
azure network nic set \
  --resource-group $RESOURCE_GROUP_NAME \
  --public-ip-name $1 \
  --subscription $SUBSCRIPTION_ID \
  --name $JUMPBOX_NIC
}

#Change internal IP address
# args : private ip address
function change_private_ip_address() {
azure network nic set \
  --resource-group $RESOURCE_GROUP_NAME \
  --subscription $SUBSCRIPTION_ID \
  --private-ip-address $1 \
  --name $JUMPBOX_NIC
}

env_check
azure_login

function vm_creation_process() {
  create_azure_vm || {
     echo "Creating Azure VM failed"
     exit 1
  }

  echo "Waiting 2 Minutes for Azure Operations to Complete..."
  # sleep 120

  connect_vm_nic_to_external_ip jumpbox1_eip || {
     echo "Attaching NIC failed"
     exit 1
  }
  echo "Waiting 2 Minutes for Azure Operations to Complete..."
  # sleep 120

  change_private_ip_address 10.10.4.100 || {
     echo "Changing NIC Pirvate IP failed"
     exit 1
  }

  if [ -z $provision_script ]; then
    echo "No provision script provided: skipping"
    exit 0
  fi
}

vm_creation_process

eval ${provision_script}
