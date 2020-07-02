#!/bin/bash

ARCH=mips64el
SUITE=buster
MIRROR_URL=http://mirrors.163.com/debian
TARGET_HOSTNAME=ls2k


BUILD_DIR=build
ROOTFS_DIR="$BUILD_DIR/rootfs"
OVERLAY_UPPER_DIR="$BUILD_DIR/overlay-upper"
OVERLAY_WORK_DIR="$BUILD_DIR/overlay-work"
POST_DEBOOTSTRAP_SETUP_DIR=post-debootstrap-setup
INSTALLER_DIR=installer
TARGET_MEDIA_DIR=target-media

cd "$(dirname $0)"

resolv_workaround() {
  set -e
  mkdir -p "$ROOTFS_DIR/run/systemd/resolve"
  cat "/etc/resolv.conf" > "$ROOTFS_DIR/run/systemd/resolve/stub-resolv.conf"
}

require_bootstrapped() {
  set +e
  if [ ! -d "$ROOTFS_DIR" ]; then
    echo "Error: Could not find target rootfs directory. Have you bootstrapped?"
    set -e
    return 1
  fi
  set -e
  return 0
}

run_debootstrap() {
  set -e
  mkdir -p "$ROOTFS_DIR"
  qemu-debootstrap --arch "$ARCH" "$SUITE" "$ROOTFS_DIR" "$MIRROR_URL"
}

run_post_debootstrap_setup_cleanup() {
  set +e
  umount -q "$ROOTFS_DIR/tmp/$POST_DEBOOTSTRAP_SETUP_DIR"
  set -e
}

run_post_debootstrap_setup() {
  trap run_post_debootstrap_setup_cleanup EXIT
  require_bootstrapped
  resolv_workaround
  mkdir -p "$ROOTFS_DIR/tmp/$POST_DEBOOTSTRAP_SETUP_DIR"
  mount --bind "$POST_DEBOOTSTRAP_SETUP_DIR" "$ROOTFS_DIR/tmp/$POST_DEBOOTSTRAP_SETUP_DIR"
  chroot "$ROOTFS_DIR" "/tmp/$POST_DEBOOTSTRAP_SETUP_DIR/setup.sh"
  run_post_debootstrap_setup_cleanup
  trap - EXIT
}

build_installer_initrd_cleanup() {
  echo "Cleaning up..."
  set +e
  umount -q "$ROOTFS_DIR/proc" 
  umount -q "$ROOTFS_DIR/sys"
  umount -q "$ROOTFS_DIR/tmp/$INSTALLER_DIR"
  umount -q "$ROOTFS_DIR"
  set -e
}

build_installer_initrd() {
  trap build_installer_initrd_cleanup EXIT
  set -e
  require_bootstrapped
  resolv_workaround
  mkdir -p "$OVERLAY_UPPER_DIR" "$OVERLAY_WORK_DIR"
  mount -t overlay overlay -o "lowerdir=$ROOTFS_DIR,upperdir=$OVERLAY_UPPER_DIR,workdir=$OVERLAY_WORK_DIR" "$ROOTFS_DIR"
  mount -t proc proc "$ROOTFS_DIR/proc"
  mount -t sysfs sys "$ROOTFS_DIR/sys"
  chroot "$ROOTFS_DIR" apt update
  chroot "$ROOTFS_DIR" apt install -y gcc whiptail parted squashfs-tools dosfstools
  mkdir -p "$ROOTFS_DIR/tmp/$INSTALLER_DIR"
  mount --bind "$INSTALLER_DIR" "$ROOTFS_DIR/tmp/$INSTALLER_DIR"
  export INSTALLER_MKINITRAMFS_KERNEL_VERSION="$(ls $ROOTFS_DIR/lib/modules | sort -V | tail -1)"
  chroot "$ROOTFS_DIR" "/tmp/$INSTALLER_DIR/build.sh"
  ln -sf "../$INSTALLER_DIR/installer.img" "$BUILD_DIR/"
  build_installer_initrd_cleanup
  trap - EXIT
}

pack_rootfs() {
  set -e
  require_bootstrapped
  EXCLUDE_LIST="/var/log /var/tmp /var/cache /var/run /var/mail /run /var/run /tmp /root /home /dev /sys /proc /mnt /media"
  EXCLUDE_ARGS=
  for dir in $EXCLUDE_LIST; do
    EXCLUDE_ARGS="-e $ROOTFS_DIR/$dir $EXCLUDE_ARGS"
  done
  mksquashfs "$ROOTFS_DIR" "$BUILD_DIR/filesystem.sqfs" -comp xz -noappend $EXCLUDE_ARGS
  (cd "$BUILD_DIR" && md5sum "filesystem.sqfs" > "filesystem.md5sum")
}

create_zipped_installation_file() {
  set +e
  for file in "$TARGET_MEDIA_DIR"/*; do
    if [ -h $file -a ! -e $file ]; then
      echo "Error: Broken symlink $file found. Have you run build-installer and pack-rootfs?"
      return 1
    fi
  done
  set -e
  FILENAME="debian_${SUITE}_${ARCH}_${TARGET_HOSTNAME}_$(date '+%Y%m%d').zip"
  zip -0 -r "$FILENAME" "$TARGET_MEDIA_DIR"
  echo "$FILENAME is ready."
}

clean_all() {
  set +e
  rm -f *.zip

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
  set -e
}

set -e

case $1 in 
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
create-zipped-installation-file)
  create_zipped_installation_file
  ;;
all)
  run_debootstrap
  run_post_debootstrap_setup
  build_installer_initrd
  pack_rootfs
  create_zipped_installation_file
  ;;
clean-all)
  clean_all
  ;;
*)
  echo -e \
    "Usage: $0 command\n\n" \
    "Available commands:\n" \
    "debootstrap -- debootstrap the base rootfs using qemu-debootstrap\n" \
    "post-debootstrap-setup -- install essential packages, desktop environment, external packages in setup/pkgs, and configure DHCP network for wired network interfaces\n" \
    "build-installer-initrd -- build the installer initrd image\n" \
    "pack-rootfs -- pack the rootfs into a squashfs image and generate its md5sum\n" \
    "create-zipped-installation-file -- create the ready-to-use installation zip file\n" \
    "all -- everything above\n" \
    "clean-all -- clean all built files\n"
  exit 1
esac
