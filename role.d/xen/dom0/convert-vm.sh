#!/bin/bash

die() {
	echo >&2 "$@"
	exit 1
}

[ "$#" -eq 2 ] || die "usage: ${0} <disk-image-file> <target-vmdk>"

ORIG_DISK_IMAGE="${1}"
ORIG_DISK_FILESIZE=$(ls -l "${ORIG_DISK_IMAGE}" | cut -d ' ' -f 5)
ORIG_DISK_FILESIZE_GBYTE=$(expr ${ORIG_DISK_FILESIZE} / 1024 / 1024 / 1024)

TARGET_DISK_IMAGE="${2}"
TARGET_DISK_IMAGE_GBYTE=$(expr ${ORIG_DISK_FILESIZE_GBYTE} + 5)

TMP_IMAGE_FILE=$(mktemp /tmp/conversion.XXXX)

ST=1
STS=10

echo "Converting disk image file ${ORIG_DISK_IMAGE} size ${ORIG_DISK_FILESIZE_GBYTE} GB"

echo "Creating VMDK of ${ORIG_DISK_FILESIZE_GBYTE} GB + 5 GB = ${TARGET_DISK_IMAGE_GBYTE} GB for swap and filesystem tables" 
echo "(${ST}/${STS}) Creating temporary sparse disk image in ${TMP_IMAGE_FILE} of size ${TARGET_DISK_IMAGE_GBYTE} GB"
dd if=/dev/zero of="${TMP_IMAGE_FILE}" bs=1G count=0 seek="${TARGET_DISK_IMAGE_GBYTE}" > /dev/null 2>&1
ST=$(expr ${ST} + 1)

echo "(${ST}/${STS}) Applying partition table to temporary image"
cat << EOF | sfdisk --quiet -L "${TMP_IMAGE_FILE}" > /dev/null 2>&1
# partition table of disk.img
unit: sectors

disk.img1 : start=     2048, size=  8388608, Id=82
disk.img2 : start=  8390656, size= , Id=83, bootable
disk.img3 : start=        0, size=        0, Id= 0
disk.img4 : start=        0, size=        0, Id= 0
EOF
ST=$(expr ${ST} + 1)

echo "(${ST}/${STS}) Attaching the virtual drive to loopback devices"
KPARTX_OUTPUT=$(kpartx -v -a "${TMP_IMAGE_FILE}")
COUNT=0
while read KLINE; do
	DEV=$(echo ${KLINE} | cut -d ' ' -f 3)
	PARTITION_DEV="/dev/mapper/${DEV}"
	if [ "${COUNT}" == "0" ] ; then
		SWAP_DEV="${PARTITION_DEV}"
	fi
	if [ "${COUNT}" == "1" ] ; then
		DISK_DEV="${PARTITION_DEV}"
	fi
	LOOP_DEV=$(echo ${KLINE} | cut -d ' ' -f 8)
	COUNT=$(expr ${COUNT} + 1)
done <<< "${KPARTX_OUTPUT}"

echo "      Found the following devices swap partition ${SWAP_DEV},"
echo "      root partition ${DISK_DEV} on loop device ${LOOP_DEV}"
echo "(${ST}/${STS}) Creating swap space in ${SWAP_DEV}"
mkswap "${SWAP_DEV}" > /dev/null 2>&1
ST=$(expr ${ST} + 1) 

echo "(${ST}/${STS}) Copying Xen disk image to temporary drive image in ${DISK_DEV}"
echo "      This will take some minutes"
cp "${ORIG_DISK_IMAGE}" "${DISK_DEV}"
ST=$(expr ${ST} + 1)

echo "(${ST}/${STS}) Running filesystem check on copied partition"
echo "      Please fix any errors that appear"
e2fsck -f "${DISK_DEV}" #  > /dev/null 2>&1
if [ "$?" -ge 4 ] ; then
	kpartx -d "${TMP_IMAGE_FILE}" > /dev/null 2>&1
	rm "${TMP_IMAGE_FILE}"
	die "You did not fix the errors shown by e2fsck please start over"
fi
ST=$(expr ${ST} + 1)

echo "(${ST}/${STS}) Resizing the disk partition to fit the slightly larger size"
resize2fs "${DISK_DEV}"
ST=$(expr ${ST} + 1)

echo "(${ST}/${STS}) Installing Grub Bootloader"
ROOT_LOOP_DEV=$(losetup -f --show "${DISK_DEV}")
TMP_DIR=$(mktemp -d /tmp/tmproot.XXXX)
mount -o loop "${ROOT_LOOP_DEV}" "${TMP_DIR}"
mount --bind /dev "${TMP_DIR}/dev"
mount -t sysfs sysfs "${TMP_DIR}/sys"
mount -t proc  proc "${TMP_DIR}/proc"
# Inject grub setup script
cp /usr/local/sbin/convert-vm-grub-helper-execute-only-in-vms.sh "${TMP_DIR}/usr/local/sbin/grub.sh"
chmod +x "${TMP_DIR}/usr/local/sbin/grub.sh"
# Script inside vm installed
echo "     Chrooting into disk which is mounted at ${TMP_DIR}"
LANG=C chroot "${TMP_DIR}" /bin/bash -c "/usr/local/sbin/grub.sh ${LOOP_DEV} ${ROOT_LOOP_DEV}"
rm "${TMP_DIR}/usr/local/sbin/grub.sh"
umount "${TMP_DIR}/proc"
umount "${TMP_DIR}/sys"
umount "${TMP_DIR}/dev"
umount "${TMP_DIR}"
rm -r "${TMP_DIR}"
ST=$(expr ${ST} + 1)

echo "(${ST}/${STS}) Detaching the virtual drive from loopback devices"
kpartx -d "${TMP_IMAGE_FILE}" > /dev/null 2>&1
ST=$(expr ${ST} + 1)

echo "(${ST}/${STS}) Converting raw image to VMDK disk"
qemu-img convert "${TMP_IMAGE_FILE}" -O vmdk "${TARGET_DISK_IMAGE}"
ST=$(expr ${ST} + 1)

echo "(${ST}/${STS}) Cleaning up: Deleting temporary sparse disk image"
rm "${TMP_IMAGE_FILE}"
ST=$(expr ${ST} + 1)
