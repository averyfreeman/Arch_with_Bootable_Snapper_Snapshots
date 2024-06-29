#!/usr/bin/env bash
# LICENSE.md in root of repo, please do not distribute without it
export TARGET_PART='/dev/vda2'
export VG_NAME=vg0
export LV_NAME=rootvol

# eye-catching all the things (important)
output(){
    printf '\e[1;34m%-6s\e[m\n' "${@}"
}

echo "unmounting and destroying all the things"
output "#### THIS SCRIPT INDISCRIMINANTLY DESTROYS EVERYTHING IT CAN ####"
output "############             EDIT IT FIRST!             #############"
output "you will probably want to remove some things, and move stuff around"
read -p "Did you edit this file before running it?  Hit ctrl-c and look it over CAREFULLY"
btrfs subvol set-default /mnt
btrfs subvol delete /mnt
umount /mnt/var/lib/{AccountsService,machines,lxc,libvirt/images,gdm,docker,containers,containerd}
umount /mnt/var/{crash,log,spool,tmp,cache} 
umount /mnt/{.snapshots,srv,home,root,boot,@}
umount /mnt
rm -rf /mnt/*
rm -rf /mnt
btrfs device scan -u "/dev/mapper/${VG_NAME}-${LV_NAME}"
lvremove "/dev/mapper/${VG_NAME}-${LV_NAME}"
wipefs -a "/dev/mapper/${VG_NAME}-${LV_NAME}"
lvremove "/dev/mapper/${VG_NAME}-${LV_NAME}"
vgremove "${VG_NAME}"
pvremove "${TARGET_PART}"
