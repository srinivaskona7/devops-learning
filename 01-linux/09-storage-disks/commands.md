# Storage & Disks — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# Privileged container so loop devices and mount work
docker run -it --rm --privileged ubuntu:22.04 bash
apt-get update && apt-get install -y util-linux e2fsprogs >/dev/null
```

## Core commands

```bash
# Tree of block devices + filesystems + UUIDs
lsblk -f
```

```bash
# Custom columns
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE
```

```bash
# UUIDs and types of all block devices
blkid
```

```bash
# Partition tables (root)
fdisk -l
parted -l
```

```bash
# Filesystem free space, human + type column
df -hT
```

```bash
# Inode usage (a fs can be "full" with bytes free)
df -i
```

```bash
# Total of a directory
du -sh /var/log
```

```bash
# All mounts / ad-hoc mount / safe remount read-only
mount
mount /dev/sdb1 /mnt/data
mount -o remount,ro /
```

```bash
# Unmount
umount /mnt/data
```

```bash
# Show mount info for a path
findmnt /home
```

```bash
# Mount everything in /etc/fstab not yet mounted (test before reboot!)
mount -a
```

```bash
# Make a filesystem
mkfs.ext4 /dev/sdb1
mkfs.xfs  /dev/sdb1
```

```bash
# Add swap
mkswap /dev/sdb2 && swapon /dev/sdb2
```

```bash
# Grow a mounted filesystem online
resize2fs /dev/mapper/vg-lv     # ext4
xfs_growfs /mnt/data            # xfs (mount point, NOT device)
```

```bash
# LVM stack: PV → VG → LV → mkfs → mount
pvcreate /dev/sdb1
vgcreate vg_data /dev/sdb1
lvcreate -L 10G -n lv_app vg_data
mkfs.ext4 /dev/vg_data/lv_app
mount /dev/vg_data/lv_app /mnt/app
```

```bash
# Grow an LV then expand the filesystem on it
lvextend -L +5G /dev/vg_data/lv_app
resize2fs /dev/vg_data/lv_app
```

```bash
# Loopback file as a fake disk (great for labs)
dd if=/dev/zero of=/tmp/disk.img bs=1M count=200
LOOP=$(losetup -f --show /tmp/disk.img)
```

```bash
# List / detach loop devices
losetup -a
losetup -d /dev/loop0
```

## Inspection / verification

```bash
# Confirm an fstab entry actually mounts
mount -a && findmnt /mnt/mydata
```

```bash
# Pull the UUID for an fstab entry (stable across reboots)
blkid -s UUID -o value /dev/loop0
```

```bash
# LVM inspection
pvs ; vgs ; lvs
pvdisplay ; vgdisplay ; lvdisplay
```

```bash
# Find what's eating disk in a tree (sorted, human-readable)
du -h --max-depth=1 / 2>/dev/null | sort -rh | head
```

```bash
# Interactive disk usage browser
ncdu /
```

```bash
# Find leaked deleted-but-open files (df vs du discrepancy)
lsof | grep deleted
```

## Cleanup

```bash
# Unmount and detach loop disk
umount /mnt/mydata
losetup -d "$LOOP"
```

```bash
# Remove a fstab line by UUID match
sed -i "\|UUID=$UUID|d" /etc/fstab
```

## One-liners worth memorising

```bash
# Add a mount to fstab safely (UUID + nofail)
echo "UUID=$(blkid -s UUID -o value /dev/loop0)  /mnt/mydata  ext4  defaults,nofail  0  2" >> /etc/fstab
```

```bash
# Fastest "what's full" snapshot
df -hT | grep -v tmpfs && du -h --max-depth=1 / 2>/dev/null | sort -rh | head
```

```bash
# Create + attach a 100 MB virtual disk in one block
dd if=/dev/zero of=/tmp/disk.img bs=1M count=100 && losetup -fP /tmp/disk.img
```

```bash
# Resize the LV to take all free space in the VG, then grow the fs
lvextend -l +100%FREE /dev/vg_data/lv_app && resize2fs /dev/vg_data/lv_app
```

```bash
# Inode usage at a glance — catch "full of small files"
df -i | sort -k5 -rn | head
```
