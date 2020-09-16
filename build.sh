#!/bin/bash

set -e

BUILD_DIR=build
ROOTFS_DIR="$BUILD_DIR/rootfs"
CONFIG_DIR=configs
OVERLAY_UPPER_DIR="$BUILD_DIR/overlay-upper"
OVERLAY_WORK_DIR="$BUILD_DIR/overlay-work"
HOOK_FUNCTIONS=scripts/functions
INSTALLER_DIR=installer

export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
export LC_ALL=C LANGUAGE=C LANG=C

cd "$(dirname $0)"

resolv_workaround() {
  mkdir -p "$ROOTFS_DIR/run/systemd/resolve"
  cat "/etc/resolv.conf" > "$ROOTFS_DIR/run/systemd/resolve/stub-resolv.conf"
}

require_bootstrapped() {
  if [ ! -d "$ROOTFS_DIR" ]; then
    echo "Error: Could not find target rootfs directory. Have you bootstrapped?"
    return 1
  fi
  return 0
}

run_debootstrap() {
  mkdir -p "$ROOTFS_DIR"
  qemu-debootstrap --arch "$CONFIG_ARCH" \
    ${CONFIG_KEYRING:+"--keyring" "$CONFIG_KEYRING"} \
    ${CONFIG_EXT_PKGS:+"--include" "$CONFIG_EXT_PKGS"} \
    "$CONFIG_SUITE" "$ROOTFS_DIR" "$CONFIG_MIRROR"
}

run_post_debootstrap_setup_cleanup() {
  umount -q "$ROOTFS_DIR/proc" || true
  umount -q "$ROOTFS_DIR/sys" || true
  umount -q "$ROOTFS_DIR/tmp/setup" || true
  umount -q "$ROOTFS_DIR/dev/pts" || true
}

run_post_debootstrap_setup() {
  local POSTDEBOOTSTRAP_SETUP_DIR="$CONFIG_DIR/$CONFIG_NAME/setup"
  echo "$POSTDEBOOTSTRAP_SETUP_DIR"
  if [ ! -f "$POSTDEBOOTSTRAP_SETUP_DIR/setup.sh" ]; then
    return
  fi

  trap run_post_debootstrap_setup_cleanup EXIT INT
  mount -t proc proc "$ROOTFS_DIR/proc"
  mount -t sysfs sys "$ROOTFS_DIR/sys"
  mount --bind /dev/pts "$ROOTFS_DIR/dev/pts"
  require_bootstrapped
  resolv_workaround
  mkdir -p "$ROOTFS_DIR/tmp/setup"
  mount --bind "$POSTDEBOOTSTRAP_SETUP_DIR" "$ROOTFS_DIR/tmp/setup"
  cp "$HOOK_FUNCTIONS" "$ROOTFS_DIR/tmp/functions"
  export CONFIG_HOSTNAME
  env -u DBUS_SESSION_BUS_ADDRESS HOOK_FUNCTIONS="/tmp/functions" chroot "$ROOTFS_DIR" "/tmp/setup/setup.sh"
  run_post_debootstrap_setup_cleanup
  trap - EXIT INT
}

build_installer_initrd_cleanup() {
  echo "Cleaning up..."
  umount -q "$ROOTFS_DIR/proc" || true
  umount -q "$ROOTFS_DIR/sys" || true
  umount -q "$ROOTFS_DIR/tmp/$INSTALLER_DIR" || true
  umount -q "$ROOTFS_DIR" || true
}

build_installer_initrd() {
  trap build_installer_initrd_cleanup EXIT INT
  require_bootstrapped
  resolv_workaround
  mkdir -p "$OVERLAY_UPPER_DIR" "$OVERLAY_WORK_DIR"
  mount -t overlay overlay -o "lowerdir=$ROOTFS_DIR,upperdir=$OVERLAY_UPPER_DIR,workdir=$OVERLAY_WORK_DIR" "$ROOTFS_DIR"
  mount -t proc proc "$ROOTFS_DIR/proc"
  mount -t sysfs sys "$ROOTFS_DIR/sys"
  chroot "$ROOTFS_DIR" apt update
  chroot "$ROOTFS_DIR" apt install -y --no-install-recommends whiptail parted squashfs-tools dosfstools busybox
  mkdir -p "$ROOTFS_DIR/tmp/$INSTALLER_DIR"
  mount --bind "$INSTALLER_DIR" "$ROOTFS_DIR/tmp/$INSTALLER_DIR"

  if [ "$CONFIG_INSTALLER_KERNEL_VERSION" != "" -a "$CONFIG_INSTALLER_KERNEL_VERSION" != "auto" ]; then
    local INSTALLER_KERNEL_VERSION="$CONFIG_INSTALLER_KERNEL_VERSION"
  else
    local INSTALLER_KERNEL_VERSION="$(ls $ROOTFS_DIR/lib/modules | sort -V | tail -1)"
  fi

  chroot "$ROOTFS_DIR" "/tmp/$INSTALLER_DIR/build.sh" "$INSTALLER_KERNEL_VERSION"
  ln -sf "../$INSTALLER_DIR/installer.img" "$BUILD_DIR/"
  build_installer_initrd_cleanup
  trap - EXIT INT
}

pack_rootfs() {
  require_bootstrapped
  EXCLUDE_LIST="var/log/* var/tmp/* var/cache/* var/run/* var/mail/* run/* var/run/* tmp/* root/* root/.* home/* dev/* sys/* proc/* mnt/* media/* debootstrap"
  mksquashfs "$ROOTFS_DIR" "$BUILD_DIR/filesystem.sqfs" -comp xz -noappend -wildcards ${EXCLUDE_LIST:+-e $EXCLUDE_LIST}
  (cd "$BUILD_DIR" && md5sum "filesystem.sqfs" > "filesystem.md5sum")
}

check_target_media_symlinks() {
  local TARGET_MEDIA_DIR="$1"
  for file in "$TARGET_MEDIA_DIR"/*; do
    if [ -h $file -a ! -e $file ]; then
      echo "Error: Broken symlink $file found. Have you run build-installer and pack-rootfs?"
      return 1
    fi
  done
  return 0
}

create_bootable_zip() {
  local TARGET_MEDIA_DIR="$CONFIG_DIR/$CONFIG_NAME/target-media"
  check_target_media_symlinks "$TARGET_MEDIA_DIR"
  FILENAME="loongbian_${CONFIG_SUITE}_${CONFIG_HOSTNAME}_$(date '+%Y%m%d').zip"
  zip -0 -r "$FILENAME" "$TARGET_MEDIA_DIR"
  echo "$FILENAME is ready."
}

create_bootable_iso() {
  local TARGET_MEDIA_DIR="$CONFIG_DIR/$CONFIG_NAME/target-media"
  check_target_media_symlinks "$TARGET_MEDIA_DIR" 
  FILENAME="loongbian_${CONFIG_SUITE}_${CONFIG_HOSTNAME}_$(date '+%Y%m%d').iso"
  genisoimage -V "Loongbian Installer" -f -l -o "$FILENAME" "$TARGET_MEDIA_DIR"
  echo "$FILENAME is ready."
}

clean_all() {
  if [ "$NO_CLEAN_WARNING" != "y" ]; then
    echo "WARNING: All built files will be deleted! Press Ctrl+C now to abort. Sleeping for 5 secs..."
    sleep 5
  fi

  rm -f *.zip
  rm -f *.iso

  if [ ! -d "$ROOTFS_DIR" ]; then
    return 0
  fi

  # extra check
  if ! which findmnt > /dev/null; then
    echo "Error: Could not find findmnt command."
    return 1
  fi
  if ! which fgrep > /dev/null; then
    echo "Error: Could not find fgrep command."
    return 1
  fi
  if ! which realpath > /dev/null; then
    echo "Error: Could not find realpath command."
    return 1
  fi

  if findmnt -lo TARGET | fgrep "$(realpath $ROOTFS_DIR)" > /dev/null; then
    echo "Error: Something is mounted in the target rootfs directory, not cleaning."
    return 1
  fi
  rm -rf --one-file-system "$BUILD_DIR"
}

usage() {
  echo -e \
    "Usage: $0 -c config -m command\n\n" \
    "Available commands:\n" \
    "debootstrap -- debootstrap the base rootfs using qemu-debootstrap\n" \
    "post-debootstrap-setup -- install essential packages, desktop environment, external packages in setup/pkgs, and configure DHCP network for wired network interfaces\n" \
    "build-installer-initrd -- build the installer initrd image\n" \
    "pack-rootfs -- pack the rootfs into a squashfs image and generate its md5sum\n" \
    "create-bootable-iso -- create the bootable installation iso file\n" \
    "all -- everything above\n" \
    "create-bootable-zip -- create the bootable installation zip file (legacy)\n" \
    "clean-all -- clean all built files\n"
}


while [ "$#" -gt 0 ]; do
  case "$1" in
  -c|--config)
    CONFIG_NAME="$2"
    CONFIG_FILE="$CONFIG_DIR/$CONFIG_NAME/config"
    shift 2 || (usage; exit 1)
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  -m|--mode)
    MODE="$2"
    shift 2 || (usage; exit 1)
    ;;
  -y|--no-clean-warning)
    NO_CLEAN_WARNING=y
    shift
    ;;
  *)
    usage
    exit 1
    ;;
  esac
done

if [ "$CONFIG_FILE" = "" ]; then
  usage
  exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: could not find config file $CONFIG_FILE"
  exit 1
fi


source "$CONFIG_FILE"

case "$MODE" in 
debootstrap)
  run_debootstrap
  ;;
post-debootstrap-setup)
  run_post_debootstrap_setup
  ;;
build-installer-initrd)
  build_installer_initrd
  ;;
pack-rootfs)
  pack_rootfs
  ;;
create-bootable-zip)
  create_bootable_zip
  ;;
create-bootable-iso)
  create_bootable_iso
  ;;
all|"")
  clean_all
  run_debootstrap
  run_post_debootstrap_setup
  build_installer_initrd
  pack_rootfs
  create_bootable_iso
  ;;
clean-all)
  clean_all
  ;;
*)
  usage
  exit 1
esac
