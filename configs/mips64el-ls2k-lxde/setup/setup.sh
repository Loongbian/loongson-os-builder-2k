#!/bin/bash -x

set -e

source "$HOOK_FUNCTIONS"

basic_setup
enable_splash

run_loongbian_workarounds

#add_fallback_source "http://127.0.0.1:3142/mirrors.163.com/debian"
#apt install -y libc-l10n locales lxde desktop-base plymouth
