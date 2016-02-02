
set -ex

if [ $# -eq 0 ]
then
  echo "No ENVIRONMENT arguments supplied"
  exit 1
fi

export ENVIRONMENT=$1
source ./bootstrap_env.sh

function azure_config() {
  azure login
  azure config mode arm
}

echo "Bootstrapping Azure for ${ENVIRONMENT}..."

function create_resource_group(){
  azure group create \
    --name $RESOURCE_GROUP_NAME \
    --subscription $SUBSCRIPTION_ID \
    --location $LOCATION \
    --json
}


function create_storage_account(){
  azure storage account create \
    --resource-group $RESOURCE_GROUP_NAME \
    --subscription $SUBSCRIPTION_ID \
    --type $STORAGE_TYPE \
    --location $LOCATION \
    --json \
    $STORAGE_ACCOUNT_NAME
}

function primary_storage_key() {
   azure storage account keys list \
     --resource-group $RESOURCE_GROUP_NAME \
     $STORAGE_ACCOUNT_NAME --json |\
     jq -r .storageAccountKeys.key1
}

function secondary_storage_key() {
   azure storage account keys list \
     --resource-group $RESOURCE_GROUP_NAME \
     $STORAGE_ACCOUNT_NAME --json |\
     jq -r .storageAccountKeys.key2
}


function create_storage_containers() {
  PRIMARY_STORAGE_KEY=$(primary_storage_key)

  azure storage container create \
    --account-name $STORAGE_ACCOUNT_NAME \
    --account-key ${PRIMARY_STORAGE_KEY} \
    --container bosh \
    --json

  azure storage container create \
    --account-name $STORAGE_ACCOUNT_NAME \
    --account-key ${PRIMARY_STORAGE_KEY} \
    --permission Blob \
    --container stemcell \
    --json

  azure storage table create \
    --account-name $STORAGE_ACCOUNT_NAME \
    --account-key ${PRIMARY_STORAGE_KEY} \
    --table stemcells \
    --json
}

function create_public_ip() {
  azure network public-ip create \
    --location $LOCATION \
    --resource-group $RESOURCE_GROUP_NAME \
    --allocation-method Static \
    --name $PUBLIC_IP_NAME \
    --json

  azure network public-ip create \
    --location $LOCATION \
    --resource-group $RESOURCE_GROUP_NAME \
    --allocation-method Static \
    --name $JUMPBOX_EXTERNAL_IP \
    --json
}

function create_vnet() {
  azure network vnet create \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $VIRTUAL_NETWORK_NAME \
    --location "$LOCATION" \
    --address-prefixes ${NETWORK_CIDR} \
    --json
}

function create_subnet() {
  cidr=$1
  name=$2
  azure network vnet subnet create \
    --resource-group $RESOURCE_GROUP_NAME \
    --vnet-name $VIRTUAL_NETWORK_NAME \
    --address-prefix $cidr \
    --name $name \
    --json
}

function create_networks() {
  create_subnet '10.10.0.0/24' bosh1
  create_subnet '10.10.64.0/24' bosh2
  create_subnet '10.10.128.0/24' bosh3

  create_subnet '10.10.4.0/24' jumpbox1
  create_subnet '10.10.5.0/24' jumpbox1

  create_subnet '10.10.16.0/24' cf1
  create_subnet '10.10.80.0/24' cf2

  create_subnet '10.10.114.0/24' diego1
  create_subnet '10.10.115.0/24' diego2
  create_subnet '10.10.116.0/24' diego3

  create_subnet '10.10.114.0/24' diego1
  create_subnet '10.10.115.0/24' diego2
  create_subnet '10.10.116.0/24' diego3

  create_subnet '10.10.32.0/24' cf-mysql1
  create_subnet '10.10.96.0/24' cf-mysql2
  create_subnet '10.10.192/24' cf-mysql3

  create_subnet '10.10.7.0/24' cf-redis1

  create_subnet '10.10.46.0/24' logsearch1
  create_subnet '10.10.110.0/24' logsearch2
  create_subnet '10.10.174.0/24' logsearch3

  create_subnet '10.10.50.0/24' firehose-nozzle1
  create_subnet '10.10.51.0/24' firehose-nozzle2

  create_subnet '10.10.129.0/24' concourse

  create_subnet '10.10.253.0/24' load-balancer
  create_subnet '10.10.254.0/24' errand

}

function generate_password() {
  export ACTIVE_DIRECTORY_PASSWORD=`pwgen -s 32 -0`
  export JUMPBOX_PASSWORD=`pwgen -s 32 -0`
  cat > output/generate_password.json << EOF
{
  active_directory_password: ${ACTIVE_DIRECTORY_PASSWORD},
  jumpbox_password: ${JUMPBOX_PASSWORD}
}
EOF
}

function create_active_directory() {
  azure ad app create \
    --name "${ACTIVE_DIRECTORY_APPLICATION_NAME}" \
    --home-page "https://${ACTIVE_DIRECTORY_APPLICATION_NAME}" \
    --identifier-uris "https://${ACTIVE_DIRECTORY_APPLICATION_NAME}" \
    --password ${ACTIVE_DIRECTORY_PASSWORD} \
    --json
}

function log_output() {
  execute_func=$1
  eval ${execute_func} | tee "output/${execute_func}.json"
  #`$execute_func`|tee "output/${execute_func}.json"
}

azure_config
generate_password

log_output create_resource_group
log_output create_storage_account
log_output create_storage_containers
log_output create_public_ip
log_output create_vnet
log_output create_networks
log_output create_active_directory
