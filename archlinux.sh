#!/bin/sh

set -euv

NEWHOSTNAME=archlinux
ROOTPASSWD=12345678
HDDSIZE=256GB

parted /dev/sda mklabel gpt
parted /dev/sda mkpart primary fat32 1 1GB
parted /dev/sda mkpart primary btrfs 1GB $HDDSIZE
mkfs.vfat -v -F 32 /dev/sda1
mkfs.btrfs -f /dev/sda2

# Install Base system
mount /dev/sda1 /mnt
grep jp /etc/pacman.d/mirrorlist > mirrorlist
cat /etc/pacman.d/mirrorlist >> mirrorlist
cp mirrorlist /etc/pacman.d/mirrorlist
yes "" | pacstrap -i /mnt base base-devel

# fstab
genfstab -U -p /mnt >> /mnt/etc/fstab

# Create Setup Script on chroot environment
cat <<++EOS>>/mnt/setup.sh
#!/bin/bash
echo $NEWHOSTNAME >> /etc/hostname

ln -s /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
echo en_US.UTF-8 UTF-8 >> /etc/locale.gen
echo ja_JP.UTF-8 UTF-8 >> /etc/locale.gen
locale-gen
echo LANG=en_US.UTF-8 >> /etc/locale.conf
echo KEYMAP=jp106 >> /etc/vconsole.conf

echo root:$ROOTPASSWD | chpasswd

## Network
pacman -S --noconfirm wireless_tools wpa_supplicant wpa_actiond dialog ifplugd
systemctl enable netctl-auto@wlp2s0
systemctl enable dhcpcd.service

## bootloader for UEFI
pacman-db-upgrade
pacman -S grub grub-efi-x86_64 efibootmgr --noconfirm
grub-install --force --recheck /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg

## X Window System
pacman -S --noconfirm xorg-server xorg-server-utils xorg-xinit xorg-xclock xterm
pacman -S --noconfirm xf86-video-intel 
pacman -S --noconfirm slim archlinux-themes-slim slim-themes
pacman -S --noconfirm xfce4 xfce4-goodies gamin
pacman -S --noconfirm mozc ibus-mozc emacs-mozc
systemctl enable slim.service
cp /etc/skel/.xinitrc ~/
sed -i"" 's/#exec startxfce4/exec startxfce4/g' .xinitrc 
++EOS

chmod +x /mnt/setup.sh

# Setup chroot environment
arch-chroot /mnt "/setup.sh"

# end
umount -R /mnt
reboot
