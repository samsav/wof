#!/usr/bin/env bash

set -euo pipefail

echo "::group:: Install 1Password"

# The image is ostree-based: /opt is a symlink to var/opt, and /var/opt does
# not exist at build time. The 1Password RPM installs under /opt/1Password,
# and the transaction cannot create its files until that symlink resolves.
mkdir -p /var/opt

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

# The packages' %post scriptlets create their groups with groupadd, leaving
# bare /etc/group entries. bootc container lint refuses those: the deployed
# system reproduces group state from /usr/lib/sysusers.d, so every group
# shipped in /etc/group must be declared there. Declare fixed GIDs (above
# the sequential per-user range that starts at 1000) and materialize them
# now, so the scriptlets' getent checks skip their groupadd and the setgid
# bits land on these GIDs.
cat >/usr/lib/sysusers.d/onepassword.conf <<EOF
g onepassword 1790
g onepassword-cli 1791
g onepassword-mcp 1792
EOF
systemd-sysusers

dnf5 install -y 1password 1password-cli

# /var in the image acts like a Docker volume: it is seeded from the initial
# image at first boot and never updated afterwards, so the payload must move
# into /usr, which is committed with the image. tmpfiles.d then recreates
# /opt/1Password at boot so /usr/bin/1password's target stays reachable.
mv /var/opt/1Password /usr/lib/1Password
cat >/usr/lib/tmpfiles.d/onepassword.conf <<EOF
d /var/opt 0755 root root -
L /opt/1Password - - - - /usr/lib/1Password
EOF

rm -f /etc/yum.repos.d/1password.repo

echo "::endgroup::"
