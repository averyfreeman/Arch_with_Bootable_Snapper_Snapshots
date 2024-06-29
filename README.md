# "Unbreakable" Arch (mostly) Unattended Installer

Thanks to Tommy Tran for creating the original interactive version of this script:  https://github.com/TommyTran732/Arch-Setup-Script

I have pared his work down considerably for my own needs/interests, and tightened up the syntax in a few places requiring (mainly) better string substitution.

I removed LUKS. In theory, it's really cool, but In practice, I'm probably ~10 times more likely to lose my credentials, or experience an unrecoverable configuration issue that locks me out indefinitely, than I am to have actors of malintent attempt to access my files. Priorities and circumstances, right? 

Moreover, I've removed links to any additional scripts nested in the original, as it was more important to me personally to engage in understanding the primary functions of the process (some rather complicated, like the subvolume layout, grub modifications, snapper policies, and setting a snapshot as the default mount btrfs subvolume) than implementing ancillary features (even hardening).

Therefore, this rendition does not download any additional scripts to run during setup.  It does run Pacman and download two AUR packages from `chaotic-aur`, but they are only to avoid compiling software during the setup process.  The two 3rd-party packages are `paru` and `snap-pac-grub` (I may remove latter due to conflict - still investigating).  

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
As it will prevent being able to configure the snapshot from which you boot (bad)


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