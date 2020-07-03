# Loongson OS Builder for 2k Edu

Build a ready-to-boot Loongson OS image in one command.

## Get the builder

```
git clone https://github.com/Loongbian/loongson-os-builder-2k.git --recursive
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
$ ./build.sh all
```

Now you can see a ready-to-boot installation zip file. You may wish to distribute it.

### Manually

`build.sh` supports a number of different commands.

* `debootstrap`: debootstrap the base rootfs using qemu-debootstrap.
* `post-debootstrap-setup`: install essential packages, desktop environment, external packages in setup/pkgs, and configure DHCP network for wired network interfaces
* `build-installer-initrd`: build the installer.img initrd image
* `pack-rootfs`: pack the rootfs into a squashfs image and generate its md5sum required by installer.img
* `create-zipped-installation-file`: create the ready-to-boot installation zip file
* `all`: everything above
* `clean-all`: clean all built files

## Create the bootable installation media

```
$ unzip debian_buster_mips64el_ls2k_20200703.zip    # replace the filename with the actual one you have
$ # make sure your USB drive has a DOS (also known as MBR) disk label and has a FAT-32 partition.
$ cp target-media/* /media/usb                      # replace the destination with the mountpoint of your USB drive
```
