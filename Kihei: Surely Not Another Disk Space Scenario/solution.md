# Solution for Kihei: Surely Not Another Disk Space Scenario
## Description
There is a /home/admin/kihei program. Make the changes necessary so it runs succesfully, without deleting the /home/admin/datafile file.

## Problem Analysis
Running the program results in a panic error and the program exits without creating a new file /home/admin/newdatafile.
```bash
./kihei -v
Creating file /home/admin/data/newdatafile with size 1.5GB...
panic: exit status 1

goroutine 1 [running]:
main.main()
        ./main.go:64 +0x47d
```
The program attempts to create a new file /home/admin/data/newdatafile with a size of 1.5GB, but it fails.

### Potential Causes
1. **Insufficient Disk Space**: The partition where /home/admin/datafile is located does not have enough free space to accommodate the new file being created by the kihei program.
2. **File System Quotas**: There may be file system quotas in place that limit the amount of disk space that can be used by the user running the kihei program.
3. **Incorrect File Path**: The kihei program may be attempting to create the new file in a directory that is not writable or does not exist.

## Root Cause
1. Checking the disk space on the partition where /home/admin/datafile is located shows that it is 93% full, with only 592MB of available space, which is insufficient for creating a 1.5GB file.
```bash
df -h /home/admin/datafile
Filesystem      Size  Used Avail Use% Mounted on
/dev/nvme0n1p1  7.7G  6.7G  592M  93% /
```

## Solution
1. **Free Up Disk Space**: Identify and remove unnecessary files or move them to another partition with more available space to free up enough space for the kihei program to create the new file. But as specified, we cannot delete /home/admin/datafile.
2. **Create a LVM Logical Volume**: If there are unused disks available on the system, we can create a new LVM logical volume, format it, and mount it to /home/admin/data to provide additional space for the kihei program to create the new file.
First, check for available disks that can be used to create a new LVM logical volume.
```bash
lsblk -l
NAME       MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
nvme1n1    259:0    0    1G  0 disk
nvme0n1    259:1    0    8G  0 disk
nvme2n1    259:2    0    1G  0 disk
nvme0n1p1  259:3    0  7.9G  0 part /
nvme0n1p14 259:4    0    3M  0 part
nvme0n1p15 259:5    0  124M  0 part /boot/efi
```
In this case, we have two additional disks, /dev/nvme1n1 and /dev/nvme2n1, each with 1GB of space that can be used to create a new LVM logical volume and mount it to /home/admin/data.
```bash
sudo pvcreate /dev/nvme1n1 /dev/nvme2n1
sudo vgcreate vg_data /dev/nvme1n1 /dev/nvme2n1
sudo lvcreate -l 100%FREE -n lv_data vg_data
sudo mkfs.ext4 /dev/vg_data/lv_data
sudo mount /dev/vg_data/lv_data /home/admin/data
sudo chown -R admin:admin /home/admin/data
```
After performing these steps, the /home/admin/data directory will have a new logical volume mounted with sufficient space to accommodate the new file.
Running df -h again shows that /home/admin/data now has 2GB of available space.
```bash
df -h /home/admin/data
Filesystem                   Size  Used Avail Use% Mounted on
/dev/mapper/vg_data-lv_data  2.0G   24K  1.9G   1% /home/admin/data
```

## Verification
Run the kihei program again to verify that it can now create the new file successfully.
It should complete without errors this time and the output should return done.
```bash
./kihei -v
Creating file /home/admin/data/newdatafile with size 1.5GB...
Done.
```