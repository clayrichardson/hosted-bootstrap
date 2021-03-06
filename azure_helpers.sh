set -ex

source ./helpers.sh

function azure_login(){
  retry 5 private_azure_login
}

function private_azure_login() {
  log_file="${OUTPUT_DIR}/login.log"
  if [ -f $log_file ]; then
    rm $log_file
  fi
  # if list locations fails, we need to login
  azure login | tee ${log_file} &

  until grep -i "To sign in" $log_file && echo "Found token output"
  do
    echo "Waiting for Azure cli to give token..."
    sleep 1
  done

  token=`cat ${log_file} |grep "To sign in"| sed 's/.*code \(.*\) to authenticate.$/\1/'`

  if [ -z "${token}" ]; then
    echo 'No login token found, exit'
    exit 1
  fi

  export AZURE_CLI_TOKEN=${token}
  $(npm bin)/phantomjs --debug=true --ssl-protocol=any --ignore-ssl-errors=true ./login.js
  wait
  azure config mode arm
}

function env_check() {
  if [[ "$ENVIRONMENT" =~ [^a-zA-Z0-9\ ] ]]; then
    echo "Invalid name ${ENVIRONMENT}, use alphanumeric string"
    exit 1
  fi
}

function log_output() {
  execute_func=$1
  file_extension=$2
  file_name=$(echo $execute_func|sed 's/\//-/g')
  eval ${execute_func} | tee "${OUTPUT_DIR}/${file_name}.${file_extension}"
  if [[ ! ${PIPESTATUS[0]} == 0 ]]; then
    exit 1
  fi
}

function get_primary_storage_key() {
  local storage_account_name=$1
  local full_storage_account_name="${STORAGE_ACCOUNT_PREFIX}${storage_account_name}"
  azure storage account keys list \
    --resource-group $RESOURCE_GROUP_NAME \
    $full_storage_account_name --json |\
    jq -r .key1
}

function get_secondary_storage_key() {
  local storage_account_name=$1
  local full_storage_account_name="${STORAGE_ACCOUNT_PREFIX}${storage_account_name}"
  azure storage account keys list \
    --resource-group $RESOURCE_GROUP_NAME \
    $full_storage_account_name --json |\
    jq -r .key2
}
