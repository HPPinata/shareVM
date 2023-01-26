#!/bin/bash
# combustion: network

echo 'root:HASHchangeME' | chpasswd -e
echo 'nfsshare' > /etc/hostname

zypper in -y nfs-kernel-server parted
systemctl enable nfs-server
mount /dev/xvda4 /var

echo 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/root.conf

mount /dev/sr1 /mnt
zypper rm -yu xen-tools-domU
/mnt/Linux/install.sh -d sles -m 15 -n

wipefs -f -a /dev/xvdd /dev/xvde
sleep 1
parted -s -a optimal /dev/xvdd 'mklabel gpt mkpart primary 0% 100%'
parted -s -a optimal /dev/xvde 'mklabel gpt mkpart primary 0% 100%'
sleep 1

mkfs.btrfs -f -L data -m raid1 -d raid1 /dev/xvdd1 /dev/xvde1
mkdir -p /var/nfsshare
mount /dev/xvdd1 /var/nfsshare

{ echo; echo '/dev/xvdd1  /var/nfsshare  btrfs  nofail  0  2'; } >> /etc/fstab
cat /etc/fstab

mkdir -p /var/nfsshare/vm
echo '/var/nfsshare/vm  *(rw)' >> /etc/exports
chown -R root:root /var/nfsshare
chmod -R 777 /var/nfsshare
