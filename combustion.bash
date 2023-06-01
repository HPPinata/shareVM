#!/bin/bash
# combustion: network

echo 'root:HASHchangeME' | chpasswd -e
echo 'netshare' > /etc/hostname
echo 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/root.conf

mount /dev/vda4 /var

zypper in -y bcache-tools cron duperemove nfs-kernel-server \
policycoreutils-python-utils samba snapper zram-generator

systemctl enable smb
systemctl enable nfs-server

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

mkdir -p /var/share/mnt
mount /dev/bcache0 /var/share/mnt

{ echo; echo '/dev/bcache0  /var/share/mnt  btrfs  nofail  0  2'; } >> /etc/fstab

mkdir /var/share/mnt/vms
mkdir /var/share/mnt/net

{ echo 'SMBchangeME'; echo 'SMBchangeME'; } | smbpasswd -a root
pdbedit -u root --set-nt-hash 'SMBchangeME'

cat <<'EOL' > /etc/samba/smb.conf
[smb-net]
    comment = user data network share
    path = /var/share/mnt/net
    read only = no
    inherit owner = yes
    inherit permissions = yes
EOL
semanage fcontext -at samba_share_t '/var/share/mnt/net(/.*)?'

echo '/var/share/mnt/vms  proxmox(rw,async,no_root_squash)' >> /etc/exports

mkdir /var/share/mnt/.duperemove

cat <<'EOL' > /var/share/snapper.bash
#!/bin/bash

timedatectl set-timezone Europe/Berlin
localectl set-keymap de

snapper -c data create-config /var/share/mnt
snapper -c data set-config "TIMELINE_CREATE=yes" "TIMELINE_CLEANUP=yes" \
"TIMELINE_LIMIT_HOURLY=24" "TIMELINE_LIMIT_DAILY=7" "TIMELINE_LIMIT_WEEKLY=6" \
"TIMELINE_LIMIT_MONTHLY=0" "TIMELINE_LIMIT_YEARLY=0"

semanage fcontext -at snapperd_data_t '/var/share/mnt/.snapshots(/.*)?'

cat <<'EOF' | crontab -
SHELL=/bin/bash
BASH_ENV=/etc/profile

@reboot fstrim -av
@reboot restorecon -Rv /
#@reboot echo 0 | tee /sys/block/bcache*/bcache/sequential_cutoff
0 6 * * 1 duperemove -dhr -b 64K --dedupe-options=same --hash=xxhash --hashfile=/var/share/mnt/.duperemove/hashfile.db /var/share/mnt
0 5 1 * * rm -rf /var/share/mnt/.duperemove/hashfile.db && btrfs filesystem defragment -r /var/share/mnt
EOF
EOL

cat <<'EOL' | crontab -
SHELL=/bin/bash
BASH_ENV=/etc/profile
@reboot bash /var/share/snapper.bash
EOL
