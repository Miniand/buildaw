#!/bin/sh
#
#  Copyright (c) 2012 Miniand
#  
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.
#  
################################################################################
#  
#  Create an Allwinner A10 compatible image for use on SD cards.
#  
#  Author: Michael Alexander <mick@miniand.com>
#  Site:   <https://github.com/miniand/buildaw>
#
################################################################################

# ENVIRONMENT VARIABLES

# Which directory to do the build in
if [ -z "$BUILD_DIR" ]; then
  BUILD_DIR="build"
fi
# The byte size to send to dd to make the initial image, multiplied by count
# determines the size in bits
if [ -z "$IMAGE_DD_BS" ]; then
  IMAGE_DD_BS="512"
fi
# The count to send to dd to make the initial image, multiplied by byte size
# determines the size in bits
if [ -z "$IMAGE_DD_COUNT" ]; then
  IMAGE_DD_COUNT="7340032"
fi

# Exit immediately on error
set -e

# ENSURE A CLEAN BUILD DIR EXISTS

if [ -d "$BUILD_DIR" ]; then
  echo "Removing existing build directory..."
  rm -rf build
fi
echo "Creating build directory..."
mkdir -p $BUILD_DIR

# CREATE BLANK IMAGE

echo "Creating blank image..."
dd if=/dev/zero of=$BUILD_DIR/output.img bs=$IMAGE_DD_BS count=$IMAGE_DD_COUNT

echo "Creating partitions in image..."
echo "2048,32768
34816" | sfdisk --unit S --force $BUILD_DIR/output.img

# PREPARE BOOT PARTITION

echo "Finding available loopback device for boot block device..."
BOOT_DEVICE=$( losetup -f )

echo "Mounting boot block device to $BOOT_DEVICE..."
losetup -o 1048576 $BOOT_DEVICE $BUILD_DIR/output.img

echo "Formatting boot block device as msdos..."
mkfs.vfat $BOOT_DEVICE

BOOT_MOUNT="$BUILD_DIR/mount/boot"
echo "Mounting boot partition to $BOOT_MOUNT..."
mkdir -p $BOOT_MOUNT
mount $BOOT_DEVICE $BOOT_MOUNT

echo "Copying files into boot partition..."
rsync -r -t -v src/boot/ $BOOT_MOUNT

echo "Unmounting boot partition from $BOOT_MOUNT..."
umount $BOOT_MOUNT

echo "Detaching boot block device from $BOOT_DEVICE..."
losetup -d $BOOT_DEVICE

# PREPARE ROOTFS PARTITION

echo "Finding available loopback device for rootfs block device..."
ROOTFS_DEVICE=$( losetup -f )

echo "Mounting rootfs block device to $ROOTFS_DEVICE..."
losetup -o 1048576 $ROOTFS_DEVICE $BUILD_DIR/output.img

echo "Formatting rootfs block device as ext4..."
mkfs.ext4 $ROOTFS_DEVICE

ROOTFS_MOUNT="$BUILD_DIR/mount/rootfs"
echo "Mounting rootfs partition to $ROOTFS_MOUNT..."
mkdir -p $ROOTFS_MOUNT
mount $ROOTFS_DEVICE $ROOTFS_MOUNT

echo "Extracting rootfs.tgz into partition..."
tar -zxvf src/rootfs/rootfs.tgz --directory $ROOTFS_MOUNT

if [ -d "src/rootfs/extra" ]; then
  echo "Copying extra files into rootfs partition..."
  rsync -r -t -v src/rootfs/extra/ $ROOTFS_MOUNT
fi

echo "Unmounting rootfs partition from $ROOTFS_MOUNT..."
umount $ROOTFS_MOUNT

echo "Detaching rootfs block device from $ROOTFS_DEVICE..."
losetup -d $ROOTFS_DEVICE

echo "Writing u-boot to beginning of image..."
dd if=src/u-boot/u-boot.bin of=$BUILD_DIR/output.img bs=1024 seek=8 conv=notrunc

echo "Ensuring writes have completed..."
sync

echo "Done! Image built at $BUILD_DIR/output.img"
