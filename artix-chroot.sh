!#/usr/bin/env bash
bold=$(tput setaf 2 bold)      # makes text bold and sets color to 2
bolderror=$(tput setaf 3 bold) # makes text bold and sets color to 3
normal=$(tput sgr0)            # resets text settings back to normal


error() {\
    printf "%s\n" "${bolderror}ERROR:${normal}\\n%s\\n" "$1" >&2; exit 1;
}


inststuff() {\
    pacman -Sy --noconfirm --needed yay git base-devel fakeroot lightdm lightdm-openrc lightdm-gtk-greeter cinnamon brave-bin
}
inststuff || error "Error installing packages"


addlocales() {
    printf "%s\n" "Enter your locale, you can skip it if you are using the us one e.g. "en_US.UTF-8 UTF-8""
    read alocale
    echo $alocale >> /etc/locale.gen 
    locale-gen
}
addlocales || error "Cannot generate locales"


USERADD() {\
    printf "%s\n" "Choose non-root user account name"
    read username
    useradd -m -G audio,video,wheel $username 
    printf "%s\n" "Enter the account password\n"
    passwd $username
}
USERADD || error "Error adding ${username} to your install"


zfsbootmenu() {
    mkdir -p /efi/EFI/zbm
    wget https://get.zfsbootmenu.org/latest.EFI -O /efi/EFI/zbm/zfsbootmenu.EFI
    efibootmgr --disk ${DISK} --part 1 --create --label "ZFSBootMenu" --loader '\EFI\zbm\zfsbootmenu.EFI' --unicode "spl_hostid=$(hostid) zbm.timeout=3 zbm.prefer=zroot zbm.import_policy=hostid" --verbose
}
zfsbootmenu || error "Error installing zfsbootmenu!"


zfsservice() {\
    pacman -U --noconfirm /install/zfs-openrc-20241023-1-any.pkg.tar.zst
    rc-update add zfs-import boot
    rc-update add zfs-load-key boot
    rc-update add zfs-share boot
    rc-update add zfs-zed boot
    rc-update add zfs-mount boot
}
zfsservice || error "Error installing zfs services"


enableservices() {\
    rc-update add NetworkManager default
    rc-update add lightdm default
    rc-update add dbus default
    rc-update add metalog default
    rc-update add acpid default
    rc-update add bluetoothd default
    rc-update add cronie default
    rc-update add elogind boot
}
enableservices || error "Error enabling Services!"


passwdroot() {\
	printf "%s\n" "${bold}Input your desired password for root"
	passwd
}
passwdroot || error "Wrong password!"


cachefile() {
    printf "%s\n" "${bold}Creating cachefile to be included in initcpio"
    zpool set cachefile=/etc/zfs/zpool.cache rpool_$INST_UUID
}
cachefile || error "Failed to generate cachefile"


regenerate_initcpio() {
   	printf "%s\n" "${bold}Regenerating initramfs"
    mkinitcpio -P
}
regenerate_initcpio || error "Error generating initcpio!!"


inst_zbm() {
    pacman -U --noconfirm install/zfsbootmenu-3.0.1-1-x86_64.pkg.tar.zst
    
}
inst_zbm || error "Failed to install zbm"


printf "%s\n" "Finish!"