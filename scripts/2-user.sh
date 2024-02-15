#!/usr/bin/env bash
#
# @file User
# @brief User customizations and AUR package installation.

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
"
echo "[*] sourcing '${HOME}/ArchTitus/configs/setup.conf'..."
source "${HOME}/ArchTitus/configs/setup.conf"

uppercase_desktopenv=$(printf "%s" "${DESKTOP_ENV}" | tr '[:lower:]' '[:upper:]')
echo "
--------------------------------------------------------------------------
 Installing ${uppercase_desktopenv} Desktop Environment
--------------------------------------------------------------------------
"
cd ~ || exit 1
sed -n '/'${INSTALL_TYPE}'/q;p' ~/ArchTitus/pkg-files/"${DESKTOP_ENV}".txt | while read line; do
	if [[ ${line} == '--END OF MINIMAL INSTALL--' ]]; then
		# If selected installation type is FULL, skip the --END OF THE MINIMAL INSTALLATION-- line
		continue
	fi
	echo "[*] INSTALLING: ${line} ..."
	sudo pacman -S --noconfirm --needed "${line}"
done

if [[ ${AUR_HELPER} != none ]]; then
	echo "
--------------------------------------------------------------------------
 Installing AUR Helper: '${AUR_HELPER}'
--------------------------------------------------------------------------
"
	(
		cd ~ || exit 1
		git clone "https://aur.archlinux.org/${AUR_HELPER}.git"
		cd ~/"${AUR_HELPER}" || exit 1
		makepkg -si --noconfirm --needed
	)

	case ${AUR_HELPER} in
	"yay" | "yay-bin")
		aur_command="yay"
		;;
	"paru" | "paru-bin")
		aur_command="paru"
		;;
	"trizen")
		aur_command="trizen"
		;;
	"pikaur")
		aur_command="pikaur"
		;;
	"pakku")
		aur_command="pakku"
		;;
	"aurman")
		aur_command="aurman"
		;;
	"aura")
		aur_command="sudo aura"
		;;
	*) ;;
	esac

	echo "
--------------------------------------------------------------------------
 Installing AUR Packages
--------------------------------------------------------------------------
"
	# sed $INSTALL_TYPE is using install type to check for MINIMAL installation, if it's true, stop
	# stop the script and move on, not installing any more packages below that line
	sed -n '/'${INSTALL_TYPE}'/q;p' ~/ArchTitus/pkg-files/aur-pkgs.txt | while read line; do
		if [[ ${line} == '--END OF MINIMAL INSTALL--' ]]; then
			# If selected installation type is FULL, skip the --END OF THE MINIMAL INSTALLATION-- line
			continue
		fi
		echo "[*] INSTALLING: ${line} ..."
		"${aur_command}" -S --noconfirm --needed "${line}"
	done
fi

echo "
--------------------------------------------------------------------------
 Xorg/Keyboard configuration
--------------------------------------------------------------------------
"
sudo mkdir -p /etc/X11/xorg.conf.d
sudo tee /etc/X11/xorg.conf.d/00-keyboard.conf <<EOF
# Written by systemd-localed(8), read by systemd-localed and Xorg. It's
# probably wise not to edit this file manually. Use localectl(1) to
# update this file.
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "${KEYMAP}"
EndSection
EOF

echo "
--------------------------------------------------------------------------
                     SYSTEM READY FOR 3-post-setup.sh
--------------------------------------------------------------------------
"
sleep 1
clear
exit
