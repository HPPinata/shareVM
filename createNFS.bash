#!/bin/bash

yum upgrade -y && yum autoremove -y
mkdir install-tmp
mv createNFS.bash install-tmp
cd install-tmp

defaultSR=$(xe sr-list name-label="Local storage" | grep uuid | awk -F ': ' {'print $2'})
defaultNET=$(xe network-list bridge=xenbr0 | grep uuid | awk -F ': ' {'print $2'})


add-SR () {
  mkdir /srv/pass_drives
  ln -s /dev/sda /srv/pass_drives/
  ln -s /dev/sdb /srv/pass_drives/
  
  passSR=$(xe sr-create name-label=Pass_Drives type=udev content-type=disk device-config:location=/srv/pass_drives)
}


combustion-ISO () {
  isoSR=$(xe sr-list name-label=LocalISO | grep uuid | awk -F ': ' {'print $2'})
  
  wget https://raw.githubusercontent.com/HPPinata/nfsVM/main/combustion.bash
  
  while [ -z "$hashed_password" ]; do echo "Password previously unset or input inconsistent."; \
    hashed_password="$(python -c 'from __future__ import print_function; import crypt; import getpass; \
    tin = getpass.getpass(); tin2 = getpass.getpass(); print(crypt.crypt(tin)) if (tin == tin2) else ""')"; done
  sed -i "s+HASHchangeME+$hashed_password+g" combustion.bash
  
  mkdir -p disk/combustion
  mv combustion.bash disk/combustion/script
  yum install -y genisoimage
  mkisofs -l -o nfsshare_combustion.iso -V combustion disk
  yum remove -y genisoimage && yum autoremove -y
  
  cp nfsshare_combustion.iso /var/opt/xen/ISO_Store
  xe sr-scan uuid=$isoSR
}


create-VM () {
  vmUID=$(xe vm-install new-name-label=nfsserver new-name-description="NFS-Server VM" template-name-label=MicroOS_Template)
  
  vdiUID=$(xe vm-disk-list uuid=$vmUID | grep -A 1 VDI | grep uuid | awk -F ': ' {'print $2'})
  xe vdi-param-set uuid=$vdiUID name-label=nfsshare
  
  vdiUID=$(xe vdi-list sr-uuid=$passSR | grep -e uuid | grep -v sr | awk -F ': ' {'print $2'})
  N=3
  for D in $vdiUID; do
    xe vbd-create vm-uuid=$vmUID device=$N vdi-uuid=$D
    let N++
  done
  
  xe vm-cd-add cd-name=nfsshare_combustion.iso device=1 uuid=$vmUID
  xe vm-cd-add cd-name=guest-tools.iso device=2 uuid=$vmUID
  
  xe vm-param-set uuid=$vmUID other-config:auto_poweron=true
}


cleanup () {
  cd .. && rm -rf install-tmp
  
  yum install -y pv --enablerepo epel
  yes | pv -SpeL1 -s 300 > /dev/null
  yum remove -y pv && yum autoremove -y
  
  xe vm-shutdown uuid=$vmUID
  xe vm-cd-remove cd-name=nfsshare_combustion.iso uuid=$vmUID
  xe vm-cd-remove cd-name=guest-tools.iso uuid=$vmUID
}

add-SR
combustion-ISO
create-VM

xe vm-start uuid=$vmUID

cleanup
