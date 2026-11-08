#!/usr/bin/env bash

set -euo pipefail

echo "::group:: Install Vicinae & Zed from Terra"

# shellcheck disable=SC2016
dnf5 install -y --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release
dnf5 install -y vicinae zed

# Remove the repository file. A third-party repository is a build-time source
# only; 90-cleanup.sh also disables terra.repo as a backstop.
rm -f /etc/yum.repos.d/terra.repo

echo "::endgroup::"
