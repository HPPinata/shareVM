# nasVM
This script was created to bring up NFS and SMB shares with bcache in Proxmox without having to pass through an entire drive controller. It creates a VM running openSUSE MicroOS to manage the exports.

## Usage:
```
curl -O https://raw.githubusercontent.com/HPPinata/shareVM/proxmox/createSHR.bash
cat createSHR.bash #look at the things you download
bash createSHR.bash
```

When the script completes the VM shuts down. After the next startup the shares should be reachable on the IP address your DHCP server assigned to the VM (or via the hostname "netshare").

### SEQ_cutoff:
Set bcache sequential cutoff to different value (4M) temporarily
```
echo $(( 1024 * 4096 )) | tee /sys/block/bcache*/bcache/sequential_cutoff
cat /sys/block/bcache*/bcache/sequential_cutoff
```
