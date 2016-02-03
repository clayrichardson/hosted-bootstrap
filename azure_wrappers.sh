function destroy_storage_account(){
  azure storage account create \
    --resource-group $RESOURCE_GROUP_NAME \
    --subscription $SUBSCRIPTION_ID \
    --type $STORAGE_TYPE \
    --location $LOCATION \
    --json \
    $STORAGE_ACCOUNT_NAME
}

function primary_storage_key() {
   storage_account_name=$1
   azure storage account keys list \
     --resource-group $RESOURCE_GROUP_NAME \
     $storage_account_name --json |\
     jq -r .storageAccountKeys.key1
}

function secondary_storage_key() {
   storage_account_name=$1
   azure storage account keys list \
     --resource-group $RESOURCE_GROUP_NAME \
     $storage_account_name --json |\
     jq -r .storageAccountKeys.key2
}


function list_storage_container() {
  storage_account_name=$1
  storage_account_key=$2
  azure storage container list \
    --account-name ${storage_account_name} \
    --account-key "${storage_account_key}"\
    --json | \
    jq -r .[].name
}

function destroy_storage_containers() {

  for storage_account in $(list_storage_accounts); do
    storage_key=$(primary_storage_key ${storage_account})
    for storage_container in $(list_storage_container $storage_account $storage_key)
    do
      azure storage container delete \
        --account-name ${storage_account} \
        --account-key ${storage_key} \
        --container storage_container
    done

    for storage_table in $(list_storage_tables $storage_account $storage_key)
    do
      azure storage table delete \
        --account-name ${storage_account} \
        --account-key ${storage_key} \
        --container storage_container
    done
  done
}

function destroy_public_ips() {
  for ip in $(list_public_ips); do
    azure network public-ip delete \
      --resource-group $RESOURCE_GROUP_NAME \
      --name $ip \
      -q
  done
}

function destroy_vnets() {
  for vnet in $(list_vnets); do
    azure network vnet delete \
      --resource-group $RESOURCE_GROUP_NAME \
      --name $vnet \
      -q
  done
}

function destroy_subnet() {
  name=$1
  virtual_network_name=$2
  azure network vnet subnet delete \
    --resource-group $RESOURCE_GROUP_NAME \
    --vnet-name $virtual_network_name \
    --name $name \
    -q
}

function list_storage_accounts() {
  azure storage account list -g $RESOURCE_GROUP_NAME --json | jq -r .[].name
}

function list_vnets() {
  azure network vnet list -g $RESOURCE_GROUP_NAME  --json | \
          # delete length key to parse output
          jq 'del(.length)' | jq -r .[].name
}

function list_public_ips() {
   azure network public-ip list -g $RESOURCE_GROUP_NAME  --json | \
          # delete length key to parse output
          jq 'del(.length)' | jq -r .[].name
}

function destroy_networks() {
  for vnet in $(list_vnets); do
    subnet_names=$(azure network vnet subnet list \
      --resource-group $RESOURCE_GROUP_NAME \
      --vnet-name $vnet \
      --json | \
      jq 'del(.length)' | jq -r .[].name
    )

    for name in $subnet_names; do
      destroy_subnet $name $vnet
    done
  done
}



