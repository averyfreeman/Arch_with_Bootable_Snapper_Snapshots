#!/usr/bin/env bash
# LICENSE.md in root of repo, please do not distribute without it
set +v
export NEW_USER='avery'
# will be asked to enter password
export CONTINENT=America
export TIMEZONE=Los_Angeles
export LOCALE=en_US.UTF-8
export KEYBOARD_LAYOUT=us

# 16GB of memory allocated as ram disk for swap
export ZRAM_SWAP_SIZE='16384'

export HOSTNAME='posh-otter'
export IFNAME=enp1s0
export BRNAME=br0
export IPADDRESS='192.168.122.51/24'
export GATEWAY='192.168.122.1'

export TARGET_DISK='/dev/vda'
export ESP=/dev/vda1
export TARGET_PART="/dev/vda2"
export VG_NAME='vg1'
export ROOT_LV_NAME='rootfs'
export LV_SIZE='900G'
export ROOTVOL="/dev/mapper/${VG_NAME}-${ROOT_LV_NAME}"
export BTRFS_LABEL='BTRFS_ROOT'

export GIT_USER_NAME='Avery Freeman'
export GIT_USER_EMAIL='contact@averyfreeman.com'
export GIT_DEFAULT_BRANCH='main'

# for printing fancy, eye-catching messages
output(){
    printf '\e[1;34m%-6s\e[m\n' "${@}"
}

output "Please note, this installer almost certainly has problems. Keep a"
output "close eye on it, and be prepared to hit ctrl-c if necessary. Like"
output "the last script, I put a couple sanity checks in it to make sure"
output "you are paying attention.  The complexity of this process means even"
output "slight differences in system config could create a gulf of disparity in"
output "success level"
read -p "Check no 1: PAUSE: hit ctrl-c to abort, any other key to continue"

## Pacstrap
output 'Installing the base system (it may take a while).'

output "You may see an error when mkinitcpio tries to generate a new initramfs."
output "It is okay. The script will regenerate the initramfs later in the installation process."

# pacstrap /mnt base efibootmgr grub grub-btrfs lvm2 thin-provisioning-tools openssh terminus-font linux linux-headers linux-firmware sbctl snapper sudo zram-generator intel-ucode efifs openssh nano sbsigntools git arch-install-scripts wget pydf efifs
output "Generating /etc/fstab based on current mounts:"
genfstab -t PARTUUID /mnt > /mnt/etc/fstab

output "removing explicit reference to default subvol in fstab, so snapper can modify"
sed -i 's|,subvolid=258,subvol=/@/.snapshots/1/snapshot,subvol=@/.snapshots/1/snapshot||g' /mnt/etc/fstab

output "Important: Stop. Ensure fstab generated. First line /dev/mapper/$VG_NAME-$ROOT_LV_NAME should NOT have a subvol"
output "specified.  This allows snapper to set subvol dynamically, so you can boot from different subvols,"
output "which in practice generally means bootable snapshots for file recovery"

echo "2-line head of your current fstab:"
head -n 2 /etc/fstab

echo "First line mount options should look like this (subvolume not specified):"
echo " . . .  btrfs       rw,relatime,discard=async,space_cache=v2 [no subvol]. . ."
echo "The section that should have been removed from fstab: "
echo ". . . ,subvolid=258,subvol=/@/.snapshots/1/snapshot,subvol=@/.snapshots/1/snapshot . . ."

output "If it hasn't been removed from your fstab, hit ctrl-c and refine script"
output "or remove explicit subvol reference manually in text editor (ESSENTIAL!)"
read -p "Check no 2: PAUSE: hit ctrl-c to abort, any other key to continue"

pacstrap /mnt apparmor base base-devel man-db wget git chrony efibootmgr firewalld arch-install-scripts inotify-tools lvm2 thin-provisioning-tools zsh terminus-font linux linux-headers linux-firmware sbctl snapper vim vim-airline vim-airline-themes vim-runtime powerline-vim reflector sudo zram-generator intel-ucode efifs openssh pydf podman distrobox linux-zen linux-zen-headers micro nano gnome virt-manager rsync

# creating zram swap dev
printf "[zram0]
zram-size = %s
compression-algorithm = zstd\n" $ZRAM_SWAP_SIZE \
    > /etc/systemd/zram-generator.conf

# locale preferences, hosts, hostname, initrd prefs (vconsole)
echo "$HOSTNAME" > /mnt/etc/hostname
echo 'Setting hosts file.'
echo "127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain   $HOSTNAME
192.168.1.51   $HOSTNAME.localdomain   $HOSTNAME" > /mnt/etc/hosts
echo "$LOCALE UTF-8"  > /mnt/etc/locale.gen
echo "LANG=$LOCALE" > /mnt/etc/locale.conf
printf "KEYMAP=$KEYBOARD_LAYOUT
FONT=ter-v28b
XKBLAYOUT=us
XKBMODEL=pc105+inet
XKBOPTIONS=terminate:ctrl_alt_bksp\n"\
    > /mnt/etc/vconsole.conf


cp /mnt/etc/mkinitcpio.conf /mnt/etc/mkinitcpio.conf.original

echo 'MODULES=(btrfs)
BINARIES=()
# systemd-networkd linux bridge
FILES=()
HOOKS=(systemd autodetect btrfs microcode modconf keyboard sd-vconsole lvm2 block)
COMPRESSION="zstd"
#COMPRESSION_OPTIONS=()
#MODULES_DECOMPRESS="no"' > /mnt/etc/mkinitcpio.conf

# ## Do not preload part_msdos
sed -i 's/ part_msdos//g' /mnt/etc/default/grub

# ## Ensure correct GRUB settings
echo '' >> /mnt/etc/default/grub
echo '# Default to linux-zen
GRUB_DEFAULT="2>1"'

# Booting with BTRFS subvolume
echo 'GRUB_BTRFS_OVERRIDE_BOOT_PARTITION_DETECTION=true' >> /mnt/etc/default/grub

sed -i 's|GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"|GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 intel_iommu=on iommu=pt i915.enable_guc=2 i915.enable_gvt=true"|g' /mnt/etc/default/grub
sed -i 's/rootflags=subvol=$rootsubvol//g' /mnt/etc/grub.d/10_linux
sed -i 's/rootflags=subvol=$rootsubvol//g' /mnt/etc/grub.d/20_linux_xen
sed -i 's|#PermitRootLogin prohibit-password|PermitRootLogin yes|g' /mnt/etc/ssh/sshd_config

printf "[Match]\nName=$IFNAME\n\n[Network]\nBridge=$BRNAME\n" \
        > /mnt/etc/systemd/network/20-$IFNAME-$BRNAME-slave.network
printf "[NetDev]\nName=$BRNAME\nKind=bridge\n\n[Bridge]\nSTP=yes\n" \
        > /mnt/etc/systemd/network/20-bridge-$BRNAME.netdev
printf "[Match]\nName=$BRNAME\n\n\
[Network]\nAddress=$IPADDRESS\nGateway=$GATEWAY\n\
DNS=1.1.1.1\nDNS=1.0.0.1\n" \
        > /mnt/etc/systemd/network/20-bridge-$BRNAME.network

grep 'NOPASSWD: ALL' /mnt/etc/sudoers > /mnt/etc/sudoers.d/wheel_nopasswd.conf
sed -i 's|# %wheel ALL=(ALL:ALL) NOPASSWD: ALL|%wheel ALL=(ALL:ALL) NOPASSWD: ALL|g' /mnt/etc/sudoers.d/wheel_nopasswd.conf
sed -i 's|#Color|Color|g' /mnt/etc/pacman.conf
sed -i 's|#VerbosePkgLists|VerbosePkgLists|g' /mnt/etc/pacman.conf
sed -i 's|#ParallelDownloads = 5|ParallelDownloads = 10\nILoveCandy\n|g' /mnt/etc/pacman.conf
rm /mnt/etc/resolv.conf
printf 'nameserver 1.1.1.1\nnameserver 1.0.0.1' > /mnt/etc/resolv.conf

arch-chroot /mnt <<EOF
ln -sf /usr/share/zoneinfo/$CONTINENT/$TIMEZONE /etc/localtime
hwclock --systohc
locale-gen
sbctl create-keys
chmod 600 /boot/initramfs-linux*
mkinitcpio -P
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --disable-shim-lock
grub-mkconfig -o /boot/grub/grub.cfg
EOF

# snap-pac has to be installed after grub
pacstrap /mnt snap-pac 
# these removals of the subvol reference in /etc/grub.d/{10,20}_linux{_xen}
# may or may not be necessary.  Grub should not attach any subvol to the
# CMDLINE, like this:
#
# case x"$GRUB_FS" in
#     xbtrfs)
#     rootsubvol="`make_system_path_relative_to_its_root /`"
#     rootsubvol="${rootsubvol#/}"
#     if [ "x${rootsubvol}" != x ]; then
#         GRUB_CMDLINE_LINUX=" ${GRUB_CMDLINE_LINUX}"
#     fi;;
#     xzfs)
#     rpool=`${grub_probe} --device ${GRUB_DEVICE} --target=fs_label 2>/dev/null || true`
#     bootfs="`make_system_path_relative_to_its_root / | sed -e "s,@$,,"`"
#     LINUX_ROOT_DEVICE="ZFS=${rpool}${bootfs%/}"
#     ;;
# esac
# 
# If it has:
#
# if [ "x${rootsubvol}" != x ]; then
#         GRUB_CMDLINE_LINUX="rootflags=subvol=${rootsubvol} ${GRUB_CMDLINE_LINUX}"
#     fi;;
#
# uncomment these two lines:
# sed -i 's/rootflags=subvol=${rootsubvol}//g' /mnt/etc/grub.d/20_linux_xen
# sed -i 's/rootflags=subvol=${rootsubvol}//g' /mnt/etc/grub.d/10_linux
cp -rv /mnt/usr/lib/efifs-x64 /mnt/boot/efi/EFI/drivers

output "Are you ready to set systemd units and unmount?"
output "Check /boot/efi, mounts, and /etc/grub.d/10_linux before going forward"
output "Also check that the default is set in snapper, and that the .snapshots line"
read -p "is deleted from /etc/fstab"
arch-chroot /mnt

arch-chroot /mnt <<EOF
useradd -m $NEW_USER
usermod -aG wheel $NEW_USER
EOF

output 'enter password for root and your new user (passwd name for each)' 
arch-chroot /mnt  
arch-chroot /mnt "chsh $NEW_USER -s /bin/zsh"

arch-chroot /mnt <<EOF
git config --global user.name $GIT_USER_NAME
git config --global user.email $GIT_USER_EMAIL
git config --global init.defaultBranch $GIT_DEFAULT_BRANCH
EOF

arch-chroot /mnt <<EOF
umount /.snapshots
rm -r /.snapshots
snapper --no-dbus -c root create-config /
snapper --no-dbus set-config TIMELINE_CREATE=no
snapper --no-dbus set-config TIMELINE_LIMIT_DAILY=50
snapper --no-dbus set-config TIMELINE_LIMIT_MONTHLY=200
btrfs subvolume delete /.snapshots
mkdir /.snapshots
mount -a
chmod 750 /.snapshots
EOF

arch-chroot /mnt <<EOF
wget https://builds.garudalinux.org/repos/chaotic-aur/x86_64/paru-2.0.3-1-x86_64.pkg.tar.zst
pacman -U --noconfirm paru-2.0.3-1-x86_64.pkg.tar.zst
wget https://builds.garudalinux.org/repos/chaotic-aur/x86_64/snap-pac-grub-2.0.3-2-any.pkg.tar.zst
pacman -U --noconfirm snap-pac-grub-2.0.3-2-any.pkg.tar.zst
EOF

output "Are you ready to set systemd units and unmount?"
read -p "PAUSE: hit enter to continue, ctrl-c to abort"

systemctl enable apparmor --root=/mnt
systemctl enable chronyd --root=/mnt
systemctl enable fstrim.timer --root=/mnt
systemctl enable grub-btrfsd.service --root=/mnt
systemctl enable reflector.timer --root=/mnt
systemctl enable snapper-timeline.timer --root=/mnt
systemctl enable snapper-cleanup.timer --root=/mnt
systemctl enable systemd-oomd --root=/mnt
systemctl disable systemd-timesyncd --root=/mnt
systemctl enable systemd-networkd --root=/mnt
systemctl enable gdm --root=/mnt
systemctl enable sshd --root=/mnt
# systemctl enable firewalld --root=/mnt
# systemctl enable systemd-resolved --root=/mnt
# systemctl enable sshd.socket --root=/mnt

## Set umask to 077.
sed -i 's/^UMASK.*/UMASK 077/g' /mnt/etc/login.defs
sed -i 's/^HOME_MODE/#HOME_MODE/g' /mnt/etc/login.defs
sed -i 's/^USERGROUPS_ENAB.*/USERGROUPS_ENAB no/g' /mnt/etc/login.defs
sed -i 's/umask 022/umask 077/g' /mnt/etc/bash.bashrc

output "copying update-grub script to /usr/local/bin - make sure to"
output "run it after every time grub is re-installed"
output "(may also want to list grub in /etc/pacman.conf IgnorePkg)"
chmod +x update_grub.sh 
cp update_grub.sh /mnt/usr/local/bin/update-grub

output " if you want to make further changes, hit ctrl-c and use arch-chroot /mnt."
read -p "otherwise, hit enter for all the subvols to be unmounted so you can reboot"

umount /mnt/.snapshots
umount /mnt/boot/efi
umount /mnt/boot
umount /mnt/home
umount /mnt/root
umount /mnt/srv
umount /mnt/var/log
umount /mnt/var/crash
umount /mnt/var/cache
umount /mnt/var/tmp
umount /mnt/var/spool
umount /mnt/var/lib/AccountsService
umount /mnt/var/lib/containerd
umount /mnt/var/lib/containers
umount /mnt/var/lib/docker
umount /mnt/var/lib/gdm
umount /mnt/var/lib/libvirt/images
umount /mnt/var/lib/lxc
umount /mnt/var/lib/machines
umount /mnt/root
umount /mnt
# Finish up
output "Done, time to reboot and see if this thing works - fingers crossed!"

exit
