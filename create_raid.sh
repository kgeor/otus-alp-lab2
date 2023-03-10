#!/bin/bash
echo "Creating RAID5 array"
mdadm --zero-superblock --force /dev/sd{b,c,d}
mdadm --create /dev/md5 --level=5 --raid-devices=3 /dev/sd{b,c,d}
mkdir /etc/mdadm
echo "DEVICE partitions" > /etc/mdadm/mdadm.conf
mdadm --detail --scan --verbose | awk '/ARRAY/ {print}' >> /etc/mdadm/mdadm.conf
echo "Done" 
echo "Partitioning"
parted /dev/md5 mklabel gpt
#parted /dev/md5 mkpart primary 0% 100% --script
parted /dev/md5 mkpart primary 0% 20%
parted /dev/md5 mkpart primary 20% 40%
parted /dev/md5 mkpart primary 40% 60%
parted /dev/md5 mkpart primary 60% 80%
parted /dev/md5 mkpart primary 80% 100%
for i in $(seq 1 5); do mkfs.ext4 /dev/md5p$i; done
echo "Done"
echo "Mounting new partitions"
mkdir -p /storage/raid5/part{1,2,3,4,5}
for i in $(seq 1 5); do
    echo "/dev/md5p$i /storage/raid5/part$i ext4 defaults 0 0" >> /etc/fstab
done
mount -a
echo "Done"