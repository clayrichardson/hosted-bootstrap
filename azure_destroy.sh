set -ex

if [ $# -eq 0 ]
then
  echo "No ENVIRONMENT arguments supplied"
  exit 1
fi

export ENVIRONMENT=$1
source ./bootstrap_env.sh
source ${OUTPUT_DIR}/${ENVIRONMENT}_env.sh

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
  $(npm bin)/phantomjs ./login.js
}

function azure_config() {
  azure_login
  azure config mode arm
}

echo "Destroying Azure for ${ENVIRONMENT}..."

function destroy_resource_group() {
  azure group delete \
    --name $RESOURCE_GROUP_NAME \
    -q
}

function destroy_active_directory_app() {
  azure ad app delete ${CLIENT_ID} -q
}

function log_output() {
  execute_func=$1
  eval ${execute_func} | tee "output/${execute_func}.log"
}

azure_config

log_output destroy_active_directory_app
log_output destroy_resource_group

