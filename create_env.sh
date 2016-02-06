set -ex

if [ $# -eq 0 ]
then
  echo "No ENVIRONMENT arguments supplied"
  exit 1
fi

export ENVIRONMENT=$1

source ./bootstrap_env.sh

function get_ipaddress_from_name() {
  name=$1
  cat ${OUTPUT_DIR}/get_public_ips.json | \
    jq -r ".[]| select(.name == \"${name}\")|.ipAddress"
}

function get_storage_primary_key() {
  cat ${OUTPUT_DIR}/get_storage_keys.json | \
    jq -r ".primary_storage_key"
}

function get_client_id() {
  cat ${OUTPUT_DIR}/create_active_directory_app.json | \
    jq -r ".objectId"
}

function get_app_client_password() {
  cat ${OUTPUT_DIR}/generate_password.json | \
    jq -r ".secret_active_directory_app_client_password"
}

function get_jumpbox_password() {
  cat ${OUTPUT_DIR}/generate_password.json | \
    jq -r ".secret_jumpbox_password"
}

function get_pub_cert() {
  cat ${OUTPUT_DIR}/bosh.key.pub
}

function decode_bootstrap_output() {
  export HAPROXY_EIP=$(get_ipaddress_from_name haproxy_eip)
  export CONCOURSE_EIP=$(get_ipaddress_from_name concourse_eip)
  export LOGIN_WILDCARD_EIP=$(get_ipaddress_from_name login_wildcard_eip)
  export JUMPBOX1_EIP=$(get_ipaddress_from_name jumpbox1_eip)

  export CLIENT_ID=$(get_client_id)
  export SECRET_STORAGE_ACCESS_KEY=$(get_storage_primary_key)
  export SECRET_CLIENT_PASSWORD=$(get_app_client_password)
  export SECRET_JUMPBOX_PASSWORD=$(get_jumpbox_password)
  export SECRET_SSH_CERTIFICATE=$(get_pub_cert)
}

function write_to_env() {
  filename=$1
  cat > ${OUTPUT_DIR}/${filename} << EOF
export COUNCOURSE_EIP="${CONCOURSE_EIP}"
export HAPROXY_EIP="${HAPROXY_EIP}"
export LOGIN_WILDCARD_EIP="${LOGIN_WILDCARD_EIP}"
export JUMPBOX1_EIP="${JUMPBOX1_EIP}"

export CLIENT_ID="${CLIENT_ID}"
export SECRET_STORAGE_ACCESS_KEY="${SECRET_STORAGE_ACCESS_KEY}"
export SECRET_CLIENT_PASSWORD="${SECRET_CLIENT_PASSWORD}"
export SECRET_JUMPBOX_PASSWORD="${SECRET_JUMPBOX_PASSWORD}"
export SECRET_SSH_CERTIFICATE="${SECRET_SSH_CERTIFICATE}"
EOF
}

decode_bootstrap_output
write_to_env "${ENVIRONMENT}_env.sh"


