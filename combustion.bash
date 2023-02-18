#!/bin/bash
# combustion: network

echo 'root:HASHchangeME' | chpasswd -e
echo 'nfsshare' > /etc/hostname
mount /dev/xvda4 /var

mount /dev/sr1 /mnt
zypper rm -yu xen-tools-domU
/mnt/Linux/install.sh -d sles -m 15 -n

echo 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/root.conf

zypper in -y nfs-kernel-server parted
systemctl enable nfs-server

wipefs -f -a /dev/xvdd /dev/xvde
parted -s -a optimal /dev/xvdd 'mklabel gpt mkpart primary 0% 100%'
parted -s -a optimal /dev/xvde 'mklabel gpt mkpart primary 0% 100%'

mkfs.btrfs -f -L data -m raid1 -d raid1 /dev/xvdd1 /dev/xvde1
mkdir -p /var/nfsshare
mount /dev/xvdd1 /var/nfsshare

{ echo; echo '/dev/xvdd1  /var/nfsshare  btrfs  nofail  0  2'; } >> /etc/fstab
cat /etc/fstab

mkdir -p /var/nfsshare/xen
mkdir -p /var/nfsshare/net

echo '/var/nfsshare/xen  *(rw,no_root_squash)' >> /etc/exports
echo '/var/nfsshare/net  *(rw,no_root_squash)' >> /etc/exports

mkdir -p /var/nfsshare/xen/sr
mkdir -p /var/nfsshare/xen/iso
