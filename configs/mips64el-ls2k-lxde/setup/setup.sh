#!/bin/bash -x

set -e

source "$HOOK_FUNCTIONS"

basic_setup
enable_splash
run_loongbian_workarounds
replace_apt_cacher_source
