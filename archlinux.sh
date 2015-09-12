#!/bin/sh

set -ev

export NEWHOSTNAME=archlinux
export export HDDSIZE=256GB
export PASSWORD=1234
export USER=kunst

parted /dev/sda mklabel gpt
parted /dev/sda mkpart primary fat32 1 512MB
parted /dev/sda mkpart primary btrfs 512MB $HDDSIZE
mkfs.vfat -v -F 32 /dev/sda1
mkfs.btrfs -f /dev/sda2

mount /dev/sda2 /mnt
mkdir -p /mnt/boot
mount /dev/sda1 /mnt/boot

# Install Base system
grep jp /etc/pacman.d/mirrorlist > mirrorlist
cat /etc/pacman.d/mirrorlist >> mirrorlist
cp mirrorlist /etc/pacman.d/mirrorlist
yes "" | pacstrap -i /mnt base base-devel

# fstab
genfstab -U -p /mnt >> /mnt/etc/fstab

# Create Setup Script on chroot environment
cat <<'++EOS'>/mnt/setup.sh
#!/bin/bash
cd

set -ev

echo $NEWHOSTNAME >> /etc/hostname

ln -s /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
echo ja_JP.UTF-8 UTF-8 >> /etc/locale.gen
echo en_US.UTF-8 UTF-8 >> /etc/locale.gen
locale-gen

#echo LANG=en_US.UTF-8 >> /etc/locale.conf
echo LANG=ja_JP.UTF-8 >> /etc/locale.conf
echo KEYMAP=jp106 >> /etc/vconsole.conf

hwclock --systohc --utc

echo root:$PASSWORD | chpasswd

## Add new user
useradd -m -g wheel $USER
echo $USER:$PASSWORD | chpasswd

## Bootloader for UEFI
pacman-db-upgrade
pacman -S grub dosfstools efibootmgr --noconfirm
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=arch_grub --recheck
grub-mkconfig -o /boot/grub/grub.cfg

## Network
cat <<+EOS | xargs pacman -S --noconfirm
  wireless_tools
  wpa_supplicant
  wpa_actiond
  dialog
  ifplugd
+EOS
systemctl enable netctl-auto@wlp2s0
systemctl enable dhcpcd.service

## Package manager
cat <<'+EOS' >> /etc/pacman.conf
[archlinuxfr]
SigLevel = Never
Server = http://repo.archlinux.fr/$arch
+EOS
pacman -Sy --noconfirm yaourt

## X Window System
cat <<+EOS | xargs pacman -S --noconfirm
  xorg-server
  xorg-server-utils
  xorg-xinit
  xorg-xclock
  xterm
  xf86-video-intel
  xf86-input-mouse
  xf86-input-synaptics
  xdm-archlinux
  alsa-utils
+EOS
pacman -Sg xfce4 | awk '{print $2}' | xargs pacman -S --noconfirm
cat <<+EOS | xargs pacman -S --noconfirm
  xfce4-goodies
  gamin
+EOS
systemctl enable xdm-archlinux.service

cat <<+EOS >> .xsession
setxkbmap -model jp106 -layout jp
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS="@im=fcitx"
exec startxfce4
+EOS
chmod +x .xsession
cp .xsession /home/$USER/.xsession
chown $USER:users /home/$USER/.xsession

## DPI
mkdir -p ~/.config/xfce4/xfconf/xfce-perchannel-xml/
mkdir -p /home/$USER/.config/xfce4/xfconf/xfce-perchannel-xml/
cat <<+EOS > ~/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Xft" type="empty">
    <property name="DPI" type="int" value="180"/>
  </property>
</channel>
+EOS
cp ~/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml /home/$USER/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml
chown -R $USER:users /home/$USER/.config

## Font and Input
cat <<+EOS | xargs pacman -S --noconfirm
  otf-ipafont
  fcitx
  fcitx-mozc
  fcitx-configtool
+EOS

## Sound
cat <<+EOS >> /etc/asound.conf
defaults.pcm.card 1
defaults.pcm.device 0
defaults.ctl.card 1
+EOS

## tools
cat <<+EOS | xargs pacman -S --noconfirm
  vim-minimal
  openssh
  zsh
  wget
  git
  tig
  tmux
  chromium
  firefox
  firefox-i18n-ja
  flashplugin
  thunderbird
  thunderbird-i18n-ja
  gimp
+EOS

++EOS

chmod +x /mnt/setup.sh

# Setup chroot environment
arch-chroot /mnt "/setup.sh"

# end
umount -R /mnt
reboot
