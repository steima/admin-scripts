#!/bin/bash

die() {
        echo >&2 "$@"
        exit 1
}

[ "$#" -eq 2 ] || die "usage: ${0} <disk-loop> <partition-loop>"

DRIVE="${1}"
PART="${2}"

echo "Fixing /etc/fstab for real hypervisors"
sed -i.bak s/xvda/sda/g /etc/fstab

echo "Installing grub on virtual drive ${DRIVE}, partition ${PART}"

# Avoids apt asking questions
cat << EOF | debconf-set-selections -v
grub2   grub2/linux_cmdline                select   
grub2   grub2/linux_cmdline_default        select   
grub-pc grub-pc/install_devices_empty      select yes
grub-pc grub-pc/install_devices            select  
EOF

# Install grub
apt-get -y install grub-pc

# Setup device map
cat > /boot/grub/device.map << EOF
(hd0)   ${DRIVE}
(hd0,1) ${PART}
EOF

grub-install --no-floppy --grub-mkdevicemap=/boot/grub/device.map ${DRIVE}

update-grub

PART_NODE=${DRIVE:5}

echo "Replacing ${PART_NODE} in /boot/grub/grub.cfg through sda2"

sed -i.bak s/${PART_NODE}/sda2/g /boot/grub/grub.cfg
