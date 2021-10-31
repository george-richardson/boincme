#!/bin/bash
set -eo pipefail

USER_DATA="/tmp/user-data.json"
DEFAULT_CONFIG="/boinc-config-defaults.json"
SSM_CONFIG="/tmp/boinc-config-ssm.json"
CONFIG="/tmp/boinc-config.json"

echo "Retrieving user data configuration..."
curl --silent "http://169.254.169.254/latest/user-data" > $USER_DATA

BOINC_STACK_NAME=$(jq --raw-output '.stack_name' "$USER_DATA")
BOINC_SSM_PREFIX=$(jq --raw-output '.ssm_prefix' "$USER_DATA")

echo "Retrieving SSM configuration..."
export AWS_DEFAULT_REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)
aws ssm get-parameters-by-path --with-decryption --path "$BOINC_SSM_PREFIX" \
  | jq '.Parameters | reduce .[] as $i ({}; .[$i.Name] = $i.Value)' \
  > "$SSM_CONFIG"

echo "Combining SSM configuration with defaults..."
jq --slurp '.[0] * .[1]' "$DEFAULT_CONFIG" "$SSM_CONFIG" > "$CONFIG"

echo "Parsing configuration..."
BOINC_MANAGER_USERNAME=$(jq --raw-output ".\"${BOINC_SSM_PREFIX}manager_username\"" "$CONFIG")
BOINC_MANAGER_PASSWORD=$(jq --raw-output ".\"${BOINC_SSM_PREFIX}manager_password\"" "$CONFIG")
BOINC_MANAGER_URL=$(jq --raw-output ".\"${BOINC_SSM_PREFIX}manager_url\"" "$CONFIG")

BOINC_PROJECT_URL=$(jq --raw-output ".\"${BOINC_SSM_PREFIX}project_url\"" "$CONFIG")
BOINC_PROJECT_ACCOUNT_KEY=$(jq --raw-output ".\"${BOINC_SSM_PREFIX}project_account_key\"" "$CONFIG")

BOINC_DISABLE_LOGS=$(jq --raw-output ".\"${BOINC_SSM_PREFIX}disable_logs\"" "$CONFIG")

if [ "$BOINC_DISABLE_LOGS" = "true" ]; then 
  echo "Cloudwatch logs disabled..."
else 
  echo "Enabling cloudwatch logs with vector..."
  AWS_INSTANCE_ID=$(curl --silent http://169.254.169.254/latest/meta-data/instance-id)
  echo "AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}" >> /etc/default/vector
  echo "AWS_INSTANCE_ID=${AWS_INSTANCE_ID}" >> /etc/default/vector
  echo "BOINC_STACK_NAME=${BOINC_STACK_NAME}" >> /etc/default/vector
  sudo systemctl enable vector --now
fi

if [ -z "$BOINC_MANAGER_USERNAME" ]; then 
  echo "Configuring BOINC manager... ($BOINC_MANAGER_URL)"
  boinccmd --acct_mgr attach "$BOINC_MANAGER_URL" "$BOINC_MANAGER_USERNAME" "$BOINC_MANAGER_PASSWORD"
else 
  echo "BOINC_MANAGER_USERNAME not set, skipping BOINC manager configuration..."
fi 

if [ -z "$BOINC_PROJECT_URL" ]; then 
  echo "Configuring BOINC project... ($BOINC_PROJECT_URL)"
  boinccmd --project_attach "$BOINC_PROJECT_URL" "$BOINC_PROJECT_ACCOUNT_KEY"
else 
  echo "BOINC_PROJECT_URL not set, skipping BOINC project configuration..."
fi 

echo "Disabling boinc-config systemd unit..."
sudo systemctl disable boinc-config

echo "Cleaning up..."
rm "$CONFIG" "$SSM_CONFIG"