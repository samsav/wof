#!/usr/bin/env bash

set -euo pipefail

# Enable nullglob for all glob operations to prevent failures on empty matches
shopt -s nullglob

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

# Prepare 1Password groups
# Normally, when after dnf installs the 1password RPM, an
# 'after-install.sh' script runs to cofigure several things, including
# the creation of a group. Under rpm-ostree, this didn't work quite as
# expected, thus several steps were done to hack around and fix things.
# Now with dnf, there is a problem where 'after-install.sh' creates
# groups which conflict with default user's GID. This now pre-creates
# the groups, rather than fixing after RPM installation.

# I hardcode GIDs and cross fingers that nothing else steps on them.
# These numbers _should_ be okay under normal use, but
# if there's a more specific range that I should use here
# please submit a PR!

# Specifically, GID must be > 1000, and absolutely must not
# conflict with any real groups on the deployed system.
# Normal user group GIDs on Fedora are sequential starting
# at 1000, so let's skip ahead and set to something higher.
GID_ONEPASSWORD="1790"
GID_ONEPASSWORDCLI="1791"
groupadd -g ${GID_ONEPASSWORD} onepassword
groupadd -g ${GID_ONEPASSWORDCLI} onepassword-cli

dnf5 install -y 1password

# This places the 1Password contents in an image safe location
mv /var/opt/1Password /usr/lib/1Password # move this over here

rm -f /etc/yum.repos.d/1password.repo

echo "::endgroup::"

# Restore default glob behavior
shopt -u nullglob
