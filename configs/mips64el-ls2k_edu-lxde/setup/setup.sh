#!/bin/bash -x

set -e

source "$HOOK_FUNCTIONS"

APT_FALLBACK_SOURCE="http://mirrors.163.com/debian"

update_apt_list() {
  if ! fgrep "$APT_FALLBACK_SOURCE" /etc/apt/sources.list; then
    echo "deb $APT_FALLBACK_SOURCE buster main" >> /etc/apt/sources.list
  fi
}

run_workarounds() {
  # PMON boot.cfg should be configured at installation time
  rm -f "/boot/boot.cfg"
  # disable DNSSEC for systemd-resolved to prevent name resolution failure due to the incorrect hardware clock
  mkdir -p "/etc/systemd/resolved.conf.d"
  echo -e "[Resolve]\nDNSSEC=false\n" > "/etc/systemd/resolved.conf.d/disable-dnssec.conf"
}

basic_setup
update_apt_list
run_workarounds
