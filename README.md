# smbVM
This script was created to bring up an SMB share with bcache in Proxmox without having to pass through an entire drive controller. It creates a VM running openSUSE MicroOS to manage the export.

## Usage:
```
wget https://raw.githubusercontent.com/HPPinata/shareVM/proxmox/createSMB.bash
cat createSMB.bash #look at the things you download
bash createSMB.bash
```

When the script completes the VM shuts down. After the next startup the SMB share should be reachable on the IP address your DHCP server assigned to the VM (or via the hostname "smbshare").

### SEQ_cutoff:
Set bcache sequential cutoff to different value (4M) temporarily
```
echo $(( 1024 * 4096 )) | tee /sys/block/bcache*/bcache/sequential_cutoff
cat /sys/block/bcache*/bcache/sequential_cutoff
```
