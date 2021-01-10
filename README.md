# Loongson OS Builder for 2k Edu

Build a ready-to-boot Loongson OS image in one command.

Tested on a Debian Buster x86_64 build machine.

## Get the builder

```
git clone https://github.com/Loongbian/loongson-os-builder-2k.git --recursive --depth=1
```

Note the `--recursive` option.

## Prerequisites

As root, run

```
$ apt install binfmt-support qemu qemu-user-static debootstrap 
```

## Build

### Automatically (recommended)

```
$ cd loongson-os-builder-2k
$ ./build.sh -c mips64el-ls2k-lxde
```

Now you get a ready-to-boot installation iso file. You may wish to distribute it.

### Manually

`build.sh` supports a number of different commands.

* `debootstrap`: debootstrap the base rootfs using qemu-debootstrap.
* `setup`: run post-installation setup script: install essential packages, desktop environment, external packages in setup/pkgs, and configure DHCP network for wired network interfaces
* `installer`: build the installer.img initrd image
* `sqfs`: pack the rootfs into a squashfs image and generate its md5sum required by installer.img
* `iso`: create the bootable installation iso file
* `all`: everything above
* `zip`:  create the bootable installation zip file (legacy)
* `clean`: clean all built files

For example, use

```
$ ./build.sh -c mips64el-ls2k-lxde -m debootstrap
```

to run debootstrap only.

## Create a bootable installation media

```
$ dd if=loongbian_buster_mips64el_ls2k_YYYYMMDD.iso of=/dev/sdX bs=1M status=progress
```
