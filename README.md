# nfsVM
This script was created to bring up a simple NFS share in XCP-ng without having to pass through an entire Controller. It creates a VM to run openSUSE MicroOS and a simple export.

## Usage:
```
wget https://raw.githubusercontent.com/HPPinata/nfsVM/main/createNFS.bash
cat createNFS.bash #look at the things you download
bash createNFS.bash
```

After the script completes the VM reboots, then the NFS share should be reachable on the IP address your DHCP server assigned to the VM (or via the hostname "nfsshare").
