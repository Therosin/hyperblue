#!/usr/bin/env bash

# Tell this script to exit if there are any errors.
# You should have this in every custom script, to ensure that your completed
# builds actually ran successfully without any errors!
set -oue pipefail

# Get the Fedora release version and architecture
FEDORA_VERSION=$(rpm -E %fedora)
ARCHITECTURE=$(uname -m)

# Create the ZeroTier YUM repository configuration
echo "[zerotier]
name=ZeroTier, Inc. repository
baseurl=https://download.zerotier.com/redhat/$FEDORA_VERSION/$ARCHITECTURE
enabled=1
gpgcheck=0" | sudo tee /etc/yum.repos.d/zerotier.repo

# Install ZeroTier using rpm-ostree
rpm-ostree install zerotier-one
