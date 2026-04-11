#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════
#  Arch Linux Installation Script
#  Hardware: Ryzen 9800X3D / RX 9070 XT / MSI MS-7E51
#  Target:   nvme1n1 (477GB) — replacing Kubuntu
#  Dual boot with Windows on nvme0n1
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

# ── Configuration ────────────────────────────────────────────────
DISK="/dev/nvme1n1"
HOSTNAME="archbox"
USERNAME="pedroapy"
TIMEZONE="Europe/Madrid"
LOCALE="en_US.UTF-8"
KEYMAP="us"
EXTRA_KEYMAP="es"

# Btrfs subvolumes
declare -a SUBVOLS=("@" "@home" "@snapshots" "@var_log" "@var_cache" "@docker")

# ── Pre-flight checks ───────────────────────────────────────────
echo ""
warn "════════════════════════════════════════════════════════"
warn "  This will ERASE ${DISK} (Kubuntu)"
warn "  Windows on nvme0n1 will NOT be touched"
warn "  Micron T705 on nvme2n1 will NOT be touched"
warn "  HDD sda will NOT be touched"
warn "════════════════════════════════════════════════════════"
echo ""
read -p "Type 'YES' to continue: " confirm
[[ "$confirm" != "YES" ]] && echo "Aborted." && exit 1

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
#   Part 1: EFI System Partition — 1024MB (generous for future UKI)
#   Part 2: Root (btrfs) — remaining space
sgdisk -n 1:0:+1024M -t 1:ef00 -c 1:"EFI" "${DISK}"
sgdisk -n 2:0:0       -t 2:8300 -c 2:"Arch" "${DISK}"

# Inform kernel of partition changes
partprobe "${DISK}"
sleep 1

success "Partitioned: ${DISK}p1 (EFI 1G) + ${DISK}p2 (Arch btrfs)"

# ── Step 3: Format partitions ────────────────────────────────────
info "Formatting partitions..."

mkfs.fat -F 32 -n EFI "${DISK}p1"
mkfs.btrfs -f -L Arch "${DISK}p2"

success "Partitions formatted"

# ── Step 4: Create btrfs subvolumes ──────────────────────────────
info "Creating btrfs subvolumes..."

mount "${DISK}p2" /mnt

for subvol in "${SUBVOLS[@]}"; do
    btrfs subvolume create "/mnt/${subvol}"
    success "  Created subvolume: ${subvol}"
done

umount /mnt

# ── Step 5: Mount subvolumes ────────────────────────────────────
info "Mounting subvolumes..."

MOUNT_OPTS="compress=zstd:1,noatime,ssd,space_cache=v2"

mount -o "${MOUNT_OPTS},subvol=@"          "${DISK}p2" /mnt
mkdir -p /mnt/{home,efi,.snapshots,var/log,var/cache,var/lib/docker}

mount -o "${MOUNT_OPTS},subvol=@home"      "${DISK}p2" /mnt/home
mount -o "${MOUNT_OPTS},subvol=@snapshots" "${DISK}p2" /mnt/.snapshots
mount -o "${MOUNT_OPTS},subvol=@var_log"   "${DISK}p2" /mnt/var/log
mount -o "${MOUNT_OPTS},subvol=@var_cache" "${DISK}p2" /mnt/var/cache
mount -o "${MOUNT_OPTS},subvol=@docker"    "${DISK}p2" /mnt/var/lib/docker

mount "${DISK}p1" /mnt/efi

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
sed -i 's/^MODULES=.*/MODULES=(amdgpu btrfs)/' /etc/mkinitcpio.conf
sed -i 's/^HOOKS=.*/HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems)/' /etc/mkinitcpio.conf
mkinitcpio -P
success "mkinitcpio configured and rebuilt"

# ── Bootloader (systemd-boot) ───────────────────────────────
info "Installing systemd-boot..."
bootctl install --esp-path=/efi

# Loader config
cat > /efi/loader/loader.conf << EOF
default arch.conf
timeout 3
console-mode auto
editor  no
EOF

# Get root partition UUID
ROOT_UUID=$(blkid -s UUID -o value DISK_PLACEHOLDERp2)

# Boot entry
cat > /efi/loader/entries/arch.conf << EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /amd-ucode.img
initrd  /initramfs-linux.img
options root=UUID=${ROOT_UUID} rootflags=subvol=@ rw amd_pstate=active split_lock_detect=off
EOF

# Fallback entry
cat > /efi/loader/entries/arch-fallback.conf << EOF
title   Arch Linux (fallback)
linux   /vmlinuz-linux
initrd  /amd-ucode.img
initrd  /initramfs-linux-fallback.img
options root=UUID=${ROOT_UUID} rootflags=subvol=@ rw amd_pstate=active
EOF

success "systemd-boot installed"

# ── Users ────────────────────────────────────────────────────
info "Creating user..."
echo "Set ROOT password:"
passwd

groupadd -f docker
useradd -m -G wheel,docker,video,audio -s /usr/bin/zsh USERNAME_PLACEHOLDER
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

# Enable multilib for 32-bit AMD drivers
cat >> /etc/pacman.conf << EOF

[multilib]
Include = /etc/pacman.d/mirrorlist
EOF

pacman -Syu --noconfirm
success "Pacman configured"

# ── NFS mounts ───────────────────────────────────────────────
info "Configuring NFS mounts..."
pacman -S --needed --noconfirm nfs-utils

mkdir -p /mnt/nas/{fotos,docs,shared,roms}

cat >> /etc/fstab << EOF

# NAS mounts
REDACTED_IP:/mnt/nas/share  /mnt/nas/fotos  nfs defaults,noatime,nofail 0 0
REDACTED_IP:/mnt/nas/share   /mnt/nas/docs   nfs defaults,noatime,nofail 0 0
REDACTED_IP:/mnt/nas/share   /mnt/nas/shared  nfs defaults,noatime,nofail 0 0
REDACTED_IP:/mnt/nas/share     /mnt/nas/roms    nfs defaults,noatime,nofail 0 0
EOF

success "NFS mounts configured"

# ── NTFS data disks ─────────────────────────────────────────
info "Configuring NTFS data disks..."
pacman -S --needed --noconfirm ntfs-3g

mkdir -p /media/gdisk

# Micron T705 1.8TB
T705_UUID=$(blkid -s UUID -o value /dev/nvme2n1p1)
cat >> /etc/fstab << EOF

# Micron T705 data disk
UUID=${T705_UUID} /media/gdisk ntfs-3g uid=1000,gid=1000,rw,umask=022,nofail 0 0
EOF

success "NTFS disks configured"

# ── TRIM timer for NVMe ─────────────────────────────────────
systemctl enable fstrim.timer
success "TRIM timer enabled"

# ── Windows dual boot ───────────────────────────────────────
info "Configuring Windows dual boot..."
# systemd-boot auto-detects Windows Boot Manager on the other EFI
# Just need os-prober or manual entry if not auto-detected

# Mount Windows EFI to check
mkdir -p /mnt/win_efi
mount /dev/nvme0n1p1 /mnt/win_efi 2>/dev/null || true

if [[ -f /mnt/win_efi/EFI/Microsoft/Boot/bootmgfw.efi ]]; then
    cat > /efi/loader/entries/windows.conf << EOF
title   Windows
efi     /EFI/Microsoft/Boot/bootmgfw.efi
EOF
    # Copy Windows EFI files to our ESP so systemd-boot can chain-load
    mkdir -p /efi/EFI/Microsoft/Boot
    cp /mnt/win_efi/EFI/Microsoft/Boot/bootmgfw.efi /efi/EFI/Microsoft/Boot/
    success "Windows boot entry added"
else
    info "Windows EFI not found on nvme0n1p1 — you may need to add it manually"
    info "Or set BIOS boot order to select Windows EFI directly"
fi

umount /mnt/win_efi 2>/dev/null || true
rmdir /mnt/win_efi 2>/dev/null || true

success "Dual boot configured"

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

chmod +x /mnt/chroot-setup.sh

# Run chroot setup
arch-chroot /mnt /chroot-setup.sh

# Cleanup
rm /mnt/chroot-setup.sh

# ── Step 9: Unmount and reboot ───────────────────────────────
echo ""
success "════════════════════════════════════════════════════════"
success "  Installation complete!"
success "════════════════════════════════════════════════════════"
echo ""
info "Next steps:"
info "  1. umount -R /mnt"
info "  2. reboot"
info "  3. Log in as ${USERNAME}"
info "  4. Connect to WiFi: nmcli device wifi connect <SSID> password <PASS>"
info "  5. Clone dotfiles:"
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
