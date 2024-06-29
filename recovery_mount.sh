#!/usr/bin/env bash
# LICENSE.md in root of repo, please do not distribute without it
export ESP=/dev/vda1
export ROOTVOL=/dev/mapper/vg-ROOTVOL

echo "Ensure two variables at top of script set to correct volumes. Currently:"
echo "ESP partition is set toL $ESP"
echo "ROOT volume is set to $ROOTVOL"
read -p "if not correct, hit ctrl-c and adjust before re-running script"

export ROOTFLAGS_BOOTPART='ssd,noatime,compress=zstd,nodev,nosuid,noexec,subvol'
export ROOTFLAGS_ROOTPART='ssd,noatime,compress=zstd,nodev,nosuid,subvol'
export ROOTFLAGS_SNAPSHOTS='ssd,noatime,compress=zstd'
export ROOTFLAGS_NODATACOW='ssd,noatime,compress=zstd,nodatacow,nodev,nosuid,noexec,subvol'
export ROOTFLAGS_ESP='nodev,nosuid,noexec'

mount -o "${ROOTFLAGS_BOOTPART}=@/boot" "${ROOTVOL}" /mnt/boot
mount -o "${ROOTFLAGS_ROOTPART}=@/root" "${ROOTVOL}" /mnt/root
mount -o "${ROOTFLAGS_ROOTPART}=@/home" "${ROOTVOL}" /mnt/home
mount -o "${ROOTFLAGS_SNAPSHOTS}=@/.snapshots" "${ROOTVOL}" /mnt/.snapshots
mount -o "${ROOTFLAGS_SNAPSHOTS}=@/srv" "${ROOTVOL}" /mnt/srv
mount -o "${ROOTFLAGS_NODATACOW}=@/var_log" "${ROOTVOL}" /mnt/var/log
mount -o "${ROOTFLAGS_NODATACOW}=@/var_crash" "${ROOTVOL}" /mnt/var/crash
mount -o "${ROOTFLAGS_NODATACOW}=@/var_cache" "${ROOTVOL}" /mnt/var/cache
mount -o "${ROOTFLAGS_NODATACOW}=@/var_tmp" "${ROOTVOL}" /mnt/var/tmp
mount -o "${ROOTFLAGS_NODATACOW}=@/var_spool" "${ROOTVOL}" /mnt/var/spool
mount -o "${ROOTFLAGS_NODATACOW}=@/var_lib_AccountsService" $BTRFS /mnt/var/lib/AccountsService
mount -o "${ROOTFLAGS_NODATACOW}=@/var_lib_containerd" "${ROOTVOL}" /mnt/var/lib/containerd
mount -o "${ROOTFLAGS_NODATACOW}=@/var_lib_containers" "${ROOTVOL}" /mnt/var/lib/containers
mount -o "${ROOTFLAGS_NODATACOW}=@/var_lib_docker" "${ROOTVOL}" /mnt/var/lib/docker
mount -o "${ROOTFLAGS_NODATACOW}=@/var_lib_gdm" "${ROOTVOL}" /mnt/var/lib/gdm
mount -o "${ROOTFLAGS_NODATACOW}=@/var_lib_libvirt_images" "${ROOTVOL}" /mnt/var/lib/libvirt/images
mount -o "${ROOTFLAGS_NODATACOW}=@/var_lib_lxc" "${ROOTVOL}" /mnt/var/lib/lxc
mount -o "${ROOTFLAGS_NODATACOW}=@/var_lib_machines" "${ROOTVOL}" /mnt/var/lib/machines
mount -o "${ROOTFLAGS_ESP} ${ESP}" /mnt/boot/efi