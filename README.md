# Arch Installer on OpenSUSE-like BTRFS subvolume layout
---
### With GRUB configured to make snapshots available to boot from

Thanks to Tommy Tran for creating the original interactive version of this script:  https://github.com/TommyTran732/Arch-Setup-Script

I have pared his work down considerably for my own needs/interests, and while I might have tightened up the syntax in a few places requiring some hefty string substitution, I mostly just hacked a ton of options and features out of it, and made it so hopefully it wouldn't ask me any questions.

It's not quite there yet.  Turns out, when you are configuring ~18 subvolumes, each with different mount points, it behoves you to slow the process down enough to make sure each stage completes fully - no fun waiting for the script to get all the way through, only to find out something went wrong way back in the beginning!

So I've created pause points, ala "training wheels", that stop and ask you if you're paying attention during some of the most significant areas where an incorrect setting will cascade failure the rest of the way through.  There's a good chance the script won't be configured in a way that it'll remove all your partitions, logical volumes, will miss a subvolume you actually wanted, or won't be configured to bind-mount that volume you wanted instead of a subvol.

Gut check aside:  At the very least, I suggest mounting an ext4 or xfs volume to /var/lib/flatpak, the performance on btrfs is atrocious - if you want to keep them in user folder, there's ~/.local/share/flatpak - docker, containerd, podman (/var/lib/containers) all have the same problem as flatpak (they use a fuse filesystem) and on CoW FS it just sucks - even with CoW turned off (at least, that's how I felt about it.  I will build this into the script eventually, but before that happens, look into doing it for yourself.  

The most logical subvols to use a separate LV or partition for are: 
`/var/lib/{containerd,containers,docker,flatpak,lxc,machines,libvirt}` - 
and about `@var_lib_libvirt_images subvol`, you might as well just do the whole `libvirt` dir, since I wouldn't want to have to roll back my VM settings without my images being rolled back, or vice versa, just because a package installation caused a boot error - right now only the `libvirt/images` dir is mounted `nodatacow`, so I'll need to fix that...

The good thing about the new "non-interactive" layout is I put all the possible variables at the top in both scripts - I broke the script out into 2 chunks, since it's so incredibly long as a failsafe against going all the way through while it's misconfigured - so be sure to check the variables in both `part1.sh` and `part2.sh` - definitely recommend copying and pasting one to the other.  I don't want to put a lot of energy into re-writing it in bash, since I am probably going to port the codebase to Python so it's not so finicky (IMO bash is a little too unpredictable for a script that's even semi-complicated). 

What else... let's see...

I removed LUKS. In theory, it's really cool and helpful. In practice, I'm more afraid I'm going to lose my credentials than I am of someone trying to compromise my system.  Or possibly experience some unrecoverable configuration issue that locks me out indefinitely - it IS Arch Linux, after all, right?  

Perhaps more substantially, I've removed links to any additional scripts nested in the original, as none of the features involved were important, and it seemed like more of a security risk than not setting up LUKS, plus I wanted to focus on the primary functions of the bootstrapping process, and it's definitely a lot more complicated than your average non-subvol layout.  Configuring the grub modifications takes a bit getting used to.  The snapper policies are fascinating, especially the role the default subvol plays in `/etc/fstab` for booting a snapshot, and implementing ancillary features (even hardening or NetworkManager) seemed interruptive for the time being.

Therefore, this rendition does not download any additional scripts to run during setup, except for Pacman long enough to download two AUR packages that are pre-compiled on `chaotic-aur`. They're mainly to avoid compiling software during the bootstrapping process.  The two 3rd-party packages are `paru` and `snap-pac-grub` (check out the latter and see if you think it might conflict with the snapshot default subvol mount in fstab - I'm still on the fence about it, myself).  

Chaotic AUR information is here:  https://github.com/chaotic-aur
(it's a repository of curated and pre-compiled AUR packages - pretty awesome)

As always, go through anything you get like this on the internet with a fine-toothed comb before you consider running it yourself.  Or sandbox it somehow, like in a virtual machine without any networking, in case there's a network-wide proliferating crypto-lock scam embedded somewhere (trust me, it really happens). 

More things this pared down version I worked over _does not have_:
- No variants (desktop vs server). Choose your packages and put them in the first `pacstrap` block.  
- No virtual machine check - you know how to install qemu-ga 
- No option for different network backend - `networkd bridge only` (you're welcome)
- EOF block at end pared down into sections (found original block unpredictable)
- No LUKS (big one, but worth mentioning twice)
- No scripts downloading software from other sources, except 2 AUR .zst packages
- No options to make choices during the process other than to abort --
  - put all your options in the variables at the top of the document, and make
    sure they're consistent across both documents, as well!
- Does not match the style, grace, or stability of original, to be certain 
	- Makes up for it for being FAF, and won't ask you any questions if you remove all the `read -p` statements (that's for you to decide if you still need training wheels!)

	What it does have the original doesn't:
- Sets up a volume group and logical volume for the filesystem, before BTRFS vol
- A few extra subvols to support GDM and AccountsService, regardless of Gnome
- Subvols to ensure `nodatacow` on `Docker`, `Containerd,`,`podman (/var/lib/containers)`, and `lxc` (did I miss anything?)
- Many `echos` for creating/modifying text files are instead `printf statements`
- Substituting `%s` `$STRING` for chunk-embedded `$VARS` (thanks, `Shellcheck`!)
- The purely preferenial, such as pipes for `sed` (_you can use hashtags?!_)
- Additional modifications of `pacman.conf`: 
  -`Color`, `ILoveCandy`, `VerbosePkgLists` and `ParallelDownloads = 10`.  
	- May add `grub` to `IgnorePkg` as sane new user default since `grub` vulnerable
- Copy of `update_grub.sh` script sent to `/usr/local/bin/update-grub`
		- Recommend running whenever concerned (I should really create a pacman hook)
		- Important: run `grep subvol /etc/grub.d/10_linux` as often as you feel justifyably anxious about accidentally overwriting a modified package
		 - Always make sure you have this line:

```
        GRUB_CMDLINE_LINUX=" ${GRUB_CMDLINE_LINUX}"

```
	
	Instead of this one (the default):


```
	    GRUB_CMDLINE_LINUX="rootflags=subvol=${rootsubvol} ${GRUB_CMDLINE_LINUX}"
```
As it will prevent snapper from configuring which snapshot you'll boot from (very bad)


-- That's enough info from me for now. Don't forget there are parts 1 and 2, and there are some sanity checks while it goes through the process - stick around for questions it asks, and to hit any key to continue if you're satisfied everything is up to snuff.

The `opensuse-style`  layout of `btrfs` subvols is intricate, but its complexity creates a huge number of mount requirements no user is likely to be able to remember, therefore I created scripts for mounting and unmounting the subvols during situations where you need manual intervention for recovery 
(careful, the unmount one has a bunch of deletion and lv/vg removal in it, too!)    



[![ShellCheck](https://github.com/TommyTran732/Arch-Setup-Script/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/TommyTran732/Arch-Setup-Script/actions/workflows/shellcheck.yml)

This is my installer for Arch Linux. It sets up a BTRFS system with encrypted `/boot` and full snapper support (both snapshotting and rollback work!). It also includes various system hardening configurations.

The script is based on [easy-arch](https://github.com/classy-giraffe/easy-arch). However, it diverges substantially from the original project does not follow its development.

Visit my Matrix group: https://invite.arcticfoxes.net/#/#tommy:arcticfoxes.net

### How to use it?
1. Download an Arch Linux ISO from [here](https://archlinux.org/download/)
2. Flash the ISO onto an [USB Flash Drive](https://wiki.archlinux.org/index.php/USB_flash_installation_medium).
3. Boot the live environment.
4. Connect to the internet.
5. `git clone https://github.com/tommytran732/Arch-Setup-Script/`
6. `cd Arch-Setup-Script`
7. `chmod u+x ./install.sh`
8. `./install.sh`

### Snapper behavior
The partition layout I use allows us to replicate the behavior found in openSUSE 🦎
1. Snapper rollback <number> works! You will no longer need to manually rollback from a live USB like you would with the @ and @home layout suggested in the Arch Wiki.
2. You can boot into a readonly snapshot! GDM and other services will start normally so you can get in and verify that everything works before rolling back.
3. Automatic snapshots on pacman install/update/remove operations
4. Directories such as `/boot`, `/boot/efi`, `/var/log`, `/var/crash`, `/var/tmp`, `/var/spool`, /`var/lib/libvirt/images` are excluded from the snapshots as they either should be persistent or are just temporary files. `/cryptkey` is excluded as we do not want the encryption key to be included in the snapshots, which could be sent to another device as a backup.
5. GRUB will boot into the default BTRFS snapshot set by snapper. Like on openSUSE, your running system will always be a read-write snapshot in `@/.snapshots/X/snapshot`. 

### Security considerations

Since this is an encrypted `/boot` setup, GRUB will prompt you for your encryption password and decrypt the drive so that it can access the kernel and initramfs. I am unaware of any way to make it use a TPM + PIN setup.

The implication of this is that an attacker can change your secure boot state with a programmer, replace your grubx64.efi and it will not be detected until its too late.

This type of attack can theoratically be solved by splitting /boot out to a seperate partition and encrypt the root filesystem separately. The key protector for the root filesystem can then be sealed to a TPM with PCR 0+1+2+3+5+7+14. It is a bit more complicated to set up so my installer does not support this (yet!).