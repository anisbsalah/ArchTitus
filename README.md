# ArchTitus: Automated Arch Linux Install Script

[![GitHub Super-Linter](https://github.com/ChrisTitusTech/ArchTitus/workflows/Lint%20Code%20Base/badge.svg)](https://github.com/marketplace/actions/super-linter)

<img src="https://i.imgur.com/YiNMnan.png" />

This is a completely automated Arch Linux installation script.\
It includes prompts to select your desired desktop environment, AUR helper, and whether to do a minimal or a fully functional Arch Linux installation containing a desktop environment, all the required packages (graphics drivers, network, bluetooth, audio, printers, etc.), along with some preferred applications and utilities I use on a daily basis.

## Download Arch ISO

Download the Arch ISO from <https://archlinux.org/download/> and put it on a USB drive with [Etcher](https://www.balena.io/etcher/), [Rufus](https://rufus.ie/en/), or [Ventoy](https://www.ventoy.net/en/index.html)

## Boot Arch ISO

From the initial prompt, type the following commands after waiting a few seconds (as explained [here](#error-keyring-is-not-writable)):

```bash
pacman -Sy git
git clone https://github.com/anisbsalah/ArchTitus
cd ArchTitus
./archtitus.sh
```

- Single command quicklaunch:

```bash
bash <(curl -L https://github.com/anisbsalah/ArchTitus/raw/main/scripts/curl-install.sh)
```

## Troubleshooting

### **No WiFi**

You can check if WiFi is blocked by running `rfkill list`.
If it says **Soft blocked: yes**, then run `rfkill unblock wifi`

After unblocking the WiFi, you can connect to it. Go through these 5 steps:

1. Run `iwctl`

2. Run `device list`, and find your device name.

3. Run `station [device name] scan`

4. Run `station [device name] get-networks`

5. Find your network, and run `station [device name] connect [network name]`, enter your password and run `exit`. You can test if you have internet connection by running `ping google.com`

### **error: keyring is not writable**

If you get this error when installing git:

```
downloading required keys...
error: keyring is not writable
error: required key missing from keyring
error: failed to commit transaction (unexpected error)
Errors occurred, no packages were upgraded.
```

Reboot the ISO and wait at least 15 seconds before installing git. \
When starting the Arch ISO, it will update the keyring and trust database in the background. \
You can run `journalctl -f` and wait until it says something like **next trustdb check due at 2022-05-6** and **Finished Initializes Pacman keyring**.

### **Script failing constantly**

If the script fails multiple times, try to remove `install.conf` and run the script again.

### **Timezone won't get detected**

Make sure the domains `ipapi.co` and `ifconfig.co` don't get blocked by your firewall.
