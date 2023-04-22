#!/bin/bash

mkdir install-tmp
mv createNFS.bash install-tmp
cd install-tmp


combustion-ISO () {
  wget https://raw.githubusercontent.com/HPPinata/nfsVM/main/combustion.bash
  
  while [ -z "$hashed_password" ]; do echo "Password previously unset or input inconsistent."; \
    hashed_password="$(python3 -c 'import crypt; import getpass; \
    tin = getpass.getpass(); tin2 = getpass.getpass(); print(crypt.crypt(tin)) if (tin == tin2) else ""')"; done
  sed -i "s+HASHchangeME+$hashed_password+g" combustion.bash
  
  mkdir -p disk/combustion
  mv combustion.bash disk/combustion/script
  mkisofs -l -o nfsshare_combustion.iso -V combustion disk
  
  cp nfsshare_combustion.iso /var/lib/vz/template/iso
}


create-TEMPLATE () {
  vmID=99
  vmNAME=microos
  vmDESC="openSUSE MicroOS base template"
  
  qm create $vmID --name $vmNAME --description $vmDESC --cores 1 --memory 1024 --balloon 1024 --net0 model=virtio,bridge=vmbr0 --bios ovmf \
  --ostype l26 --machine q35 --scsihw virtio-scsi-pci --onboot 0 --cdrom none --agent enabled=1 --boot order=virtio0 --efidisk0 local-lvm:4
  
  wget https://download.opensuse.org/tumbleweed/appliances/openSUSE-MicroOS.x86_64-kvm-and-xen.qcow2
  
  qm disk import $vmID openSUSE-MicroOS.x86_64-kvm-and-xen.qcow2 local-lvm
  qm set $vmID --virtio0 local-lvm:vm-$vmID-disk-1
  qm disk resize $vmID virtio0 25G
  
  qm set $vmID template 1
}


create-VM () {
  create-TEMPLATE
  qm clone 99 100 --name nfsshare --description "NFS Server VM"
  
  N=0
  pass=( sda sdb )
  
  for blk in pass; do
    qm set 100 -scsi$N /dev/$blk
    let N++
  done
  
  qm set $vmID --cdrom local:iso/nfsshare_combustion.iso
  qm set $vmID --onboot 1
}


cleanup () {
  cd .. && rm -rf install-tmp
  
  until apt install -y pv; do sleep 5; done
  yes | pv -SpeL1 -s 300 > /dev/null
  apt remove -y pv && apt autoremove -y
  
  qm shutdown $vmID
  qm set $vmID --cdrom none
}


combustion-ISO
create-VM

qm start 100

cleanup
