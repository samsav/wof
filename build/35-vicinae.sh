#!/usr/bin/env bash

set -euo pipefail

echo "::group:: Install Vicinae & Zed from Terra"

# shellcheck disable=SC2016
dnf5 install -y --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release
dnf5 install -y vicinae zed

echo "::endgroup::"
