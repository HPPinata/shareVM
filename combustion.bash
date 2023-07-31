#!/bin/bash
# combustion: network

echo 'root:HASHchangeME' | chpasswd -e
echo 'netshare' > /etc/hostname
echo 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/root.conf

growpart /dev/vda 3
btrfs filesystem resize max /
mount -o subvol=@/var /dev/vda3 /var

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

pass=$(ls /dev/sd*)
wipefs -f -a ${pass[@]} /dev/vdb

bcache make -C /dev/vdb
bcache register /dev/vdb
sleep 1

for blk in ${pass[@]}; do
  bcache make -B $blk
  bcache register $blk
  sleep 1
  bcache attach /dev/vdb $blk
  bcache set-cachemode $blk writeback
done

wipefs -f -a $(find /dev/bcache* -maxdepth 0 -type b)
mkfs.btrfs -f -L data -m raid1 -d raid1 $(find /dev/bcache* -maxdepth 0 -type b)

mkdir -p /var/share/mnt
mount /dev/bcache0 /var/share/mnt

{ echo; echo '/dev/bcache0  /var/share/mnt  btrfs  nofail  0  2'; } >> /etc/fstab

btrfs subvolume create /var/share/mnt/vms
btrfs subvolume create /var/share/mnt/net

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

snapper -c data create-config /var/share/mnt/net
snapper -c data set-config "TIMELINE_CREATE=yes" "TIMELINE_CLEANUP=yes" \
"TIMELINE_LIMIT_HOURLY=24" "TIMELINE_LIMIT_DAILY=7" "TIMELINE_LIMIT_WEEKLY=6" \
"TIMELINE_LIMIT_MONTHLY=0" "TIMELINE_LIMIT_YEARLY=0"

snapper -c data setup-quota
semanage fcontext -at snapperd_data_t '/var/share/mnt/.snapshots(/.*)?'

cat <<'EOF' | crontab -
SHELL=/bin/bash
BASH_ENV=/etc/profile

@reboot restorecon -Rv /
#@reboot echo 0 | tee /sys/block/bcache*/bcache/sequential_cutoff
0 6 * * 1 duperemove -dhr -b 64K --dedupe-options=same,partial --hashfile=/var/share/mnt/.duperemove/hashfile.db /var/share/mnt
0 5 1 * * rm -rf /var/share/mnt/.duperemove/hashfile.db && btrfs filesystem defragment -r /var/share/mnt
0 5 20 * * btrfs scrub start /var/share/mnt
EOF
EOL
chmod +x /var/share/snapper.bash

cat <<'EOL' | crontab -
SHELL=/bin/bash
BASH_ENV=/etc/profile
@reboot bash /var/share/snapper.bash
EOL
