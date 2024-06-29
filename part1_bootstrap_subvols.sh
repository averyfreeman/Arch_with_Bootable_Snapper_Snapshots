#!/bin/bash
# LICENSE.md in root of repo, please do not distribute without it
export NEW_USER='avery'
# will ask for password later
export CONTINENT=America
export TIMEZONE=Los_Angeles
export LOCALE=en_US
export KEYBOARD_LAYOUT=us

# 16GB of memory allocated as ram disk for swap
export ZRAM_SWAP_SIZE='16384'

export HOSTNAME='posh-otter'
export IFNAME=enp1s0
export BRNAME=br0
export IPADDRESS='192.168.122.51'
export GATEWAY='192.168.122.1'

export TARGET_DISK='/dev/vda'
export ESP=/dev/vda1
export TARGET_PART="/dev/vda2"
export VG_NAME='vg1'
export ROOT_LV_NAME='rootfs'
export LV_SIZE='900G'
export ROOTVOL=/dev/mapper/vg1-rootfs
export BTRFS_ROOT='BTRFS_ROOT'

export GIT_USER_NAME='Avery Freeman'
export GIT_USER_EMAIL='contact@averyfreeman.com'
export GIT_DEFAULT_BRANCH='main'

# bash function to colorfully print all the things
output(){
    printf '\e[1;34m%-6s\e[m\n' "${@}"
}

pacman -Sy

# Arrays of the subvolume shitnado you're about to get hit with
ALL_SUBVOLS=(
    boot
    home
    root
    srv
    var_log
    var_crash
    var_cache
    var_tmp
    var_spool
    var_lib_AccountsService
    var_lib_containerd
    var_lib_containers
    var_lib_docker
    var_lib_gdm
    var_lib_libvirt_images
    var_lib_lxc
    var_lib_machines
)

NOCOW_VOLS=(
    boot
    home
    root
    srv
    var_log
    var_crash
    var_cache
    var_tmp
    var_spool
    var_lib_AccountsService
    var_lib_containerd
    var_lib_containers
    var_lib_docker
    var_lib_gdm
    var_lib_libvirt_images
    var_lib_lxc
    var_lib_machines
)

lvremove $ROOTVOL
vgremove $VG_NAME
pvremove $TARGET_DISK
wipefs -a "$TARGET_DISK"

pvs; vgs; lvs; lsblk 
output "everything should be ZEROED (aka NO PARTITIONS or VOLUMES): look OK?"
output "Note: removal is intentionally not complete - "
output "if any partition or volume remaining, abort now and delete manually"
read -p "Check no 1: PAUSE: hit enter to continue, ctrl-c to abort"

sgdisk -Z "$TARGET_DISK"
sgdisk -g "$TARGET_DISK"
sgdisk -I -n 1:0:+2048M -t 1:ef00 -c 1:'EFI_FS' "$TARGET_DISK"
sgdisk -I -n 2:0:0 -t 2:8300 -c 2:'ROOT_FS' "$TARGET_DISK"

# output "adding lvm stuff"
# output "create volume group"
pvcreate -f -v "$TARGET_PART"
vgcreate -f -v $VG_NAME "$TARGET_PART"
lvcreate -v -L "$LV_SIZE" "$VG_NAME" -n "$ROOT_LV_NAME" --devices "$TARGET_PART"
output "create logical volume"

lsblk
output "Should have VG and LV ready for creating new partitions"
read -p "Check no 2: PAUSE: hit enter to continue, ctrl-c to abort"

## Informing the Kernel of the changes.
output 'Informing the Kernel about the disk changes.'
partprobe "${TARGET_DISK}"

## Formatting the ESP as FAT32.
output 'Formatting the EFI Partition as FAT32 (label EFI_FS).'
mkfs.msdos -F 32 -n EFI_FS "${ESP}"

## Formatting the partition as BTRFS.
output 'Formatting ROOTVOL as BTRFS (label BTRFS_ROOT).'
mkfs.btrfs -L "${BTRFS_ROOT}" "${ROOTVOL}" 
mount "${ROOTVOL}" /mnt
lsblk -f

output "Did the new filesystem on ${TARGET_PART} mount to /mnt properly?"
read -p "Check no 3: PAUSE: hit enter to continue, ctrl-c to abort"

## setting up snapshot infrastructure
output 'Creating BTRFS subvolumes.'
btrfs su cr /mnt/@
btrfs su cr /mnt/@/.snapshots
mkdir -p /mnt/@/.snapshots/1
btrfs su cr /mnt/@/.snapshots/1/snapshot

## Creating rest of BTRFS subvolumes in array.
for SUBVOL in "${ALL_SUBVOLS[@]}"
  do
    btrfs su cr "/mnt/@/${SUBVOL}"
done 

## Disable CoW on subvols we are not taking snapshots of
for NOCOWVOL in "${NOCOW_VOLS[@]}"
  do
    chattr +C "/mnt/@/${NOCOWVOL}"
done 

## Set the default BTRFS Subvol to Snapshot 1 before pacstrapping
output "Setting snapshot no. 1 as default BTRFS subvolume"
btrfs subvolume set-default "$(btrfs subvolume list /mnt | grep "@/.snapshots/1/snapshot" | grep -oP '(?<=ID )[0-9]+')" /mnt
echo '' 
# sanity check
btrfs subvol list /mnt
echo ''
output "very important:"
output "Should be tons of subvols. Default subvol should be @/.snapshots/1/snapshot"
btrfs subvol get-default /mnt

output "Does that sound like what you're seeing here?"
read -p "Check no 4: PAUSE: hit enter to continue, ctrl-c to abort"

export DATE=$(date "+%Y-%m-%d %H:%M:%S")

## This was lifted from OpenSUSE MicroOS snapshot on 20240627
printf "<?xml version=\"1.0\"?>
<snapshot>
  <type>single</type>
  <num>1</num>
  <date>%s</date>
  <description>First Root Filesystem</description>
  <cleanup>number</cleanup>
  <userdata>
    <key>important</key>
    <value>yes</value>
  </userdata>
</snapshot>" $DATE > /mnt/@/.snapshots/1/info.xml

chmod 600 /mnt/@/.snapshots/1/info.xml
cat /mnt/@/.snapshots/1/info.xml

# btrfs subvol list /mnt
ls -la /mnt/@/.snapshots/1
output "Was info.xml file to identify snapshot no. 1 created OK?"
read -p "Check no 5: PAUSE: hit enter to continue, ctrl-c to abort"

## Mounting the newly created subvolumes.
umount /mnt
output 'Creating mount dirs and mounting all our newly created subvolumes on them.'
mount -o ssd,noatime,compress=zstd "${ROOTVOL}" /mnt
mkdir -p /mnt/{boot,home,root,.snapshots,srv,tmp}
mkdir -p /mnt/var/{cache,crash,log,spool,tmp}
mkdir -p /mnt/var/lib/{AccountsService,containerd,containers,docker,gdm,libvirt/images,lxc,machines}

mount -o ssd,noatime,compress=zstd,nodev,nosuid,noexec,subvol=@/boot "${ROOTVOL}" /mnt/boot
mount -o ssd,noatime,compress=zstd,nodev,nosuid,subvol=@/root "${ROOTVOL}" /mnt/root
mount -o ssd,noatime,compress=zstd,nodev,nosuid,subvol=@/home "${ROOTVOL}" /mnt/home
mount -o ssd,noatime,compress=zstd,subvol=@/.snapshots "${ROOTVOL}" /mnt/.snapshots
mount -o ssd,noatime,compress=zstd,subvol=@/srv "${ROOTVOL}" /mnt/srv
mount -o ssd,noatime,compress=zstd,nodatacow,nodev,nosuid,noexec,subvol=@/var_log "${ROOTVOL}" /mnt/var/log
mount -o ssd,noatime,compress=zstd,nodatacow,nodev,nosuid,noexec,subvol=@/var_crash "${ROOTVOL}" /mnt/var/crash
mount -o ssd,noatime,compress=zstd,nodatacow,nodev,nosuid,noexec,subvol=@/var_cache "${ROOTVOL}" /mnt/var/cache
mount -o ssd,noatime,compress=zstd,nodatacow,nodev,nosuid,noexec,subvol=@/var_tmp "${ROOTVOL}" /mnt/var/tmp
mount -o ssd,noatime,compress=zstd,nodatacow,nodev,nosuid,noexec,subvol=@/var_spool "${ROOTVOL}" /mnt/var/spool
mount -o ssd,noatime,compress=zstd,nodatacow,nodev,nosuid,noexec,subvol=@/var_lib_AccountsService "${ROOTVOL}" /mnt/var/lib/AccountsService
mount -o ssd,noatime,compress=zstd,nodatacow,nodev,nosuid,noexec,subvol=@/var_lib_containerd "${ROOTVOL}" /mnt/var/lib/containerd
mount -o ssd,noatime,compress=zstd,nodatacow,nodev,nosuid,noexec,subvol=@/var_lib_containers "${ROOTVOL}" /mnt/var/lib/containers
mount -o ssd,noatime,compress=zstd,nodatacow,nodev,nosuid,noexec,subvol=@/var_lib_docker "${ROOTVOL}" /mnt/var/lib/docker
mount -o ssd,noatime,compress=zstd,nodatacow,nodev,nosuid,noexec,subvol=@/var_lib_gdm "${ROOTVOL}" /mnt/var/lib/gdm
mount -o ssd,noatime,compress=zstd,nodatacow,nodev,nosuid,noexec,subvol=@/var_lib_libvirt_images "${ROOTVOL}" /mnt/var/lib/libvirt/images
mount -o ssd,noatime,compress=zstd,nodatacow,nodev,nosuid,noexec,subvol=@/var_lib_lxc "${ROOTVOL}" /mnt/var/lib/lxc
mount -o ssd,noatime,compress=zstd,nodatacow,nodev,nosuid,noexec,subvol=@/var_lib_machines "${ROOTVOL}" /mnt/var/lib/machines

mkdir -p /mnt/boot/efi
mount -o nodev,nosuid,noexec "${ESP}" /mnt/boot/efi
# sanity check
btrfs subvol list /mnt
btrfs subvol get-default /mnt
ls -ls /mnt/.snapshots/1/snapshot
cat /mnt/.snapshots/1/info.xml
# output "default subvol should be @/.snapshots/1/snapshot"
# lsd --tree --depth 2 /mnt
lsblk
output "Last check on first script - did subvols mount OK?"
read -p "Check no 6: PAUSE: hit enter to continue, ctrl-c to abort"

## Pacstrap
output 'Finished setting up the disk, volume, partitions, and subvol infrastructure'

output "run part2 script to bootstrap required software, and edit some configs"
exit
