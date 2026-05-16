#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════
#  Arch Linux Installation Script
#  Hardware: Ryzen 9800X3D / RX 9070 XT / MSI MS-7E51
#  Target:   User-selected disk (interactive)
#  Dual boot with Windows (auto-detected)
# ══════════════════════════════════════════════════════════════════
#
#  USAGE:
#    1. Boot Arch ISO (2026.04.01+)
#    2. Connect to internet (ethernet or iwctl)
#    3. Run: bash arch-install.sh
#
#  This script is meant to be READ and RUN MANUALLY step by step.
#  Review each section before executing.
# ═══════════════════════════════════════════════════════════════���══
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${RED}[!]${NC} $1"; }

# ── Configuration (defaults; override in arch-install.local.conf) ─
HOSTNAME="archbox"
USERNAME="user"
TIMEZONE="Europe/Madrid"
LOCALE="en_US.UTF-8"
KEYMAP="us"
EXTRA_KEYMAP="es"

# NFS mounts — array of "remote:export  local_mountpoint" pairs.
# Default is empty (no NFS). Override in arch-install.local.conf.
NFS_MOUNTS=()

# NTFS data disk (empty = skip)
NTFS_DATA_DEVICE=""
NTFS_DATA_MOUNT="/media/data"

# Btrfs subvolumes
declare -a SUBVOLS=("@" "@home" "@snapshots" "@var_log" "@var_cache" "@docker")

# Load local overrides if present (NEVER committed; see .gitignore)
LOCAL_CONF="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/arch-install.local.conf"
if [[ -f "$LOCAL_CONF" ]]; then
    # shellcheck source=/dev/null
    source "$LOCAL_CONF"
    info "Loaded local config: $LOCAL_CONF"
fi

# ── Disk selection ──────────────────────────────────────────────
echo ""
info "Detected disks:"
echo ""
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT,MODEL | grep -E "^(NAME|[a-z])" || lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT
echo ""

# Show partitions with OS indicators
info "Partition details (look for Windows/EFI/Linux markers):"
echo ""
for disk in $(lsblk -dnp -o NAME,TYPE | awk '$2=="disk"{print $1}'); do
    echo -e "${BLUE}━━━ ${disk} ($(lsblk -dn -o SIZE "${disk}") — $(lsblk -dn -o MODEL "${disk}"))${NC}"
    lsblk -np -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL "${disk}" | tail -n +2 | while read -r line; do
        part=$(echo "$line" | awk '{print $1}')
        # Highlight Windows and EFI partitions
        if echo "$line" | grep -qi "microsoft\|windows\|EFI system"; then
            echo -e "  ${RED}${line}  ← WINDOWS/EFI${NC}"
        elif echo "$line" | grep -qi "linux\|arch\|btrfs\|ext4"; then
            echo -e "  ${GREEN}${line}  ← LINUX${NC}"
        else
            echo "  ${line}"
        fi
    done
    echo ""
done

warn "════════════════════════════════════════════════════════"
warn "  SELECT THE DISK TO INSTALL ARCH LINUX ON"
warn "  The selected disk will be COMPLETELY ERASED"
warn "════════════════════════════════════════════════════════"
echo ""

# List candidate disks (NVMe + SATA, exclude USB)
mapfile -t DISKS < <(lsblk -dnp -o NAME,TYPE,TRAN | awk '$2=="disk" && ($3=="nvme" || $3=="sata" || $3==""){print $1}')

if [[ ${#DISKS[@]} -eq 0 ]]; then
    warn "No disks found!"
    exit 1
fi

for i in "${!DISKS[@]}"; do
    d="${DISKS[$i]}"
    size=$(lsblk -dn -o SIZE "$d")
    model=$(lsblk -dn -o MODEL "$d")
    echo -e "  ${GREEN}[$i]${NC}  $d  ($size — $model)"
done
echo ""

read -p "Enter disk number [0-$((${#DISKS[@]}-1))]: " disk_choice

if [[ ! "$disk_choice" =~ ^[0-9]+$ ]] || [[ "$disk_choice" -ge "${#DISKS[@]}" ]]; then
    warn "Invalid selection."
    exit 1
fi

DISK="${DISKS[$disk_choice]}"

# NVMe uses 'p' separator (nvme0n1p1), SATA/USB does not (sda1)
if [[ "$DISK" == /dev/nvme* ]] || [[ "$DISK" == /dev/loop* ]]; then
    PART1="${DISK}p1"
    PART2="${DISK}p2"
else
    PART1="${DISK}1"
    PART2="${DISK}2"
fi
echo ""
warn "════════════════════════════════════════════════════════"
warn "  THIS WILL ERASE: ${DISK}"
warn "  $(lsblk -dn -o SIZE,MODEL "${DISK}")"
warn "════════════════════════════════════════════════════════"

# Show what's on the selected disk
PARTS=$(lsblk -np -o NAME,SIZE,FSTYPE,LABEL "${DISK}" | tail -n +2)
if [[ -n "$PARTS" ]]; then
    warn "  Current partitions on ${DISK}:"
    echo "$PARTS" | while read -r line; do
        warn "    $line"
    done
fi

echo ""
read -p "Type 'YES' to ERASE ${DISK} and install Arch: " confirm
if [[ "$confirm" != "YES" ]]; then
    echo "Aborted."
    exit 1
fi

# Verify UEFI mode
if [[ ! -d /sys/firmware/efi/efivars ]]; then
    warn "Not booted in UEFI mode! Reboot in UEFI mode."
    exit 1
fi
success "UEFI mode verified"

# Verify internet
if ! ping -c 1 archlinux.org &>/dev/null; then
    warn "No internet connection!"
    info "For Wi-Fi: iwctl station wlan0 connect <SSID>"
    info "For Ethernet: should be automatic"
    exit 1
fi
success "Internet connection verified"

# ── Step 0: Clean up previous mounts ────────────────────────────
umount -R /mnt 2>/dev/null || true

# ── Step 1: Update system clock ──────────────────────────────────
info "Syncing system clock..."
timedatectl set-ntp true
success "Clock synced"

# ── Step 2: Partition disk ───────────────────────────────────────
info "Partitioning ${DISK}..."

# Wipe existing partitions
wipefs -af "${DISK}"
sgdisk --zap-all "${DISK}"

# Create GPT partitions:
#   Part 1: EFI System Partition — 1536MB (generous for future UKI)
#   Part 2: Root (btrfs) — remaining space
sgdisk -n 1:0:+1536M -t 1:ef00 -c 1:"EFI" "${DISK}"
sgdisk -n 2:0:0       -t 2:8300 -c 2:"Arch" "${DISK}"

# Inform kernel of partition changes
partprobe "${DISK}"
udevadm settle

success "Partitioned: ${PART1} (EFI 1.5G) + ${PART2} (Arch btrfs)"

# ── Step 3: Format partitions ────────────────────────────────────
info "Formatting partitions..."

mkfs.fat -F 32 -n EFI "${PART1}"
mkfs.btrfs -f -L Arch "${PART2}"

success "Partitions formatted"

# ── Step 4: Create btrfs subvolumes ──────────────────────────────
info "Creating btrfs subvolumes..."

mount "${PART2}" /mnt

for subvol in "${SUBVOLS[@]}"; do
    btrfs subvolume create "/mnt/${subvol}"
    success "  Created subvolume: ${subvol}"
done

umount /mnt

# ── Step 5: Mount subvolumes ────────────────────────────────────
info "Mounting subvolumes..."

MOUNT_OPTS="compress=zstd:1,noatime,discard=async"

mount -o "${MOUNT_OPTS},subvol=@"          "${PART2}" /mnt
mkdir -p /mnt/{home,boot,.snapshots,var/log,var/cache,var/lib/docker}

mount -o "${MOUNT_OPTS},subvol=@home"      "${PART2}" /mnt/home
mount -o "${MOUNT_OPTS},subvol=@snapshots" "${PART2}" /mnt/.snapshots
mount -o "${MOUNT_OPTS},subvol=@var_log"   "${PART2}" /mnt/var/log
mount -o "${MOUNT_OPTS},subvol=@var_cache" "${PART2}" /mnt/var/cache
mount -o "${MOUNT_OPTS},subvol=@docker"    "${PART2}" /mnt/var/lib/docker

mount "${PART1}" /mnt/boot

success "All subvolumes mounted"

# ── Step 6: Install base system ──────────────────────────────────
info "Installing base system (pacstrap)... This will take a few minutes."

pacstrap -K /mnt \
    base \
    base-devel \
    linux \
    linux-firmware \
    linux-headers \
    amd-ucode \
    btrfs-progs \
    networkmanager \
    vim \
    git \
    sudo \
    zsh

success "Base system installed"

# ── Step 7: Generate fstab ──────────────────────────────────────
info "Generating fstab..."

genfstab -U /mnt >> /mnt/etc/fstab

# Remove subvolid= for easier btrfs snapshot rollbacks
sed -i 's/,subvolid=[0-9]*//g' /mnt/etc/fstab

# Verify fstab
cat /mnt/etc/fstab
echo ""
info "Review the fstab above. Press Enter to continue or Ctrl+C to abort."
read -r

success "fstab generated"

# ── Step 8: Chroot configuration ────────────────────────────────
info "Entering chroot for system configuration..."

cat > /mnt/chroot-setup.sh << 'CHROOT_EOF'
#!/usr/bin/env bash
set -euo pipefail

info()    { echo -e "\033[0;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[0;32m[OK]\033[0m $1"; }

# ── Timezone ─────────────────────────────────────────────────
info "Setting timezone..."
ln -sf /usr/share/zoneinfo/TIMEZONE_PLACEHOLDER /etc/localtime
hwclock --systohc
success "Timezone set"

# ── Locale ───────────────────────────────────────────────────
info "Configuring locale..."
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^#es_ES.UTF-8 UTF-8/es_ES.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=LOCALE_PLACEHOLDER" > /etc/locale.conf
echo "KEYMAP=KEYMAP_PLACEHOLDER" > /etc/vconsole.conf
success "Locale configured"

# ── Hostname ─────────────────────────────────────────────────
info "Setting hostname..."
echo "HOSTNAME_PLACEHOLDER" > /etc/hostname
cat > /etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   HOSTNAME_PLACEHOLDER.localdomain HOSTNAME_PLACEHOLDER
EOF
success "Hostname set"

# ── mkinitcpio ───────────────────────────────────────────────
info "Configuring mkinitcpio for btrfs..."
sed -i 's/^MODULES=.*/MODULES=(amdgpu)/' /etc/mkinitcpio.conf
sed -i 's/^HOOKS=.*/HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems)/' /etc/mkinitcpio.conf
mkinitcpio -P
success "mkinitcpio configured and rebuilt"

# ── Bootloader (rEFInd) ─────────────────────────────────────
info "Installing rEFInd..."
pacman -S --needed --noconfirm refind
refind-install

# Get root partition UUID
ROOT_UUID=$(blkid -s UUID -o value PART2_PLACEHOLDER)

# Detect Windows EFI partition (small FAT32 on a different disk)
WIN_EFI_UUID=""
for part in $(blkid -t TYPE=vfat -o device); do
    if [[ "$part" != "PART1_PLACEHOLDER" ]] && [ -n "$(blkid -o value -s UUID "$part")" ]; then
        # Check if it has Microsoft boot files by mounting temporarily
        TMP_MNT=$(mktemp -d)
        mount -o ro "$part" "$TMP_MNT" 2>/dev/null
        if [[ -f "$TMP_MNT/EFI/Microsoft/Boot/bootmgfw.efi" ]]; then
            WIN_EFI_UUID=$(blkid -s UUID -o value "$part")
            info "Found Windows EFI at $part (UUID: $WIN_EFI_UUID)"
        fi
        umount "$TMP_MNT" 2>/dev/null
        rmdir "$TMP_MNT"
    fi
done

# rEFInd configuration
cat > /boot/EFI/refind/refind.conf << EOF
timeout 10
use_nvram false
scanfor manual
default_selection "Arch Linux"
resolution max

# Theme (installed below)
include themes/catppuccin/mocha.conf

menuentry "Arch Linux" {
    icon     /EFI/refind/themes/catppuccin/assets/mocha/icons/os_arch.png
    volume   "EFI"
    loader   /vmlinuz-linux
    initrd   /initramfs-linux.img
    options  "root=UUID=${ROOT_UUID} rootflags=subvol=@ rw amd_pstate=active split_lock_detect=off"
}

menuentry "Arch Linux (fallback)" {
    icon     /EFI/refind/themes/catppuccin/assets/mocha/icons/os_arch.png
    volume   "EFI"
    loader   /vmlinuz-linux
    initrd   /initramfs-linux-fallback.img
    options  "root=UUID=${ROOT_UUID} rootflags=subvol=@ rw amd_pstate=active"
}

EOF

# Add Windows entry if detected
if [[ -n "$WIN_EFI_UUID" ]]; then
    cat >> /boot/EFI/refind/refind.conf << EOF

menuentry "Windows" {
    icon     /EFI/refind/themes/catppuccin/assets/mocha/icons/os_win.png
    volume   ${WIN_EFI_UUID}
    loader   /EFI/Microsoft/Boot/bootmgfw.efi
}
EOF
    success "Windows boot entry added"
fi

# Install Catppuccin theme
if [[ ! -d /boot/EFI/refind/themes/catppuccin ]]; then
    mkdir -p /boot/EFI/refind/themes
    git clone --depth 1 https://github.com/catppuccin/refind.git /boot/EFI/refind/themes/catppuccin
fi

success "rEFInd installed with Catppuccin Mocha theme"

# ── Users ────────────────────────────────────────────────────
info "Creating user..."
echo "Set ROOT password:"
passwd

groupadd -f docker
useradd -m -G wheel,docker -s /usr/bin/zsh USERNAME_PLACEHOLDER
echo "Set password for USERNAME_PLACEHOLDER:"
passwd USERNAME_PLACEHOLDER

# Enable sudo for wheel group
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
success "User created with sudo access"

# ── Network ──────────────────────────────────────────────────
info "Enabling NetworkManager..."
systemctl enable NetworkManager
systemctl enable systemd-timesyncd
success "Network services enabled"

# ── Pacman config ────────────────────────────────────────────
info "Configuring pacman..."
# Enable Color and ParallelDownloads
sed -i 's/^#Color/Color/' /etc/pacman.conf
sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf

# Enable multilib for 32-bit AMD drivers (uncomment existing section)
sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf

pacman -Sy --noconfirm
success "Pacman configured"

# ── NFS mounts ───────────────────────────────────────────────
if [[ ${#NFS_MOUNTS[@]} -gt 0 ]]; then
    info "Configuring ${#NFS_MOUNTS[@]} NFS mount(s)..."
    pacman -S --needed --noconfirm nfs-utils

    for entry in "${NFS_MOUNTS[@]}"; do
        # Each entry: "remote:export  local_mountpoint"
        remote=$(echo "$entry" | awk '{print $1}')
        local_mp=$(echo "$entry" | awk '{print $2}')
        mkdir -p "$local_mp"
        echo "${remote} ${local_mp} nfs _netdev,noauto,x-systemd.automount,x-systemd.mount-timeout=10,noatime,nofail 0 0" >> /etc/fstab
    done
    success "NFS mounts configured (see arch-install.local.conf for sources)"
else
    info "No NFS_MOUNTS defined — skipping NFS configuration"
fi

# ── NTFS data disk (kernel ntfs3 driver) ────────────────────
if [[ -n "$NTFS_DATA_DEVICE" && -b "$NTFS_DATA_DEVICE" ]]; then
    info "Configuring NTFS data disk at $NTFS_DATA_MOUNT..."
    mkdir -p "$NTFS_DATA_MOUNT"
    NTFS_UUID=$(blkid -s UUID -o value "$NTFS_DATA_DEVICE")
    echo "UUID=${NTFS_UUID} ${NTFS_DATA_MOUNT} ntfs3 uid=1000,gid=1000,rw,dmask=022,fmask=133,nofail 0 0" >> /etc/fstab
    success "NTFS disk configured"
else
    info "NTFS_DATA_DEVICE not set or not a block device — skipping NTFS fstab entry"
fi

# TRIM: discard=async in mount options handles ongoing trim;
# fstrim.timer (weekly) is enabled later by install.sh as belt-and-braces.

# ── Windows dual boot ───────────────────────────────────────
# rEFInd auto-detects Windows Boot Manager on any EFI partition
# No manual configuration needed — scanfor external handles it
success "Windows dual boot: rEFInd will auto-detect from any disk"

# ── Done inside chroot ───────────────────────────────────────
echo ""
success "════════════════════════════════════════════════════════"
success "  Chroot configuration complete!"
success "════════════════════════════════════════════════════════"

CHROOT_EOF

# Replace placeholders in chroot script
sed -i "s|TIMEZONE_PLACEHOLDER|${TIMEZONE}|g" /mnt/chroot-setup.sh
sed -i "s|LOCALE_PLACEHOLDER|${LOCALE}|g" /mnt/chroot-setup.sh
sed -i "s|KEYMAP_PLACEHOLDER|${KEYMAP}|g" /mnt/chroot-setup.sh
sed -i "s|HOSTNAME_PLACEHOLDER|${HOSTNAME}|g" /mnt/chroot-setup.sh
sed -i "s|USERNAME_PLACEHOLDER|${USERNAME}|g" /mnt/chroot-setup.sh
sed -i "s|DISK_PLACEHOLDER|${DISK}|g" /mnt/chroot-setup.sh
sed -i "s|PART2_PLACEHOLDER|${PART2}|g" /mnt/chroot-setup.sh

chmod +x /mnt/chroot-setup.sh

# Run chroot setup (-S uses systemd-run so bootctl can write UEFI entries)
arch-chroot -S /mnt /chroot-setup.sh

# Cleanup
rm /mnt/chroot-setup.sh

# ── Step 9: Summary and reboot ──────────────────────────────
echo ""
success "════════════════════════════════════════════════════════"
success "  Installation complete!"
success "════════════════════════════════════════════════════════"
echo ""

# ── Installation summary ────────────────────────────────────
echo -e "${BLUE}┌──────────────────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│              INSTALLATION SUMMARY                     │${NC}"
echo -e "${BLUE}├──────────────────────────────────────────────────────┤${NC}"
echo -e "${BLUE}│${NC}  Hostname:     ${GREEN}${HOSTNAME}${NC}"
echo -e "${BLUE}│${NC}  User:         ${GREEN}${USERNAME}${NC}"
echo -e "${BLUE}│${NC}  Shell:        ${GREEN}/usr/bin/zsh${NC}"
echo -e "${BLUE}│${NC}  Timezone:     ${GREEN}${TIMEZONE}${NC}"
echo -e "${BLUE}│${NC}  Locale:       ${GREEN}${LOCALE}${NC}"
echo -e "${BLUE}│${NC}  Keymap:       ${GREEN}${KEYMAP}${NC}"
echo -e "${BLUE}├──────────────────────────────────────────────────────┤${NC}"
echo -e "${BLUE}│${NC}  ${GREEN}Disk layout (${DISK})${NC}"
echo -e "${BLUE}│${NC}    ${PART1}   ESP /boot   1.5GB  FAT32"
echo -e "${BLUE}│${NC}    ${PART2}   /           rest   btrfs"
echo -e "${BLUE}├──────────────────────────────────────────────────────┤${NC}"
echo -e "${BLUE}│${NC}  ${GREEN}Btrfs subvolumes${NC}"
for subvol in "${SUBVOLS[@]}"; do
    echo -e "${BLUE}│${NC}    ${subvol}"
done
echo -e "${BLUE}├──────────────────────────────────────────────────────┤${NC}"
echo -e "${BLUE}│${NC}  ${GREEN}Bootloader${NC}"
echo -e "${BLUE}│${NC}    rEFInd (ESP at /boot, Catppuccin Mocha)"
echo -e "${BLUE}│${NC}    Entries: Arch Linux, Arch Linux (fallback)"
echo -e "${BLUE}│${NC}    Windows: ${GREEN}auto-detected by rEFInd${NC}"
echo -e "${BLUE}├──────────────────────────────────────────────────────┤${NC}"
echo -e "${BLUE}│${NC}  ${GREEN}Services enabled${NC}"
echo -e "${BLUE}│${NC}    NetworkManager, systemd-timesyncd"
echo -e "${BLUE}│${NC}    TRIM: discard=async (mount option)"
if [[ ${#NFS_MOUNTS[@]} -gt 0 ]]; then
    echo -e "${BLUE}├──────────────────────────────────────────────────────┤${NC}"
    echo -e "${BLUE}│${NC}  ${GREEN}NFS mounts (${#NFS_MOUNTS[@]})${NC}"
    for entry in "${NFS_MOUNTS[@]}"; do
        echo -e "${BLUE}│${NC}    $(echo "$entry" | awk '{print $2}')"
    done
fi
if [[ -n "$NTFS_DATA_DEVICE" ]]; then
    echo -e "${BLUE}├──────────────────────────────────────────────────────┤${NC}"
    echo -e "${BLUE}│${NC}  ${GREEN}NTFS data disk (kernel ntfs3)${NC}"
    echo -e "${BLUE}│${NC}    ${NTFS_DATA_DEVICE} -> ${NTFS_DATA_MOUNT}"
fi
echo -e "${BLUE}└──────────────────────────────────────────────────────┘${NC}"
echo ""

# ── Next steps ──────────────────────────────────────────────
info "Next steps after reboot:"
info "  1. Log in as ${USERNAME}"
info "  2. Connect to WiFi: nmcli device wifi connect <SSID> password <PASS>"
info "  3. Clone dotfiles:"
info "       git clone https://github.com/pedroapy/dotfiles.git ~/dotfiles-arch"
info "       cd ~/dotfiles-arch && git checkout archlinux"
info "       ./install.sh"
echo ""
info "  BIOS: Set boot order to '${DISK}' first (Arch), Windows second"
echo ""
read -p "Unmount and reboot now? [y/N]: " reboot_confirm
if [[ "$reboot_confirm" == "y" || "$reboot_confirm" == "Y" ]]; then
    umount -R /mnt
    reboot
fi
