#!/bin/bash
set -eo pipefail

USER_DATA="/tmp/user-data.json"
DEFAULT_CONFIG="/boincme-config-defaults.json"
SSM_CONFIG="/tmp/boincme-config-ssm.json"
CONFIG="/tmp/boincme-config.json"

echo "Retrieving user data configuration..."
curl --silent "http://169.254.169.254/latest/user-data" > $USER_DATA

BOINC_STACK_NAME=$(jq --raw-output '.stack_name' "$USER_DATA")
BOINC_SSM_PREFIX=$(jq --raw-output '.ssm_prefix' "$USER_DATA")

echo "Retrieving SSM configuration..."
export AWS_DEFAULT_REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)
aws ssm get-parameters-by-path --with-decryption --path "$BOINC_SSM_PREFIX" \
  | jq ".Parameters | reduce .[] as \$i ({}; .[\$i.Name | sub(\"${BOINC_SSM_PREFIX}\"; \"\")] = \$i.Value)" \
  > "$SSM_CONFIG"

echo "Combining SSM configuration with defaults..." 
jq --slurp '.[0] * .[1]' "$DEFAULT_CONFIG" "$SSM_CONFIG" > "$CONFIG"

get_config () {
  jq --raw-output ".\"${1}\" //empty" "$CONFIG"
}

echo "Parsing configuration..."
BOINC_MANAGER_USERNAME=$(get_config "manager_username")
BOINC_MANAGER_PASSWORD=$(get_config "manager_password")
BOINC_MANAGER_URL=$(get_config "manager_url")

BOINC_PROJECT_URL=$(get_config "project_url")
BOINC_PROJECT_ACCOUNT_KEY=$(get_config "project_account_key")

BOINC_DISABLE_LOGS=$(get_config "disable_logs")

if [ "$BOINC_DISABLE_LOGS" = "true" ]; then 
  echo "Cloudwatch logs disabled..."
else 
  echo "Enabling cloudwatch logs with vector..."
  AWS_INSTANCE_ID=$(curl --silent http://169.254.169.254/latest/meta-data/instance-id)
  cat <<EOF >> /etc/default/vector
AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}
AWS_INSTANCE_ID=${AWS_INSTANCE_ID}
BOINC_STACK_NAME=${BOINC_STACK_NAME}
EOF
  sudo systemctl enable vector --now
fi

if [ -z "$BOINC_MANAGER_USERNAME" ]; then 
  echo "BOINC_MANAGER_USERNAME not set, skipping BOINC manager configuration..."
else 
  echo "Configuring BOINC manager... ($BOINC_MANAGER_URL)"
  boinccmd --acct_mgr attach "$BOINC_MANAGER_URL" "$BOINC_MANAGER_USERNAME" "$BOINC_MANAGER_PASSWORD"  
fi 

if [ -z "$BOINC_PROJECT_URL" ]; then 
  echo "BOINC_PROJECT_URL not set, skipping BOINC project configuration..."
else 
  echo "Configuring BOINC project... ($BOINC_PROJECT_URL)"
  boinccmd --project_attach "$BOINC_PROJECT_URL" "$BOINC_PROJECT_ACCOUNT_KEY"
fi 

echo "Disabling boincme-config systemd unit..."
sudo systemctl disable boincme-config

echo "Cleaning up..."
rm "$CONFIG" "$SSM_CONFIG"