#!/bin/bash
set -e

export DEBIAN_FRONTEND="noninteractive"

echo "Moving files around..."
sudo mv /tmp/boinc-config/boinc-config-defaults.json /
sudo mv /tmp/boinc-config/boinc-config.sh /
sudo mv /tmp/boinc-config/boinc-config.service /etc/systemd/system/

echo "Upgrading existing packages..."
sudo apt update > /dev/null 2>&1
sudo apt -y upgrade > /dev/null 2>&1

echo "Installing jq..."
sudo apt install -y jq > /dev/null 2>&1

echo "Installing awscli..."
sudo apt install -y awscli > /dev/null 2>&1

echo "Installing 32-bit compatibility libraries..."
sudo apt install -y lib32ncurses6 lib32z1 lib32stdc++-7-dev > /dev/null 2>&1

echo "Installing Boinc Client..."
sudo apt install -y boinc-client > /dev/null 2>&1

echo "Downloading vector..."
wget https://packages.timber.io/vector/0.17.3/vector-0.17.3-amd64.deb -O /tmp/vector.deb > /dev/null 2>&1

echo "Installing vector..."
sudo dpkg -i /tmp/vector.deb > /dev/null 2>&1

echo "Configuring vector..."
sudo mv /tmp/vector/vector.toml /etc/vector/vector.toml

echo "Disabling vector..."
sudo systemctl disable vector > /dev/null 2>&1

echo "Enabling boinc-config unit for startup..."
sudo systemctl enable boinc-config > /dev/null 2>&1