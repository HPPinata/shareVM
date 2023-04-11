#!/bin/bash
# combustion: network

echo 'root:HASHchangeME' | chpasswd -e
echo 'nfsshare' > /etc/hostname
echo 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/root.conf

mount /dev/xvda4 /var
mount /dev/sr1 /mnt

zypper rm -yu xen-tools-domU
/mnt/Linux/install.sh -d sles -m 15 -n

zypper in -y nfs-kernel-server zram-generator
systemctl enable nfs-server

cat <<'EOL' > /etc/systemd/zram-generator.conf
[zram0]

zram-size = ram
compression-algorithm = zstd
EOL

sed -i "s+SELINUX=enforcing+SELINUX=permissive+g" /etc/selinux/config

wipefs -f -a /dev/xvde /dev/xvdf
mkfs.btrfs -f -L data -m raid1 -d raid1 /dev/xvde /dev/xvdf

mkdir -p /var/nfsshare/mnt
mount /dev/xvde /var/nfsshare/mnt

{ echo; echo '/dev/xvde  /var/nfsshare/mnt  btrfs  nofail  0  2'; } >> /etc/fstab
cat /etc/fstab

mkdir /var/nfsshare/mnt/xen
mkdir /var/nfsshare/mnt/net

echo '/var/nfsshare/mnt/xen  *(rw,no_root_squash)' >> /etc/exports
echo '/var/nfsshare/mnt/net  *(rw,no_root_squash)' >> /etc/exports

mkdir /var/nfsshare/mnt/xen/sr
mkdir /var/nfsshare/mnt/xen/iso
