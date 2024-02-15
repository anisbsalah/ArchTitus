#!/bin/bash

# Checking if is running in Repo Folder
if [[ "$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]')" =~ ^scripts$ ]]; then
	echo "You are running this in ArchTitus Folder."
	echo "Please use ./archtitus.sh instead!"
	exit
fi

# Installing git
echo "[*] Installing git..."
pacman -Sy --noconfirm --needed git glibc

echo "[*] Cloning the ArchTitus Project..."
git clone https://github.com/anisbsalah/ArchTitus.git

echo "[*] Executing ArchTitus Script..."
cd "${HOME}/ArchTitus" || exit 1
exec ./archtitus.sh
