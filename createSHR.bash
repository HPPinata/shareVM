#!/bin/bash

apt update
mkdir install-tmp
mv createSHR.bash install-tmp
cd install-tmp


combustion-ISO () {
  wget https://raw.githubusercontent.com/HPPinata/shareVM/proxmox/combustion.bash

  local passvar=1; local passvar2=2
  while [[ "$passvar" != "$passvar2" ]]; do echo "VM/SMB password previously unset or input inconsistent."; \
    read -sp 'Password: ' passvar
    echo
    read -sp 'Confirm: ' passvar2
    echo
  done

  linux_password="$(openssl passwd -6 $passvar)"
  sed -i "s+HASHchangeME+$linux_password+g" combustion.bash

  smb_password="$(iconv -f ASCII -t UTF-16LE <(printf $passvar) | openssl dgst -md4 -provider legacy | awk -F '= ' {'print $2'})"
  sed -i "s+SMBchangeME+$smb_password+g" combustion.bash

  mkdir -p disk/combustion
  mv combustion.bash disk/combustion/script
  mkisofs -l -o netshare_combustion.iso -V combustion disk
  
  cp netshare_combustion.iso /var/lib/pve/local-btrfs/template/iso
}


create-TEMPLATE () {
  tpID=10001
  vmNAME=microos
  vmDESC="openSUSE MicroOS base template"
  
  qm create $tpID \
  --name $vmNAME --description "$vmDESC" --cores 1 --cpu cputype=host --memory 1024 --balloon 1024 --net0 model=virtio,bridge=vmbr0 --bios ovmf --ostype l26 \
  --machine q35 --scsihw virtio-scsi-single --onboot 0 --cdrom none --agent enabled=1 --boot order=virtio0 --efidisk0 local-btrfs:4,efitype=4m,pre-enrolled-keys=1
  
  wget https://download.opensuse.org/tumbleweed/appliances/openSUSE-MicroOS.x86_64-kvm-and-xen.qcow2
  
  qm disk import $tpID openSUSE-MicroOS.x86_64-kvm-and-xen.qcow2 local-btrfs
  qm set $tpID --virtio0 local-btrfs:$tpID/vm-$tpID-disk-1.raw,cache=writeback,discard=on,iothread=1
  qm disk resize $tpID virtio0 25G
  
  qm set $tpID --template 1
}


create-VM () {
  create-TEMPLATE
  vmID=100
  
  qm clone $tpID $vmID --name netshare --description "NAS Server VM"
  qm set $vmID --cores 4 --memory 8192 --balloon 1024 --startup order=0,up=60
  
  qm set $vmID --virtio1 /dev/nvme0n1,discard=on,iothread=1
  
  N=0
  pass=( /dev/sda /dev/sdb )
  
  for blk in ${pass[@]}; do
    qm set $vmID --scsi$N $blk,discard=on,iothread=1
    let N++
  done
  
  qm set $vmID --cdrom local-btrfs:iso/netshare_combustion.iso
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

qm start $vmID

cleanup
