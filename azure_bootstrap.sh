
set -ex

if [ $# -eq 0 ]
then
  echo "No ENVIRONMENT arguments supplied"
  exit 1
fi

export ENVIRONMENT=$1

if [[ "$ENVIRONMENT" =~ [^a-zA-Z0-9\ ] ]]; then
  echo "Invalid name ${ENVIRONMENT}, use alphanumeric string"
  exit 1
fi

source ./bootstrap_env.sh

function azure_login() {
  log_file='./output/login.log'
  azure login | tee ${log_file} &
  sleep 1
  token=`cat ${log_file} |grep "To sign in"| sed 's/.*code \(.*\) to authenticate.$/\1/'`

  if [ -z "${token}" ]; then
    echo 'No login token found, exit'
    exit 1
  fi

  export AZURE_CLI_TOKEN=${token}
  $(npm bin)/phantomjs ./phantom.js
}

function azure_config() {
  azure_login
  azure config mode arm
}

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
  for name in `cat ./config/public-ips.yml | yaml2json | jq -r .public_ips[]`; do
    azure network public-ip create \
      --location $LOCATION \
      --resource-group $RESOURCE_GROUP_NAME \
      --allocation-method Static \
      --name $name
  done
}

function create_vnet() {
  network_cidr=$(cat ./config/subnets.yml| yaml2json | jq -r .network.cidr)
  azure network vnet create \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $VIRTUAL_NETWORK_NAME \
    --location "$LOCATION" \
    --address-prefixes ${network_cidr}
}

function create_subnet() {
  cidr=$1
  name=$2
  azure network vnet subnet create \
    --resource-group $RESOURCE_GROUP_NAME \
    --vnet-name $VIRTUAL_NETWORK_NAME \
    --address-prefix $cidr \
    --name $name
}

function create_networks() {
  for name in `cat ./config/subnets.yml | yaml2json | jq -r .subnets[].name`; do
    cidr=`cat config/subnets.yml | yaml2json | jq -r ".subnets[]| select(.name == \"${name}\")|.cidr"`
    create_subnet $cidr $name
  done
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

function create_active_directory_app() {
  azure ad app create \
    --name "${ACTIVE_DIRECTORY_APPLICATION_NAME}" \
    --home-page "https://${ACTIVE_DIRECTORY_APPLICATION_NAME}" \
    --identifier-uris "https://${ACTIVE_DIRECTORY_APPLICATION_NAME}" \
    --password ${ACTIVE_DIRECTORY_PASSWORD} \
    --json
}

function internal_load_balancer_property() {
  name=$1
  field=$2
  cat ./config/load-balancers.yml | \
    yaml2json | \
    jq -r ".[\"load-balancers\"].internal[]|select(.name == \"${name}\")|.${field}"
}

function create_internal_load_balancers() {
  #create internal load balancers
  for internal_lb_name in $(cat ./config/load-balancers.yml | \
    yaml2json | \
    jq -r '.["load-balancers"].internal[].name'
  ); do

    frontend_internal_ip=$(internal_load_balancer_property ${internal_lb_name} frontend_internal_ip)
    frontend_subnet_name=$(internal_load_balancer_property ${internal_lb_name} frontend_subnet_name)
    frontend_port=$(internal_load_balancer_property ${internal_lb_name} frontend_port)
    backend_port=$(internal_load_balancer_property ${internal_lb_name} backend_port)
    probe_port=$(internal_load_balancer_property ${internal_lb_name} probe_port)
    probe_interval=$(internal_load_balancer_property ${internal_lb_name} probe_interval)
    probe_fail_count=$(internal_load_balancer_property ${internal_lb_name} probe_fail_count)

    frontend_pool_name=${internal_lb_name}_frontpool
    backend_pool_name=${internal_lb_name}_backpool
    load_balancer_rule_name=${internal_lb_name}_rule
    load_balancer_probe_name=${internal_lb_name}_probe
    # Create Loadbalancer
    azure network lb create $RESOURCE_GROUP_NAME $internal_lb_name $LOCATION

    # Create frontend pool
    azure network lb frontend-ip create \
      -g $RESOURCE_GROUP_NAME \
      -l $internal_lb_name \
      -n $frontend_pool_name\
      -a $frontend_internal_ip \
      -e $frontend_subnet_name \
      -m $VIRTUAL_NETWORK_NAME \
      --json

    # Create backend pool, probes and load balancing rules
    azure network lb address-pool create \
      $RESOURCE_GROUP_NAME \
      $internal_lb_name ${backend_pool_name} \
      --json

    azure network lb rule create $RESOURCE_GROUP_NAME $internal_lb_name $load_balancer_rule_name \
      -p tcp -f ${frontend_port} -b ${backend_port} \
      -t $frontend_pool_name \
      -o $backend_pool_name \
      --json

    azure network lb probe create \
      --protocol tcp \
      --port $probe_port \
      --resource-group $RESOURCE_GROUP_NAME \
      --lb-name $internal_lb_name \
      --name $load_balancer_probe_name \
      --interval $probe_interval \
      --count $probe_fail_count \
      --json
  done
}

function log_output() {
  execute_func=$1
  file_extension=$2
  eval ${execute_func} | tee "output/${execute_func}.${file_extension}"
}

azure_config
generate_password

echo "Bootstrapping Azure for ${ENVIRONMENT}..."
log_output create_resource_group json
log_output create_storage_account json
log_output create_storage_containers json
log_output create_public_ip log
log_output create_vnet log
log_output create_networks log
log_output create_active_directory_app json
log_output create_internal_load_balancers json
