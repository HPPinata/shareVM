#!/bin/bash
# combustion: network

echo 'root:HASHchangeME' | chpasswd -e
echo 'nfsshare' > /etc/hostname
echo 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/root.conf

mount /dev/vda4 /var

zypper in -y bees nfs-kernel-server zram-generator
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

mkdir /var/nfsshare/mnt/.beeshome
truncate -s 1g /var/nfsshare/mnt/.beeshome/beeshash.dat

cat <<'EOL' > /etc/systemd/system/bees-dedup.service
[Unit]
Description=Run bees deduplication
After=sysinit.target

[Service]
Type=simple
ExecStart=/usr/bin/bees /var/nfsshare/mnt
CPUAccounting=true
CPUSchedulingPolicy=batch
CPUWeight=12
IOSchedulingClass=idle
IOSchedulingPriority=7
IOWeight=10
KillMode=control-group
KillSignal=SIGTERM
MemoryAccounting=true
Nice=19
Restart=on-abnormal
RuntimeDirectory=bees
StartupCPUWeight=25
StartupIOWeight=25
AmbientCapabilities=CAP_DAC_OVERRIDE CAP_DAC_READ_SEARCH CAP_FOWNER CAP_SYS_ADMIN
PrivateTmp=true

[Install]
WantedBy=basic.target
EOL
systemctl enable /etc/systemd/system/bees-dedup.service
