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
    jq -r ".appId"
}

function get_app_client_password() {
  cat ${OUTPUT_DIR}/generate_password.json | \
    jq -r ".secret_active_directory_app_client_password"
}

function get_jumpbox_password() {
  cat ${OUTPUT_DIR}/generate_password.json | \
    jq -r ".secret_jumpbox_password"
}

function get_bosh_password() {
  cat ${OUTPUT_DIR}/generate_password.json | \
    jq -r ".secret_bosh_password"
}

function get_concourse_password() {
  cat ${OUTPUT_DIR}/generate_password.json | \
    jq -r ".secret_concourse_password"
}

function get_cc_admin_password() {
  cat ${OUTPUT_DIR}/generate_password.json | \
    jq -r ".secret_cc_admin_password"
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
  export SECRET_BOSH_PASSWORD=$(get_bosh_password)
  export SECRET_CONCOURSE_PASSWORD=$(get_concourse_password)
  export SECRET_CC_ADMIN_PASSWORD=$(get_cc_admin_password)
  export SECRET_SSH_CERTIFICATE=$(get_pub_cert)
}

function write_to_env() {
  filename=$1
  cat > ${OUTPUT_DIR}/${filename} << EOF

export ENVIRONMENT="${ENVIRONMENT}"

# from bootstrap_env.sh
export SUBSCRIPTION_ID=${SECRET_SUBSCRIPTION_ID}
export TENANT_ID=${SECRET_TENANT_ID}
export LOCATION=westus
export STORAGE_TYPE=lrs
export RESOURCE_GROUP_NAME=${ENVIRONMENT}-resource
export STORAGE_ACCOUNT_NAME=${ENVIRONMENT}cfhosted2016
export PUBLIC_IP_NAME=${ENVIRONMENT}-ip
export VIRTUAL_NETWORK_NAME=${ENVIRONMENT}-network
export BOSH_SUBNET_NAME=${ENVIRONMENT}-bosh
export CF_SUBNET_NAME=${ENVIRONMENT}-cf
export DOMAIN_LABEL=${ENVIRONMENT}-domain
export ACTIVE_DIRECTORY_APPLICATION_NAME=${ENVIRONMENT}-bosh-ad-name
export OUTPUT_DIR="\$( cd "\$( dirname "\${BASH_SOURCE[0]}" )" && pwd )"
export SSH_PRIVATE_CERTIFICATE_FILE="${OUTPUT_DIR}/bosh.key"
export SSH_PUBLIC_CERTIFICATE_FILE="${SSH_PRIVATE_CERTIFICATE_FILE}.pub"

# from ${ENVIRONMENT}_env.sh
export CONCOURSE_EIP="${CONCOURSE_EIP}"
export HAPROXY_EIP="${HAPROXY_EIP}"
export LOGIN_WILDCARD_EIP="${LOGIN_WILDCARD_EIP}"
export JUMPBOX1_EIP="${JUMPBOX1_EIP}"

export CLIENT_ID="${CLIENT_ID}"
export SECRET_STORAGE_ACCESS_KEY="${SECRET_STORAGE_ACCESS_KEY}"
export SECRET_CLIENT_PASSWORD="${SECRET_CLIENT_PASSWORD}"
export SECRET_JUMPBOX_PASSWORD="${SECRET_JUMPBOX_PASSWORD}"
export SECRET_BOSH_PASSWORD="${SECRET_BOSH_PASSWORD}"
export SECRET_CONCOURSE_PASSWORD="${SECRET_CONCOURSE_PASSWORD}"
export SECRET_CC_ADMIN_PASSWORD="${SECRET_CC_ADMIN_PASSWORD}"
export SECRET_SSH_CERTIFICATE="${SECRET_SSH_CERTIFICATE}"

# from secret
export SECRET_TENANT_ID=${SECRET_TENANT_ID}
export SECRET_SUBSCRIPTION_ID=${SECRET_SUBSCRIPTION_ID}
export SECRET_AZURE_CLI_USERNAME='${SECRET_AZURE_CLI_USERNAME}'
export SECRET_AZURE_CLI_PASSWORD='${SECRET_AZURE_CLI_PASSWORD}'
export SECRET_ADMIN_EMAIL='${SECRET_ADMIN_EMAIL}'


# for jumpbox
export JUMPBOX_NIC=${JUMPBOX_NIC}
export JUMPBOX_NAME='${JUMPBOX_NAME}'
export JUMPBOX_USER=${JUMPBOX_USER}
export JUMPBOX_PASSWORD=$SECRET_JUMPBOX_PASSWORD
export JB_SUBNET_NAME=${JB_SUBNET_NAME}
export JB_IMAGE='${JB_IMAGE}'
export JB_VM_SIZE=${JB_VM_SIZE}

function logmein() {
  echo "Username:"
  read USERNAME
  ssh -A \$USERNAME@$JUMPBOX1_EIP
}

function logvcapin() {
  ssh -A -i ./output/$ENVIRONMENT/bosh.key $JUMPBOX_USER@$JUMPBOX1_EIP
}
EOF
}

decode_bootstrap_output
write_to_env "${ENVIRONMENT}_env.sh"


