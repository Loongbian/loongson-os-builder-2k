#!/bin/bash -x

if ! ischroot -t; then
  echo "Error: This script is only supposed to run in chroot."
  exit 1
fi

WORK_DIR="$(dirname $0)"
EXT_PKG_DIR="$WORK_DIR/pkgs"

install_essential_pkgs() {
  set -e
  apt update
  apt install -y initramfs-tools
}

install_desktop() {
  set -e
  apt install -y --no-install-recommends xserver-xorg lxde-core lxterminal lightdm
}

install_ext_pkgs() {
  set +e
  if [ ! -d "$EXT_PKG_DIR" ] || [ ! -f "$EXT_PKG_DIR/ORDER" ]; then
    return 0
  fi
  set -e
  for pkg in $(cat "$EXT_PKG_DIR/ORDER"); do
    dpkg -i "$EXT_PKG_DIR/$pkg"
  done
  apt install -f -y
}


setup_network() {
  set -e
  systemctl enable systemd-networkd
  systemctl enable systemd-resolved
  ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
  cat << EOF > /etc/systemd/network/dhcp.network
[Match]
Name=en*

[Network]
DHCP=yes
EOF
}

run_workarounds() {
  # PMON boot.cfg should be configured at installation time
  rm -f "/boot/boot.cfg"
  # disable DNSSEC for systemd-resolved to prevent name resolution failure due to the incorrect hardware clock
  mkdir -p "/etc/systemd/resolved.conf.d"
  echo -e "[Resolve]\nDNSSEC=false\n" > "/etc/systemd/resolved.conf.d/disable-dnssec.conf"
  # update hostname to avoid conflict with the build machine
  if [ ! "$TARGET_HOSTNAME" = "" ]; then
    echo "$TARGET_HOSTNAME" > /etc/hostname
  fi
}

install_essential_pkgs
install_desktop
install_ext_pkgs
setup_network
run_workarounds
