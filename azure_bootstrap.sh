set -ex

if [ $# -eq 0 ]
then
  echo "No ENVIRONMENT arguments supplied"
  exit 1
fi

export ENVIRONMENT=$1

source ./bootstrap_env.sh
source ./azure_helpers.sh
mkdir -p ${OUTPUT_DIR}

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
    jq -r .key1
}

function secondary_storage_key() {
  azure storage account keys list \
    --resource-group $RESOURCE_GROUP_NAME \
    $STORAGE_ACCOUNT_NAME --json |\
    jq -r .key2
}

function get_storage_keys() {
  cat << EOF
{
  "primary_storage_key": "$(primary_storage_key)",
  "secondary_storage_key": "$(secondary_storage_key)"
}
EOF
}

function test_create_storage_container() {
  local name=$1
  PRIMARY_STORAGE_KEY=$(primary_storage_key)

  local exist=$(azure storage container list \
    --account-name ${STORAGE_ACCOUNT_NAME} \
    --account-key ${PRIMARY_STORAGE_KEY} \
    --json | jq -r ".[]|select(.name == \"${name}\").name")

  if [ "$exist" == "" ]; then
    return 1
  else
    return 0
  fi
}

function test_create_storage_table() {
  local name=$1
  PRIMARY_STORAGE_KEY=$(primary_storage_key)

  local exist=$(azure storage table list \
    --account-name ${STORAGE_ACCOUNT_NAME} \
    --account-key ${PRIMARY_STORAGE_KEY} \
    --json | jq -r ".[]|select(.name == \"${name}\").name")

  if [ "$exist" == "" ]; then
    return 1
  else
    return 0
  fi
}

function create_storage_container() {
  local container=$1
  PRIMARY_STORAGE_KEY=$(primary_storage_key)
  azure storage container create \
    --account-name $STORAGE_ACCOUNT_NAME \
    --account-key ${PRIMARY_STORAGE_KEY} \
    --container $container \
    --json
}

function create_storage_table() {
  local table=$1
  PRIMARY_STORAGE_KEY=$(primary_storage_key)
  azure storage table create \
      --account-name $STORAGE_ACCOUNT_NAME \
      --account-key ${PRIMARY_STORAGE_KEY} \
      --table $table \
      --json
}


function test_create_public_ip() {
  local name=$1
  local exist=$(azure network public-ip list \
    --resource-group $RESOURCE_GROUP_NAME \
    --json | jq -r ".[]|select(.name == \"${name}\").name")

  if [ "$exist" == "" ]; then
    return 1
  else
    return 0
  fi
}


function create_public_ip() {
  local name=$1
  azure network public-ip create \
    --location $LOCATION \
    --resource-group $RESOURCE_GROUP_NAME \
    --allocation-method Static \
    --name $name
}

function get_public_ips() {
  # this function is to work around the azure cli bug of empty json
  azure network public-ip list \
    --resource-group $RESOURCE_GROUP_NAME \
    --json
}

function test_create_vnet() {
  local cidr=$1
  local existing_cidrs=$(azure network vnet list \
    --resource-group $RESOURCE_GROUP_NAME --json \
    | jq -r '.[].addressSpace.addressPrefixes[]')

  if [ "$(echo $existing_cidrs | grep -i $cidr)" == '' ]; then
    return 1
  fi
  return 0
}

function create_vnet() {
  local network_cidr=$1
  azure network vnet create \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $VIRTUAL_NETWORK_NAME \
    --location "$LOCATION" \
    --address-prefixes ${network_cidr}
}

function test_create_subnet() {
  local name=$1

  local exist=$(azure network vnet subnet list \
    --resource-group $RESOURCE_GROUP_NAME \
    --vnet-name $VIRTUAL_NETWORK_NAME \
    --json | jq -r ".[]|select (.name == \"${name}\")|.name")

  if [ "$exist" == "" ]; then
    return 1
  else
    return 0
  fi
}

function create_subnet() {
  local cidr=$1
  local name=$2
  azure network vnet subnet create \
    --resource-group $RESOURCE_GROUP_NAME \
    --vnet-name $VIRTUAL_NETWORK_NAME \
    --address-prefix $cidr \
    --name $name
}


function create_networks() {
  subnet_names=`cat ./config/subnets.yml | ./yaml2json | jq -r .subnets[].name`
  for name in $subnet_names; do
    local cidr=`cat config/subnets.yml | ./yaml2json | jq -r ".subnets[]| select(.name == \"${name}\")|.cidr"`
    test_create_subnet $name || log_output "create_subnet $cidr $name" log
  done
}

function generate_ssh_certs() {
  local cert_file="${SSH_PRIVATE_CERTIFICATE_FILE}"
  if [ ! -e $cert_file ]; then
    ssh-keygen -q -t rsa -f ${SSH_PRIVATE_CERTIFICATE_FILE} -N "" -C "${ENVIRONMENT} admin: ${SECRET_ADMIN_EMAIL}"
  fi
}

function generate_password() {
  local password_file="${OUTPUT_DIR}/generate_password.json"
  if [ ! -e $password_file ]; then
    local secret_active_directory_password=`pwgen -s 32 -0`
    local secret_jumpbox_password="$(pwgen -s -n -c -B 31)*"
    local secret_bosh_password=`pwgen -s 32 -0`
    local secret_concourse_password=`pwgen -s 32 -0`
    local secret_cc_admin_password=`pwgen -s 32 -0`
    cat > ${OUTPUT_DIR}/generate_password.json << EOF
{
  "secret_active_directory_app_client_password": "${secret_active_directory_password}",
  "secret_jumpbox_password": "${secret_jumpbox_password}",
  "secret_bosh_password": "${secret_bosh_password}",
  "secret_concourse_password": "${secret_concourse_password}",
  "secret_cc_admin_password": "${secret_cc_admin_password}"
}
EOF
   fi
}

function test_create_active_directory_app() {
  local app=${ACTIVE_DIRECTORY_APPLICATION_NAME}
  local existing_app=$(azure ad app list --json|jq -r .[].displayName)

  if [ "$(echo $existing_app | grep -i $app)" == '' ]; then
    return 1
  fi
  return 0

}

function create_active_directory_app() {
  local password=$(cat ${OUTPUT_DIR}/generate_password.json | jq -r ".secret_active_directory_app_client_password")
  azure ad app create \
    --name "${ACTIVE_DIRECTORY_APPLICATION_NAME}" \
    --home-page "https://${ACTIVE_DIRECTORY_APPLICATION_NAME}" \
    --identifier-uris "https://${ACTIVE_DIRECTORY_APPLICATION_NAME}" \
    --password ${password} \
    --json
}

function get_application_id() {
  cat ${OUTPUT_DIR}/create_active_directory_app.json | \
    jq -r ".appId"
}

function test_create_service_principle() {
  local client_id=$(get_application_id)
  local existing_app_ids=$(azure ad sp list --json|jq -r .[].appId)

  if [ "$(echo $existing_app_ids | grep -i $client_id)" == '' ]; then
    return 1
  fi
  return 0
}


function create_service_principle() {
  local client_id=$(get_application_id)
  azure ad sp create \
    --applicationId "${client_id}" \
    --json
}

function test_create_role_assignment() {
  local existing_roles_name=$(azure role assignment list --json | jq -r .[].properties.aADObject.displayName)
  local ad_app_name=${ACTIVE_DIRECTORY_APPLICATION_NAME}

  if [ "$(echo $existing_roles_name | grep -i $ad_app_name)" == '' ]; then
    return 1
  fi
  return 0
}

function create_role_assignment() {
  azure role assignment create \
    --roleName "Contributor" \
    --spn "https://${ACTIVE_DIRECTORY_APPLICATION_NAME}" \
    --subscription ${SUBSCRIPTION_ID} \
    --json
}

function internal_load_balancer_property() {
  name=$1
  field=$2
  cat ./config/load-balancers.yml | \
    ./yaml2json | \
    jq -r ".[\"load-balancers\"].internal[]|select(.name == \"${name}\")|.${field}"
}

function test_create_internal_load_balancer() {
  local lb=$1
  local existing_lb=$(azure network lb list -g $RESOURCE_GROUP_NAME --json| jq -r .[].name)
  if [ "$(echo $existing_lb | grep -i $lb)" == '' ]; then
    return 1
  fi
  return 0
}

function create_internal_load_balancer() {
  local internal_lb_name=$1
  azure network lb create $RESOURCE_GROUP_NAME $internal_lb_name $LOCATION
}

function test_create_load_balancer_frontend_ip() {
  local internal_lb_name=$1
  local existing_frontend_name=$(azure network lb frontend-ip list \
    -g $RESOURCE_GROUP_NAME \
    -l $internal_lb_name \
    --json| jq .[].name)

  local frontend_pool_name=${internal_lb_name}_frontpool

  if [ "$(echo $existing_frontend_name | grep -i $frontend_pool_name)" == '' ]; then
    return 1
  fi
  return 0

}

function create_load_balancer_frontend_ip() {
  local internal_lb_name=$1

  local frontend_internal_ip=$(internal_load_balancer_property ${internal_lb_name} frontend_internal_ip)
  local frontend_subnet_name=$(internal_load_balancer_property ${internal_lb_name} frontend_subnet_name)
  local frontend_port=$(internal_load_balancer_property ${internal_lb_name} frontend_port)
  local frontend_pool_name=${internal_lb_name}_frontpool

  azure network lb frontend-ip create \
    -g $RESOURCE_GROUP_NAME \
    -l $internal_lb_name \
    -n $frontend_pool_name\
    -a $frontend_internal_ip \
    -e $frontend_subnet_name \
    -m $VIRTUAL_NETWORK_NAME \
    --json
}

function test_create_load_balancer_backend_pool() {
  local internal_lb_name=$1
  local backend_pool_name=${internal_lb_name}_backpool
  local existing_backend_pool=$(azure network lb address-pool list $RESOURCE_GROUP_NAME $internal_lb_name --json | jq .[].name)
  if [ "$(echo $existing_backend_pool | grep -i $backend_pool_name)" == '' ]; then
    return 1
  fi
  return 0
}

function create_load_balancer_backend_pool() {
  local internal_lb_name=$1
  local backend_pool_name=${internal_lb_name}_backpool
  azure network lb address-pool create \
    $RESOURCE_GROUP_NAME \
    $internal_lb_name ${backend_pool_name} \
    --json
}

function test_create_load_balancer_rule() {
  local internal_lb_name=$1
  local load_balancer_rule_name=${internal_lb_name}_rule
  local existing_rule=$(azure network lb rule list $RESOURCE_GROUP_NAME $internal_lb_name --json | jq .[].name)
  if [ "$(echo $existing_rule | grep -i $load_balancer_rule_name)" == '' ]; then
    return 1
  fi
  return 0
}

function create_load_balancer_rule() {
  local internal_lb_name=$1

  local load_balancer_rule_name=${internal_lb_name}_rule
  local frontend_port=$(internal_load_balancer_property ${internal_lb_name} frontend_port)
  local backend_port=$(internal_load_balancer_property ${internal_lb_name} backend_port)

  local frontend_pool_name=${internal_lb_name}_frontpool
  local backend_pool_name=${internal_lb_name}_backpool

  azure network lb rule create $RESOURCE_GROUP_NAME $internal_lb_name $load_balancer_rule_name \
    -p tcp -f ${frontend_port} -b ${backend_port} \
    -t $frontend_pool_name \
    -o $backend_pool_name \
    --json
}

function test_create_load_balancer_probe() {
  local internal_lb_name=$1
  local load_balancer_probe_name=${internal_lb_name}_probe
  local existing_probe=$(azure network lb probe list $RESOURCE_GROUP_NAME $internal_lb_name --json | jq .[].name)
  if [ "$(echo $existing_probe | grep -i $load_balancer_probe_name)" == '' ]; then
    return 1
  fi
  return 0
}

function create_load_balancer_probe() {
  local internal_lb_name=$1

  local probe_port=$(internal_load_balancer_property ${internal_lb_name} probe_port)
  local probe_interval=$(internal_load_balancer_property ${internal_lb_name} probe_interval)
  local probe_fail_count=$(internal_load_balancer_property ${internal_lb_name} probe_fail_count)
  local load_balancer_probe_name=${internal_lb_name}_probe

  azure network lb probe create \
    --protocol tcp \
    --port $probe_port \
    --resource-group $RESOURCE_GROUP_NAME \
    --lb-name $internal_lb_name \
    --name $load_balancer_probe_name \
    --interval $probe_interval \
    --count $probe_fail_count \
    --json
}

env_check
azure_login
generate_password
generate_ssh_certs

echo "Bootstrapping Azure for ${ENVIRONMENT}..."
log_output create_resource_group json
log_output create_storage_account json

for storage_container in bosh stemcell; do
  test_create_storage_container ${storage_container} || log_output "create_storage_container ${storage_container}" json
done

for storage_table in stemcells; do
  test_create_storage_table ${storage_table} || log_output "create_storage_table ${storage_table}" json
done

for public_ip in `cat ./config/public-ips.yml | ./yaml2json | jq -r .public_ips[]`; do
  test_create_public_ip ${public_ip} || log_output "create_public_ip ${public_ip}" log
done

vnet_cidr=$(cat ./config/subnets.yml| ./yaml2json | jq -r .network.cidr)
test_create_vnet ${vnet_cidr} || log_output "create_vnet ${vnet_cidr}" log

create_networks

test_create_active_directory_app || log_output create_active_directory_app json

# HACK: NEED to wait for a while before role assignment, reason unknown
test_create_service_principle || (log_output create_service_principle json && sleep 60)

test_create_role_assignment || log_output create_role_assignment json

for internal_lb_name in $(cat ./config/load-balancers.yml | \
  ./yaml2json | \
  jq -r '.["load-balancers"].internal[].name'
); do
  test_create_internal_load_balancer $internal_lb_name || log_output "create_internal_load_balancer $internal_lb_name" json
  test_create_load_balancer_frontend_ip $internal_lb_name || log_output "create_load_balancer_frontend_ip $internal_lb_name" json
  test_create_load_balancer_backend_pool $internal_lb_name || log_output "create_load_balancer_backend_pool $internal_lb_name" json
  test_create_load_balancer_rule $internal_lb_name || log_output "create_load_balancer_rule $internal_lb_name" json
  test_create_load_balancer_probe $internal_lb_name || log_output "create_load_balancer_probe $internal_lb_name" json
done

log_output get_public_ips json
log_output get_storage_keys json

./create_env.sh ${ENVIRONMENT}
