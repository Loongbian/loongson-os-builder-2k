#!/bin/bash -x

set -e

source "$HOOK_FUNCTIONS"

export SKIP_LOCALE_CONF=1

basic_setup
run_loongbian_workarounds
replace_apt_cacher_source
