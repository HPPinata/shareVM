#!/bin/bash
# combustion: network

echo 'root:HASHchangeME' | chpasswd -e
echo 'nfsshare' > /etc/hostname
echo 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/root.conf
mount /dev/xvda4 /var

mount /dev/sr1 /mnt
zypper rm -yu xen-tools-domU
/mnt/Linux/install.sh -d sles -m 15 -n

zypper in -y bcache-tools checkpolicy nfs-kernel-server wget zram-generator
systemctl enable nfs-server

cat <<'EOL' > /etc/systemd/zram-generator.conf
[zram0]

zram-size = ram
compression-algorithm = zstd
EOL

wget https://raw.githubusercontent.com/HPPinata/Notizen/main/selinux/xen_shutdown.te
checkmodule -M -m -o xen_shutdown.mod xen_shutdown.te
semodule_package -o xen_shutdown.pp -m xen_shutdown.mod
semodule -i xen_shutdown.pp

mkdir -p /var/nfsshare/mnt

cat <<'EOL' > /var/nfsshare/bcache.bash
#!/bin/bash

modprobe bcache
umount /var/nfsshare/mnt
sleep 1

echo 1 | tee /sys/fs/bcache/*/stop
echo 1 | tee /sys/block/bcache*/bcache/stop
sleep 1

wipefs -f -a /dev/xvdd /dev/xvde /dev/xvdf
sleep 1

make-bcache -B /dev/xvde /dev/xvdf
make-bcache -C /dev/xvdd
sleep 1

bcache-super-show /dev/xvdd | grep cset.uuid | awk -F ' ' {'print $2'} | tee /sys/block/bcache*/bcache/attach

wipefs -f -a /dev/bcache0 /dev/bcache1
mkfs.btrfs -f -L data -m raid1 -d raid1 /dev/bcache0 /dev/bcache1

mount /dev/bcache0 /var/nfsshare/mnt

{ echo; echo '/dev/bcache0  /var/nfsshare/mnt  btrfs  nofail  0  2'; } >> /etc/fstab
cat /etc/fstab

mkdir /var/nfsshare/mnt/xen
mkdir /var/nfsshare/mnt/net

echo '/var/nfsshare/mnt/xen  *(rw,no_root_squash)' >> /etc/exports
echo '/var/nfsshare/mnt/net  *(rw,no_root_squash)' >> /etc/exports

mkdir /var/nfsshare/mnt/xen/sr
mkdir /var/nfsshare/mnt/xen/iso

systemctl disable /etc/systemd/system/bcache-init.service
EOL
chmod +x /var/nfsshare/bcache.bash

cat <<'EOL' > /etc/systemd/system/bcache-init.service
[Unit]
Description=Initialize and format NFS
After=basic.target

[Service]
Type=oneshot
ExecStart=bash -c '/var/nfsshare/bcache.bash'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOL
systemctl enable /etc/systemd/system/bcache-init.service
