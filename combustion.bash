#!/bin/bash
# combustion: network

echo 'root:HASHchangeME' | chpasswd -e
echo 'smbshare' > /etc/hostname
echo 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/root.conf

mount /dev/vda4 /var

zypper in -y bcache-tools cron duperemove policycoreutils-python-utils samba zram-generator
systemctl enable smb

cat <<'EOL' > /etc/systemd/zram-generator.conf
[zram0]

zram-size = ram
compression-algorithm = zstd
EOL

modprobe bcache
echo 1 | tee /sys/fs/bcache/*/stop
echo 1 | tee /sys/block/bcache*/bcache/stop
sleep 1

pass=( /dev/sda /dev/sdb )

wipefs -f -a ${pass[@]} /dev/vdb

for blk in ${pass[@]}; do
  make-bcache -B $blk
  echo $blk > /sys/fs/bcache/register
done
sleep 1

make-bcache -C /dev/vdb
echo /dev/vdb > /sys/fs/bcache/register
sleep 1
bcache-super-show /dev/vdb | grep cset.uuid | awk -F ' ' {'print $2'} | tee /sys/block/bcache*/bcache/attach

echo writeback | tee /sys/block/bcache*/bcache/cache_mode

wipefs -f -a /dev/bcache*
mkfs.btrfs -f -L data -m raid1 -d raid1 /dev/bcache*

mkdir -p /var/smbshare/mnt
mount /dev/bcache0 /var/smbshare/mnt

{ echo; echo '/dev/bcache0  /var/smbshare/mnt  btrfs  nofail  0  2'; } >> /etc/fstab
cat /etc/fstab

mkdir /var/smbshare/mnt/vms
mkdir /var/smbshare/mnt/net

{ echo 'SMBchangeME'; echo 'SMBchangeME'; } | smbpasswd -a root
pdbedit -u root --set-nt-hash 'SMBchangeME'

cat <<'EOL' >> /etc/samba/smb.conf

[smb-sr]
    comment = VM disk network share
    path = /var/smbshare/mnt/vms
    read only = no
    browsable = yes

[smb-net]
    comment = user data network share
    path = /var/smbshare/mnt/net
    read only = no
    browsable = yes
EOL

semanage fcontext -at samba_share_t "/var/smbshare/mnt(/.*)?"
restorecon -Rv /

mkdir /var/smbshare/mnt/.duperemove

cat <<'EOL' | crontab -
BASH_ENV=/etc/profile

6 6 * * 1 duperemove -dhr -b 64K --dedupe-options=same --hash=xxhash --hashfile=/var/smbshare/mnt/.duperemove/hashfile.db /var/smbshare/mnt
5 5 1 * * rm -rf /var/smbshare/mnt/.duperemove/hashfile.db && btrfs filesystem defragment -r /var/smbshare/mnt
EOL
