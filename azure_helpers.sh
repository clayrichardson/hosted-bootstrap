function azure_login() {
  log_file="${OUTPUT_DIR}/login.log"
  azure login | tee ${log_file} &
  sleep 2
  token=`cat ${log_file} |grep "To sign in"| sed 's/.*code \(.*\) to authenticate.$/\1/'`

  if [ -z "${token}" ]; then
    echo 'No login token found, exit'
    exit 1
  fi

  export AZURE_CLI_TOKEN=${token}
  $(npm bin)/phantomjs ./phantom.js
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
  eval ${execute_func} | tee "${OUTPUT_DIR}/${execute_func}.${file_extension}"
}
