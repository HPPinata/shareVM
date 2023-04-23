#!/bin/bash
# combustion: network

echo 'root:HASHchangeME' | chpasswd -e
echo 'nfsshare' > /etc/hostname
echo 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/root.conf

mount /dev/vda4 /var

zypper in -y nfs-kernel-server zram-generator
systemctl enable nfs-server

cat <<'EOL' > /etc/systemd/zram-generator.conf
[zram0]

zram-size = ram
compression-algorithm = zstd
EOL

wipefs -f -a /dev/sda /dev/sdb
mkfs.btrfs -f -L data -m raid1 -d raid1 /dev/sda /dev/sdb

mkdir -p /var/nfsshare/mnt
mount /dev/sda /var/nfsshare/mnt

{ echo; echo '/dev/sda  /var/nfsshare/mnt  btrfs  nofail  0  2'; } >> /etc/fstab
cat /etc/fstab

mkdir /var/nfsshare/mnt/vms
mkdir /var/nfsshare/mnt/net

echo '/var/nfsshare/mnt/vms  *(rw,no_root_squash)' >> /etc/exports
echo '/var/nfsshare/mnt/net  *(rw,no_root_squash)' >> /etc/exports
