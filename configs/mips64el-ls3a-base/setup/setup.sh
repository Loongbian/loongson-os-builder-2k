#!/bin/bash

set -e

source "$HOOK_FUNCTIONS"

export SKIP_LOCALE_CONF=1

basic_setup
add_fallback_source "http://127.0.0.1:3142/mirrors.teach.com.cn/debian"
replace_apt_cacher_source
