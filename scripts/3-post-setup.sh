#!/usr/bin/env bash
#
# @file Post-Setup
# @brief Finalizing installation configurations and cleaning up after script.

echo "
--------------------------------------------------------------------------
   █████╗ ██████╗  ██████╗██╗  ██╗████████╗██╗████████╗██╗   ██╗███████╗
  ██╔══██╗██╔══██╗██╔════╝██║  ██║╚══██╔══╝██║╚══██╔══╝██║   ██║██╔════╝
  ███████║██████╔╝██║     ███████║   ██║   ██║   ██║   ██║   ██║███████╗
  ██╔══██║██╔══██╗██║     ██╔══██║   ██║   ██║   ██║   ██║   ██║╚════██║
  ██║  ██║██║  ██║╚██████╗██║  ██║   ██║   ██║   ██║   ╚██████╔╝███████║
  ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝   ╚═╝   ╚═╝   ╚═╝    ╚═════╝ ╚══════╝
--------------------------------------------------------------------------
                      Automated Arch Linux Installer
--------------------------------------------------------------------------

Final Setup and Configurations
GRUB EFI Bootloader Install & Check
"
source "${HOME}/ArchTitus/configs/setup.conf"

if [[ -d "/sys/firmware/efi" ]]; then
	grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB "${DISK}"
fi
grub-mkconfig -o /boot/grub/grub.cfg

echo "
--------------------------------------------------------------------------
 Enabling Login Display Manager
--------------------------------------------------------------------------
"
case ${DESKTOP_ENV} in
"cinnamon" | "xfce") systemctl enable lightdm.service ;;
"gnome") systemctl enable gdm.service ;;
"kde") systemctl enable sddm.service ;;
*) ;;
esac

echo "
--------------------------------------------------------------------------
 Enabling Essential Services
--------------------------------------------------------------------------
"
systemctl enable cups.service
echo "  Cups enabled"
ntpd -qg
systemctl enable ntpd.service
echo "  NTP enabled"
systemctl disable dhcpcd.service
echo "  DHCP disabled"
systemctl stop dhcpcd.service
echo "  DHCP stopped"
systemctl enable NetworkManager.service
echo "  NetworkManager enabled"
systemctl enable wpa_supplicant.service
echo "  WPA_SUPPLICANT enabled"
systemctl enable sshd.service
echo "  sshd enabled"
systemctl enable avahi-daemon.service
echo "  Avahi enabled"
systemctl enable bluetooth.service
echo "  Bluetooth enabled"
systemctl enable acpid.service
echo "  ACPID enabled"
systemctl enable tlp.service
echo "  TLP enabled"
systemctl enable reflector.timer
echo "  Reflector enabled"

echo "
--------------------------------------------------------------------------
 Cleaning
--------------------------------------------------------------------------
"
# Remove no password sudo rights
sed -i 's/^%wheel ALL=(ALL) NOPASSWD: ALL/# %wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
# Add sudo rights
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Remove project folder
rm -r "${HOME}/ArchTitus"
rm -r "/home/${USERNAME}/ArchTitus"

# Replace in the same state
cd "$(pwd)" || exit 1

echo "
--------------------------------------------------------------------------
"
sleep 1
