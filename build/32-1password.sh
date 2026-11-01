#!/usr/bin/env bash

set -euo pipefail

echo "::group:: Install 1Password"

# Add key for 1Password yum repository
rpm --import https://downloads.1password.com/linux/keys/1password.asc
# Add the repository
cat <<EOF >/etc/yum.repos.d/1password.repo
[1password]
name=1Password Stable Channel
baseurl=https://downloads.1password.com/linux/rpm/stable/\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://downloads.1password.com/linux/keys/1password.asc
EOF

dnf5 install -y 1password 1password-cli

rm -f /etc/yum.repos.d/1password.repo
