#!/usr/bin/env bash
bold=$(tput setaf 2 bold)      # makes text bold and sets color to 2
bolderror=$(tput setaf 3 bold) # makes text bold and sets color to 3
normal=$(tput sgr0)            # resets text settings back to normal

error() {\
    printf "%s\n" "${bolderror}ERROR:${normal}\\n%s\\n" "$1" >&2; exit 1;
}


chaoticaur() {\
    printf "%s\n" "## Installing Chaotic AUR ##"
    printf "%s" "Adding repo " && printf "%s" "${bold}[chaotic-aur] " && printf "%s\n" "${normal}to /etc/pacman.conf."
    pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com && \
        echo "Receiving key for ${bold}chaotic-aur${normal}."
    pacman-key --lsign-key 3056513887B78AEB && \
       echo "Signing key for ${bold}[chaotic-aur]${normal}."
    pacman -Sy
	yes | LC_ALL=en_US.UTF-8 pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' && \
       echo "Installing keyring for ${bold}[chaotic-aur]${normal}."
    yes | LC_ALL=en_US.UTF-8 pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' && \
       echo "Installing mirrorlist for ${bold}chaotic-aur${normal}."
}
chaoticaur || error "Error installing Chaotic AUR!"


addrepo() {\
    printf "%s\n" "## Adding repos to /etc/pacman.conf."
    # Adding chaotic-aur to pacman.conf
    printf "%s" "Adding repo " && printf "%s" "${bold}[chaotic-aur] " && printf "%s\n" "${normal}to /etc/pacman.conf."
    grep -qxF "[chaotic-aur]" /etc/pacman.conf ||
        ( echo " "; echo "[chaotic-aur]"; \
        echo "Include = /etc/pacman.d/chaotic-mirrorlist") | tee -a /etc/pacman.conf
	 echo " "; echo "[omniverse]"; echo "Server = https://artix.sakamoto.pl/omniverse/\$arch"; echo "Server = https://eu-mirror.artixlinux.org/omniverse/\$arch" ; echo "Server = https://omniverse.artixlinux.org/\$arch" | tee -a /etc/pacman.conf
	 sed -i 's/^#\(\[lib32\]\)/\1/; s/^#\(Include = \/etc\/pacman\.d\/mirrorlist\)/\1/' /etc/pacman.conf
}
addrepo || error "Error adding repos!"


installzfs() {\
	printf "%s\n" "${bold}# Installing the zfs modules"
	pacman -Sy --noconfirm --needed zfs-dkms-git zfs-utils-git gptfdisk artix-archlinux-support
	echo " "; echo "[extra]"; echo "Include = /etc/pacman.d/mirrorlist-arch" | tee -a /etc/pacman.conf
	echo " "; echo "[multilib]"; echo "Include = /etc/pacman.d/mirrorlist-arch" | tee -a /etc/pacman.conf
	pacman -Sy
	modprobe zfs
	printf "%s\n" "${bold}Done!"
}
installzfs || error "Error installing zfs!"


installtz() {\
	printf "%s\n" "${bold}##Setting install variables"
	printf "${bold}Write your timezone in this format: Region/City e.g. Europe/Rome\n"
	read timezone
	printf "%s\n" "${bold}Timezone set to $timezone"
	INST_TZ=/usr/share/zoneinfo/$timezone
}
installtz || error "No timezone provided!"


installhost() {\
	printf "%s\n" "${bold}##Set desired hostname"
	printf "%s\n" "${bold}Write your desired hostname"
	read INST_HOST
}
installhost || error "No hostname given!"


installkrn() {\
	printf "%s\n" "${bold}Write the kernel you want"
	printf "${bold}Choices are linux linux-zen or linux-lts\n"
	read INST_LINVAR
}
installkrn || error "Wrong kernel"


selectdisk() {\
	printf "%s\n" "${bold}##Decide which disk yow want to use"
	ls -lah --color=auto /dev/disk/by-id
	read disk
	DISK=/dev/disk/by-id/$disk
}
selectdisk || error "Disk doesn't exist!"


settingup() {\
	printf "%s\n" "${bold}Creating temporary folder for installation"
	INST_MNT=$(mktemp -d)
	printf "%s\n" "${bold}Giving your zpools a unique identifier"
	INST_UUID=$(dd if=/dev/urandom of=/dev/stdout bs=1 count=100 2>/dev/null |tr -dc 'a-z0-9' | cut -c-6)
}
settingup || error "Setup not done"


swapdim() {\
	printf "%s\n" "${bold}Choose swap size"
	read swsize
}
swapdim || error "No size specified for swap"


partdrive() {\
	printf "%s\n" "${bold}Starting install, it will take time, so go GRUB a cup of coffee"
	printf "%s\n" "${bold}Partitioning drive"
	sgdisk --zap-all $DISK
	sgdisk -n1:0:+1G -t1:EF00 $DISK
	sgdisk -n2:0:+4G -t2:BE00 $DISK
	sgdisk -n3:0:-{swsize}G -t3:BF00 $DISK
	sgdisk -n4:0:0 -t4:8308 $DISK
	partprobe || true
}
partdrive || error "Error setting up the drive!"


bootpart() {\
	printf "%s\n" "${bold}Creating boot partition in ext4"
	mkfs.ext4 $DISK-part2
}
bootpart || error "Error setting up the boot partition"


rootpool() {\
	printf "%s\n" "${bold}Creating root pool"
	zpool create -f -o ashift=12 -O acltype=posixacl -O canmount=off -O compression=zstd -O dnodesize=auto -O normalization=formD -O relatime=on -O xattr=sa -O mountpoint=/ -R $INST_MNT rpool_$INST_UUID $DISK-part3
}
rootpool || error "Error setting up the root pool"


createdatasets() {\
	printf "%s\n" "${bold}Creating datasets"
	zfs create -o canmount=off -o mountpoint=none rpool_$INST_UUID/DATA
	zfs create -o mountpoint=/ -o canmount=on rpool_$INST_UUID/DATA/default
}
createdatasets || error "Error creating the datasets"


mountall() {\
	printf "%s\n" "${bold}Mounting everything"
	zfs mount rpool_$INST_UUID/ROOT/default
	mkdir $INST_MNT/boot
}
mountall || error "Error mounting partitions!"


separate() {\
	printf "%s\n" "${bold}Creating datasets to separate user data from root filesystem"
	zfs create -o mountpoint=/home -o canmount=on rpool_$INST_UUID/DATA/default/home
}
separate || error "Error settig up datasets!"


permissions() {\
	printf "%s\n" "${bold}Giving correct permissions to /root and /var/tmp"
	mkdir $INST_MNT/root
	mkdir -p $INST_MNT/var/tmp
	chmod 750 $INST_MNT/root
	chmod 1777 $INST_MNT/var/tmp
}
permissions || error "Wrong permissions!"


efiswap() {\
	printf "%s\n" "${bold}Formatting and mounting boot, EFI system partition and swap"
	mkswap -L SWAP ${DISK}-part4
	swapon ${DISK}-part4
	mount ${DISK}-part2 $INST_MNT/boot
	mkfs.vfat -n EFI ${DISK}-part1
	mkdir $INST_MNT/boot/efi
	mount -t vfat ${DISK}-part1 $INST_MNT/boot/efi
}
efiswap || error "Error creating/formatting EFI/swap"


installpkgs() {\
	basestrap $INST_MNT - < pkglist.txt
	basestrap $INST_MNT $INST_LINVAR ${INST_LINVAR}-headers linux-firmware zfs-dkms-git zfs-utils-git
	rm -rf $INST_MNT/etc/pacman.d
	rm $INST_MNT/etc/pacman.conf
	cp -r /etc/pacman.d $INST_MNT/etc
	cp /etc/pacman.conf $INST_MNT/etc
}
installpkgs || error "Error installing packages"


fstab() {\
	echo "UUID=$(blkid -s UUID -o value ${DISK}-part2) /boot     ext4 defaults   					   0 2" >> $INST_MNT/etc/fstab
	echo "UUID=$(blkid -s UUID -o value ${DISK}-part1) /boot/efi vfat umask=0022,fmask=0022,dmask=0022 0 1" >> $INST_MNT/etc/fstab
	echo "UUID=$(blkid -s UUID -o value ${DISK}-part4) none		 swap defaults						   0 0" >> $INST_MNT/etc/fstab
}
fstab || error "Error generating fstab"


mkinitram() {\
	mv $INST_MNT/etc/mkinitcpio.conf $INST_MNT/etc/mkinitcpio.conf.back
	tee $INST_MNT/etc/mkinitcpio.conf <<EOF
	HOOKS=(base udev autodetect modconf block keyboard zfs filesystems)
EOF
}
mkinitram || error "Error creating new mkinitcpio"


finishtouch() {\
	echo $INST_HOST > $INST_MNT/etc/hostname
	ln -sf $INST_TZ $INST_MNT/etc/localtime
	echo "en_US.UTF-8 UTF-8" >> $INST_MNT/etc/locale.gen
	echo "LANG=en_US.UTF-8" >> $INST_MNT/etc/locale.conf
	artix-chroot $INST_MNT /bin/bash -c locale-gen
	mkdir $INST_MNT/install
	cp zfs-openrc-20241023-1-any.pkg.tar.zst $INST_MNT/install/
	awk -v n=5 -v s="INST_UUID=${INST_UUID}" 'NR == n {print s} {print}' artix-chroot.sh > artix-chroot-new.sh
	mv artix-chroot-new.sh $INST_MNT/install/artix-chroot.sh
	chmod +x $INST_MNT/install/artix-chroot.sh
	artix-chroot $INST_MNT /bin/bash /install/artix-chroot.sh
}
finishtouch || error "Something went wrong, re-run the script with correct values!" && exportpools 

exportpools() {
	printf "%s\n" "Unmounting partitions and exporting pools"
	rm -rf $INST_MNT/install
	umount $INST_MNT/boot/efi
	umount $INST_MNT/boot
	swapoff $DISK-part4
	zpool export rpool_${INST_UUID}
}
exportpools || error "Something went wrong!"

printf "%s\n" "${bold} You can reboot now!"
printf "%s'n" "${bolderror}If you have any problem open an issue on this scripts repo!!"
