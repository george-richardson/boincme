#!/bin/bash
set -eo pipefail

DEFAULT_CONFIG="/boinc-config-defaults.json"
SSM_CONFIG="/tmp/boinc-config-ssm.json"
CONFIG="/tmp/boinc-config.json"

echo "Retrieving SSM configuration..."
export AWS_DEFAULT_REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)
aws ssm get-parameters-by-path --with-decryption --path "/boinc/" \
  | jq '.Parameters | reduce .[] as $i ({}; .[$i.Name] = $i.Value)' \
  > "$SSM_CONFIG"

echo "Combining SSM configuration with defaults..."
jq --slurp '.[0] * .[1]' "$DEFAULT_CONFIG" "$SSM_CONFIG" > "$CONFIG"

echo "Parsing configuration..."
BOINC_MANAGER_USERNAME=$(jq --raw-output '."/boinc/manager_username"' "$CONFIG")
BOINC_MANAGER_PASSWORD=$(jq --raw-output '."/boinc/manager_password"' "$CONFIG")
BOINC_MANAGER_URL=$(jq --raw-output '."/boinc/manager_url"' "$CONFIG")

echo "Configuring boinc manager..."
boinccmd --acct_mgr attach "$BOINC_MANAGER_URL" "$BOINC_MANAGER_USERNAME" "$BOINC_MANAGER_PASSWORD"

echo "Disabling boinc-config systemd unit..."
sudo systemctl disable boinc-config

echo "Cleaning up..."
rm "$CONFIG" "$SSM_CONFIG"