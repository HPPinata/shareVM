#!/bin/bash
# combustion: network

echo 'root:HASHchangeME' | chpasswd -e
echo 'nfsshare' > /etc/hostname
echo 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/root.conf

mount /dev/vda4 /var

zypper in -y bcache-tools cron duperemove nfs-kernel-server zram-generator
systemctl enable nfs-server

cat <<'EOL' > /etc/systemd/zram-generator.conf
[zram0]

zram-size = ram
compression-algorithm = zstd
EOL

echo 1 | tee /sys/fs/bcache/*/stop
echo 1 | tee /sys/block/bcache*/bcache/stop
sleep 1

wipefs -f -a /dev/sda /dev/sdb /dev/vdb
make-bcache -B /dev/sda /dev/sdb -C /dev/vdb
sleep 1
echo writeback > /sys/block/bcache*/bcache/cache_mode

wipefs -f -a /dev/bcache0 /dev/bcache1

mkfs.btrfs -f -L data -m raid1 -d raid1 /dev/bcache0 /dev/bcache1

mkdir -p /var/nfsshare/mnt
mount /dev/bcache0 /var/nfsshare/mnt

{ echo; echo '/dev/bcache0  /var/nfsshare/mnt  btrfs  nofail  0  2'; } >> /etc/fstab
cat /etc/fstab

mkdir /var/nfsshare/mnt/vms
mkdir /var/nfsshare/mnt/net

echo '/var/nfsshare/mnt/vms  *(rw,async,no_root_squash)' >> /etc/exports
echo '/var/nfsshare/mnt/net  *(rw,async,no_root_squash)' >> /etc/exports

mkdir /var/nfsshare/mnt/.duperemove

cat <<'EOL' | crontab -
6 6 * * 1 duperemove -dhr -b 64K --dedupe-options=same --hash=xxhash --hashfile=/var/nfsshare/mnt/.duperemove/hashfile.db
5 5 1 * * rm -rf /var/nfsshare/mnt/.duperemove/hashfile.db && btrfs filesystem defragment -r /var/nfsshare/mnt
EOL
