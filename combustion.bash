#!/bin/bash
# combustion: network

echo 'root:HASHchangeME' | chpasswd -e
echo 'nfsshare' > /etc/hostname
mount /dev/xvda4 /var

mount /dev/sr1 /mnt
zypper rm -yu xen-tools-domU
/mnt/Linux/install.sh -d sles -m 15 -n

echo 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/root.conf

zypper in -y bcache-tools nfs-kernel-server parted zram-generator
systemctl enable nfs-server

cat <<'EOL' > /etc/systemd/zram-generator.conf
[zram0]

zram-size = ram
compression-algorithm = zstd
EOL

wipefs -f -a /dev/xvdd /dev/xvde /dev/xvdf
parted -s -a optimal /dev/xvdd 'mklabel gpt mkpart primary 0% 100%'
parted -s -a optimal /dev/xvde 'mklabel gpt mkpart primary 0% 100%'
parted -s -a optimal /dev/xvdf 'mklabel gpt mkpart primary 0% 100%'

make-bcache -B /dev/xvde1 /dev/xvdf1
make-bcache -C /dev/xvdd1
for i in $(find /dev/ -iname bcache* -printf '%f\n'); do
bcache-super-show /dev/xvdd1 | grep cset.uuid | awk -F ' ' {'print $2'} > /sys/block/$i/bcache/attach
done

mkfs.btrfs -f -L data -m raid1 -d raid1 /dev/bcache0 /dev/bcache1
mkdir -p /var/nfsshare
mount /dev/bcache0 /var/nfsshare

{ echo; echo '/dev/bcache0  /var/nfsshare  btrfs  nofail  0  2'; } >> /etc/fstab
cat /etc/fstab

mkdir -p /var/nfsshare/xen
mkdir -p /var/nfsshare/net

echo '/var/nfsshare/xen  *(rw,no_root_squash)' >> /etc/exports
echo '/var/nfsshare/net  *(rw,no_root_squash)' >> /etc/exports

mkdir -p /var/nfsshare/xen/sr
mkdir -p /var/nfsshare/xen/iso
