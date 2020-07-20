#!/bin/bash -x

set -e

if ! ischroot -t; then
  echo "Error: This script is only supposed to run in chroot."
  exit 1
fi

source "$HOOK_FUNCTIONS"

APT_FALLBACK_SOURCE="http://mirrors.163.com/debian"

update_apt_list() {
  if ! fgrep "$APT_FALLBACK_SOURCE" /etc/apt/sources.list; then
    echo "deb $APT_FALLBACK_SOURCE buster main" >> /etc/apt/sources.list
  fi
  apt update
}

install_essential_pkgs() {
  apt install -y --no-install-recommends initramfs-tools pmon-update ca-certificates
  apt install -y --no-install-recommends linux-image-4.19.0-loongson-2k linux-image-5.7.0-loongson-2k
}

install_desktop() {
  apt install -y --no-install-recommends xserver-xorg lxde lightdm desktop-base plymouth
}

run_workarounds() {
  # PMON boot.cfg should be configured at installation time
  rm -f "/boot/boot.cfg"
  # disable DNSSEC for systemd-resolved to prevent name resolution failure due to the incorrect hardware clock
  mkdir -p "/etc/systemd/resolved.conf.d"
  echo -e "[Resolve]\nDNSSEC=false\n" > "/etc/systemd/resolved.conf.d/disable-dnssec.conf"
}

update_apt_list
install_essential_pkgs
install_desktop
setup_dhcp_network
run_workarounds
