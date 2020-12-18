#!/bin/bash -x

set -e

source "$HOOK_FUNCTIONS"

basic_setup
enable_splash
run_loongbian_workarounds

apt install -y libreoffice evince scratch thonny geany idle3 arduino vlc pulseaudio lxterminal gedit catfish mousepad ristretto inkscape claws-mail firefox-esr catfish python3-opencv python3-pandas python3-numpy python3-pil ls2k-unlock-io python3-adafruit-blinka build-essential

replace_apt_cacher_source
