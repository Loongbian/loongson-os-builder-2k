#!/bin/bash -x

set -e

if ! ischroot -t; then
  echo "Error: This script is only supposed to run in chroot."
  exit 1
fi

source "$HOOK_FUNCTIONS"

install_essential_pkgs() {
  apt install -y initramfs-tools linux-image-amd64 ca-certificates
}

install_essential_pkgs
setup_dhcp_network