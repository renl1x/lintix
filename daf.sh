#!/bin/bash
set -euo pipefail

STATE_DIR="/tmp/debian_install_state"
mkdir -p "$STATE_DIR"

if command -v tput >/dev/null 2>&1; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    MAGENTA=$(tput setaf 5)
    CYAN=$(tput setaf 6)
    BOLD=$(tput bold)
    NC=$(tput sgr0)
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; MAGENTA=''; CYAN=''; BOLD=''; NC=''
fi

confirm() {
    local prompt="$1"
    local resposta
    read -p "$prompt (s/n): " -n 1 resposta
    echo
    if [[ -z "$resposta" ]]; then
        return 0
    else
        [[ "$resposta" =~ ^[Ss]$ ]]
    fi
}

clear_screen() { clear; }

show_section() {
    echo "${CYAN}────────────────────────────────────────────────────────────────────${NC}"
    echo "${GREEN}► $1${NC}"
    echo "${CYAN}────────────────────────────────────────────────────────────────────${NC}"
    echo ""
}

show_option() {
    local num="$1"
    local desc="$2"
    echo "  ${CYAN}$num${NC}) $desc"
}

# ============================================================================
# DETECÇÃO
# ============================================================================

detect_distro() {
    if [ -f /etc/debian_version ]; then
        echo "debian" > "$STATE_DIR/distro"
    elif [ -f /etc/arch-release ]; then
        echo "arch" > "$STATE_DIR/distro"
    else
        echo "unknown" > "$STATE_DIR/distro"
    fi
}

detect_gpu() {
    local gpu_info=$(lspci -nn 2>/dev/null | grep -E "VGA|3D|Display" | head -1)
    if echo "$gpu_info" | grep -qi "nvidia"; then
        echo "nvidia" > "$STATE_DIR/gpu_driver"
    elif echo "$gpu_info" | grep -qi "amd\|radeon"; then
        echo "amd" > "$STATE_DIR/gpu_driver"
    elif echo "$gpu_info" | grep -qi "intel"; then
        echo "intel" > "$STATE_DIR/gpu_driver"
    else
        echo "nvidia" > "$STATE_DIR/gpu_driver"
    fi
}

detect_cpu() {
    local cpu_info=$(cat /proc/cpuinfo 2>/dev/null)
    if echo "$cpu_info" | grep -qi "intel"; then
        echo "intel" > "$STATE_DIR/cpu"
    elif echo "$cpu_info" | grep -qi "amd"; then
        echo "amd" > "$STATE_DIR/cpu"
    else
        echo "intel" > "$STATE_DIR/cpu"
    fi
}

detect_motherboard_brand() {
    local brand="gigabyte"
    
    if [ -f /sys/class/dmi/id/board_vendor ]; then
        brand=$(cat /sys/class/dmi/id/board_vendor 2>/dev/null)
    fi
    
    if [ -z "$brand" ] || [ "$brand" == "Unknown" ] || [ "$brand" == "To be filled by O.E.M." ]; then
        if [ -f /sys/class/dmi/id/sys_vendor ]; then
            brand=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)
        fi
    fi
    
    case "$brand" in
        *"ASUS"*|*"Asus"*) echo "asus" > "$STATE_DIR/motherboard_brand" ;;
        *"Gigabyte"*|*"GIGABYTE"*) echo "gigabyte" > "$STATE_DIR/motherboard_brand" ;;
        *"MSI"*|*"Micro-Star"*) echo "msi" > "$STATE_DIR/motherboard_brand" ;;
        *"Acer"*) echo "acer" > "$STATE_DIR/motherboard_brand" ;;
        *"Dell"*) echo "dell" > "$STATE_DIR/motherboard_brand" ;;
        *"HP"*|*"Hewlett-Packard"*) echo "hp" > "$STATE_DIR/motherboard_brand" ;;
        *"Lenovo"*) echo "lenovo" > "$STATE_DIR/motherboard_brand" ;;
        *) echo "gigabyte" > "$STATE_DIR/motherboard_brand" ;;
    esac
}

detect_bootloader() {
    local bootloader=""
    local esp_path=""
    
    if mount | grep -q "/boot/efi "; then
        esp_path="/boot/efi"
    elif mount | grep -q "/boot "; then
        esp_path="/boot"
    elif [ -d /boot/EFI ]; then
        esp_path="/boot"
    elif [ -d /boot/efi/EFI ]; then
        esp_path="/boot/efi"
    fi
    
    if [ -n "$esp_path" ]; then
        if [ -f "${esp_path}/EFI/systemd/systemd-bootx64.efi" ] || [ -f "${esp_path}/loader/loader.conf" ] || [ -f "/boot/loader/loader.conf" ]; then
            bootloader="systemd-boot"
        fi
    fi
    
    if [ -z "$bootloader" ] && command -v bootctl &>/dev/null; then
        if sudo bootctl status 2>/dev/null | grep -q "systemd-boot"; then
            bootloader="systemd-boot"
            if [ -f "/boot/loader/loader.conf" ]; then
                esp_path="/boot"
            elif [ -f "/boot/efi/loader/loader.conf" ]; then
                esp_path="/boot/efi"
            fi
        fi
    fi
    
    if [ -z "$bootloader" ]; then
        if [ -f /boot/grub/grub.cfg ] || [ -f /boot/EFI/GRUB/grubx64.efi ] || [ -f /etc/default/grub ]; then
            bootloader="grub"
        else
            bootloader="none"
        fi
    fi
    
    echo "$bootloader" > "$STATE_DIR/bootloader"
    [ -n "$esp_path" ] && echo "$esp_path" > "$STATE_DIR/esp_path"
}

detect_secureboot_support() {
    local distro=$(cat "$STATE_DIR/distro")
    
    if [ "$distro" == "arch" ]; then
        if ! command -v mokutil &>/dev/null; then
            sudo pacman -S --noconfirm mokutil
        fi
    fi
    
    if [ -d /sys/firmware/efi ]; then
        echo "supported" > "$STATE_DIR/secureboot_support"
        if command -v mokutil &>/dev/null; then
            if sudo mokutil --sb-state 2>/dev/null | grep -qi "SecureBoot enabled"; then
                echo "enabled" > "$STATE_DIR/secureboot_state"
            else
                echo "disabled" > "$STATE_DIR/secureboot_state"
            fi
        else
            echo "unknown" > "$STATE_DIR/secureboot_state"
        fi
    else
        echo "unsupported" > "$STATE_DIR/secureboot_support"
    fi
}

# ============================================================================
# SELEÇÃO
# ============================================================================

select_desktop() {
    clear_screen
    show_section "AMBIENTE DESKTOP"
    
    local distro=$(cat "$STATE_DIR/distro")
    
    if [[ "$distro" == "debian" ]]; then
        show_option "1" "GNOME"
        show_option "2" "KDE Plasma"
        show_option "3" "Nenhum"
        show_option "4" "Dank Linux"
        echo ""
        read -p "Opção [1-4] (Enter para GNOME): " de_opt
        
        case "$de_opt" in
            1|"") echo "gnome" > "$STATE_DIR/desktop"
                 echo "${GREEN}Desktop: GNOME${NC}" ;;
            2) echo "kde" > "$STATE_DIR/desktop"
               echo "${GREEN}Desktop: KDE Plasma${NC}" ;;
            3) echo "none" > "$STATE_DIR/desktop"
               echo "${GREEN}Desktop: Nenhum${NC}" ;;
            4) echo "dank" > "$STATE_DIR/desktop"
               echo "${GREEN}Desktop: Dank Linux${NC}" ;;
            *) echo "${RED}Opção inválida.${NC}"
               sleep 1
               select_desktop
               return
        esac
    elif [[ "$distro" == "arch" ]]; then
        show_option "1" "GNOME"
        show_option "2" "KDE Plasma"
        show_option "3" "Nenhum"
        show_option "4" "COSMIC"
        show_option "5" "Dank Linux"
        echo ""
        read -p "Opção [1-5] (Enter para GNOME): " de_opt
        
        case "$de_opt" in
            1|"") echo "gnome" > "$STATE_DIR/desktop"
                 echo "${GREEN}Desktop: GNOME${NC}" ;;
            2) echo "kde" > "$STATE_DIR/desktop"
               echo "${GREEN}Desktop: KDE Plasma${NC}" ;;
            3) echo "none" > "$STATE_DIR/desktop"
               echo "${GREEN}Desktop: Nenhum${NC}" ;;
            4) echo "cosmic" > "$STATE_DIR/desktop"
               echo "${GREEN}Desktop: COSMIC${NC}" ;;
            5) echo "dank" > "$STATE_DIR/desktop"
               echo "${GREEN}Desktop: Dank Linux${NC}" ;;
            *) echo "${RED}Opção inválida.${NC}"
               sleep 1
               select_desktop
               return
        esac
    fi
    sleep 2
}

select_produtividade() {
    clear_screen
    show_section "PRODUTIVIDADE"
    echo "  Selecione os aplicativos (escolha múltiplos):"
    echo ""
    show_option "1" "OnlyOffice"
    show_option "2" "Obsidian"
    show_option "3" "Zen Browser"
    show_option "4" "Helium Browser"
    show_option "5" "Discord"
    echo ""
    echo "  Digite os números separados por espaço (ex: 1 3 5) ou Enter para nenhum:"
    read -p "Opções: " -a prod_opts
    
    if [[ ${#prod_opts[@]} -eq 0 ]]; then
        echo "none" > "$STATE_DIR/produtividade"
    else
        local prod_list=""
        for opt in "${prod_opts[@]}"; do
            case "$opt" in
                1) prod_list="${prod_list} onlyoffice" ;;
                2) prod_list="${prod_list} obsidian" ;;
                3) prod_list="${prod_list} zen" ;;
                4) prod_list="${prod_list} helium" ;;
                5) prod_list="${prod_list} discord" ;;
                *) echo "${RED}Opção inválida: $opt${NC}" ;;
            esac
        done
        echo "$prod_list" > "$STATE_DIR/produtividade"
    fi
    sleep 1
}

select_multimidia() {
    clear_screen
    show_section "MULTIMÍDIA"
    echo "  Selecione os aplicativos (escolha múltiplos):"
    echo ""
    show_option "1" "GIMP"
    show_option "2" "Kdenlive"
    show_option "3" "OBS Studio"
    show_option "4" "HandBrake"
    show_option "5" "Audacity"
    echo ""
    echo "  Digite os números separados por espaço (ex: 1 3 5) ou Enter para nenhum:"
    read -p "Opções: " -a multi_opts
    
    if [[ ${#multi_opts[@]} -eq 0 ]]; then
        echo "none" > "$STATE_DIR/multimidia"
    else
        local multi_list=""
        for opt in "${multi_opts[@]}"; do
            case "$opt" in
                1) multi_list="${multi_list} gimp" ;;
                2) multi_list="${multi_list} kdenlive" ;;
                3) multi_list="${multi_list} obs" ;;
                4) multi_list="${multi_list} handbrake" ;;
                5) multi_list="${multi_list} audacity" ;;
                *) echo "${RED}Opção inválida: $opt${NC}" ;;
            esac
        done
        echo "$multi_list" > "$STATE_DIR/multimidia"
    fi
    sleep 1
}

select_games() {
    clear_screen
    show_section "JOGOS"
    echo "  Selecione os jogos/plataformas (escolha múltiplos):"
    echo ""
    show_option "1" "Steam"
    show_option "2" "Proton Plus"
    show_option "3" "Prism Launcher"
    show_option "4" "Sober"
    show_option "5" "Heroic Games Launcher"
    echo ""
    echo "  Digite os números separados por espaço (ex: 1 3 5) ou Enter para nenhum:"
    read -p "Opções: " -a games_opts
    
    if [[ ${#games_opts[@]} -eq 0 ]]; then
        echo "none" > "$STATE_DIR/games"
    else
        local games_list=""
        for opt in "${games_opts[@]}"; do
            case "$opt" in
                1) games_list="${games_list} steam" ;;
                2) games_list="${games_list} proton" ;;
                3) games_list="${games_list} prism" ;;
                4) games_list="${games_list} sober" ;;
                5) games_list="${games_list} heroic" ;;
                *) echo "${RED}Opção inválida: $opt${NC}" ;;
            esac
        done
        echo "$games_list" > "$STATE_DIR/games"
    fi
    sleep 1
}

select_extras() {
    clear_screen
    show_section "EXTRAS"
    echo "  Selecione os aplicativos (escolha múltiplos):"
    echo ""
    show_option "1" "DistroShelf"
    show_option "2" "VSCodium"
    show_option "3" "Gamescope"
    show_option "4" "Alpaca"
    show_option "5" "Gear Lever"
    echo ""
    echo "  Digite os números separados por espaço (ex: 1 3) ou Enter para nenhum:"
    read -p "Opções: " -a extras_opts
    
    if [[ ${#extras_opts[@]} -eq 0 ]]; then
        echo "none" > "$STATE_DIR/extras"
    else
        local extras_list=""
        for opt in "${extras_opts[@]}"; do
            case "$opt" in
                1) extras_list="${extras_list} distroshelf" ;;
                2) extras_list="${extras_list} codium" ;;
                3) extras_list="${extras_list} gamescope" ;;
                4) extras_list="${extras_list} alpaca" ;;
                5) extras_list="${extras_list} gearlever" ;;
                *) echo "${RED}Opção inválida: $opt${NC}" ;;
            esac
        done
        echo "$extras_list" > "$STATE_DIR/extras"
    fi
    sleep 1
}

# ============================================================================
# SETUP
# ============================================================================

setup_sources() {
    local distro=$(cat "$STATE_DIR/distro")
    
    case "$distro" in
        debian)
            if [ -f /etc/apt/sources.list ]; then
                sudo sed -i 's/\(main\)/\1 contrib non-free/g' /etc/apt/sources.list
            fi
            
            if [ -f /etc/apt/sources.list.d/debian.sources ]; then
                sudo sed -i '/^Components:/ s/\(main\)/\1 contrib non-free/' /etc/apt/sources.list.d/debian.sources
            fi
            
            sudo apt update
            sudo apt upgrade -y
            ;;
            
        arch)
            sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
            sudo pacman-key --lsign-key 3056513887B78AEB
            sudo pacman -U --noconfirm \
                "https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst" \
                "https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst"
            
            sudo sed -i 's/^#Color/Color/' /etc/pacman.conf
            sudo sed -i '/Color/a ILoveCandy' /etc/pacman.conf
            sudo sed -i '/^ParallelDownloads/d' /etc/pacman.conf
            sudo sed -i '/ILoveCandy/a ParallelDownloads = 15' /etc/pacman.conf
            echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf
            
            sudo pacman -Syu --noconfirm
            ;;
    esac
}

setup_security() {
    local distro=$(cat "$STATE_DIR/distro")
    
    case "$distro" in
        debian)
            sudo apt install -y ufw fwupd
            sudo systemctl enable ufw
            ;;
            
        arch)
            sudo pacman -S --noconfirm apparmor fwupd
            sudo systemctl enable apparmor
            sudo systemctl enable fwupd
            ;;
    esac
}

setup_package_managers() {
    local desktop=$(cat "$STATE_DIR/desktop")
    local distro=$(cat "$STATE_DIR/distro")
    
    case "$distro" in
        debian)
            sudo apt install -y flatpak
            
            if [[ "$desktop" == "gnome" ]]; then
                sudo apt install -y gnome-software-plugin-flatpak
            elif [[ "$desktop" == "kde" ]]; then
                sudo apt install -y plasma-discover-backend-flatpak
            fi
            
            flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
            ;;
        arch)
            sudo pacman -S --noconfirm flatpak
            flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
            ;;
    esac
}

setup_network() {
    local distro=$(cat "$STATE_DIR/distro")
    
    if [[ "$distro" == "debian" ]]; then
        sudo sed -i '/^allow-hotplug /s/^/#/' /etc/network/interfaces
        sudo sed -i '/^iface .* inet /s/^/#/' /etc/network/interfaces
        sudo sed -i '/^iface .* inet6 /s/^/#/' /etc/network/interfaces
    fi
}

setup_zram() {
    local distro=$(cat "$STATE_DIR/distro")
    
    if [[ "$distro" == "debian" ]]; then
        sudo apt install -y systemd-zram-generator
    fi
    
    sudo tee /etc/systemd/zram-generator.conf > /dev/null <<EOF
[zram0]
zram-size = ram * 0.25
compression-algorithm = zstd
swap-priority = 100
EOF
}

setup_btrfs_compression() {
    local distro=$(cat "$STATE_DIR/distro")
    
    if [[ "$distro" == "debian" ]]; then
        if mount | grep -q "btrfs"; then
            sudo sed -i '/btrfs.*compress,/s/compress,/compress=zstd,/g' /etc/fstab
            sudo sed -i '/btrfs.*compress[^=]/s/compress/compress=zstd/g' /etc/fstab
            sudo sed -i '/btrfs.*compress=zlib/s/compress=zlib/compress=zstd/g' /etc/fstab
            sudo mount -o remount /
        fi
    fi
}

setup_performance_vars() {
    sudo mkdir -p /etc/environment.d
    sudo tee /etc/environment.d/performance.conf > /dev/null <<EOF
MESA_SHADER_CACHE_MAX_SIZE=12G
__GL_SHADER_DISK_CACHE_SIZE=12000000000
EOF
}

setup_boot_timeout() {
    local bootloader=$(cat "$STATE_DIR/bootloader")
    
    if [[ "$bootloader" == "systemd-boot" ]]; then
        local esp_path=$(cat "$STATE_DIR/esp_path" 2>/dev/null)
        
        if [ -z "$esp_path" ]; then
            if [ -d /boot/loader ]; then
                esp_path="/boot"
            elif [ -d /boot/efi/loader ]; then
                esp_path="/boot/efi"
            elif [ -d /boot/EFI/systemd ]; then
                esp_path="/boot"
            elif [ -d /boot/efi/EFI/systemd ]; then
                esp_path="/boot/efi"
            else
                if mount | grep -q "/boot/efi "; then
                    esp_path="/boot/efi"
                elif mount | grep -q "/boot "; then
                    esp_path="/boot"
                else
                    return 1
                fi
            fi
        fi
        
        local loader_conf=""
        if [ -f "${esp_path}/loader/loader.conf" ]; then
            loader_conf="${esp_path}/loader/loader.conf"
        elif [ -f "/boot/loader/loader.conf" ]; then
            loader_conf="/boot/loader/loader.conf"
        elif [ -f "/boot/efi/loader/loader.conf" ]; then
            loader_conf="/boot/efi/loader/loader.conf"
        else
            if [ -d "${esp_path}/loader" ]; then
                loader_conf="${esp_path}/loader/loader.conf"
            elif [ -d "/boot/loader" ]; then
                loader_conf="/boot/loader/loader.conf"
            else
                sudo mkdir -p "${esp_path}/loader"
                loader_conf="${esp_path}/loader/loader.conf"
            fi
        fi
        
        echo "timeout 2" | sudo tee "$loader_conf" > /dev/null
        
    elif [[ "$bootloader" == "grub" ]]; then
        if [ -f /etc/default/grub ]; then
            if grep -q "^GRUB_TIMEOUT=" /etc/default/grub; then
                sudo sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=2/' /etc/default/grub
            else
                echo 'GRUB_TIMEOUT=2' | sudo tee -a /etc/default/grub
            fi
            if grep -q "^GRUB_TIMEOUT_STYLE=" /etc/default/grub; then
                sudo sed -i 's/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=menu/' /etc/default/grub
            else
                echo 'GRUB_TIMEOUT_STYLE=menu' | sudo tee -a /etc/default/grub
            fi
            sudo update-grub
        fi
    fi
}

setup_secureboot() {
    local distro=$(cat "$STATE_DIR/distro")
    local bootloader=$(cat "$STATE_DIR/bootloader")
    local motherboard_brand=$(cat "$STATE_DIR/motherboard_brand")
    local secureboot_state=$(cat "$STATE_DIR/secureboot_state")
    local secureboot_support=$(cat "$STATE_DIR/secureboot_support")
    
    if [[ "$secureboot_support" == "unsupported" ]]; then
        return 0
    fi
    
    if [[ "$distro" == "debian" ]]; then
        if ! command -v mokutil &>/dev/null; then
            return 0
        fi
        
        if [[ "$secureboot_state" != "enabled" ]]; then
            return 0
        fi
        
        if [ ! -f /var/lib/dkms/mok.pub ]; then
            return 0
        fi
        
        if sudo mokutil --list-enrolled 2>/dev/null | grep -q "Debian Secure Boot"; then
            return 0
        fi
        
        sudo mokutil --import /var/lib/dkms/mok.pub
        
    elif [[ "$distro" == "arch" ]]; then
        if [[ "$bootloader" != "systemd-boot" ]]; then
            return 0
        fi
        
        if [[ "$secureboot_state" == "enabled" ]]; then
            return 0
        fi
        
        if ! command -v sbctl &>/dev/null; then
            sudo pacman -S --noconfirm sbctl
        fi
        
        if ! sudo sbctl status 2>/dev/null | grep -q "Setup Mode.*Enabled"; then
            return 0
        fi
        
        if [ ! -f /etc/secureboot/keys/db/db.key ] && [ ! -f /usr/share/secureboot/keys/db/db.key ]; then
            sudo sbctl create-keys
        fi
        
        if ! sudo sbctl status | grep -q "Vendor Keys:.*microsoft"; then
            if [[ "$motherboard_brand" == "asus" ]] || [[ "$motherboard_brand" == "gigabyte" ]]; then
                sudo sbctl enroll-keys --microsoft
            else
                sudo sbctl enroll-keys --microsoft --firmware-builtin
            fi
        fi
        
        if [ -f /boot/vmlinuz-linux ]; then
            sudo sbctl sign -s /boot/vmlinuz-linux || true
        fi
        if [ -f /boot/vmlinuz-linux-lts ]; then
            sudo sbctl sign -s /boot/vmlinuz-linux-lts || true
        fi
        
        if [ -f /boot/EFI/Linux/arch-linux.efi ]; then
            sudo sbctl sign -s /boot/EFI/Linux/arch-linux.efi || true
        elif [ -f /boot/efi/Linux/arch-linux.efi ]; then
            sudo sbctl sign -s /boot/efi/Linux/arch-linux.efi || true
        else
            sudo mkdir -p /boot/EFI/Linux
            sudo mkinitcpio -P
            [ -f /boot/EFI/Linux/arch-linux.efi ] && sudo sbctl sign -s /boot/EFI/Linux/arch-linux.efi || true
        fi
        
        local esp_path=$(cat "$STATE_DIR/esp_path" 2>/dev/null)
        [ -z "$esp_path" ] && esp_path="/boot"
        
        [ -f "${esp_path}/EFI/systemd/systemd-bootx64.efi" ] && sudo sbctl sign -s "${esp_path}/EFI/systemd/systemd-bootx64.efi" || true
        [ -f /usr/lib/systemd/boot/efi/systemd-bootx64.efi ] && sudo sbctl sign -s -o /usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed /usr/lib/systemd/boot/efi/systemd-bootx64.efi || true
        [ -f "${esp_path}/EFI/BOOT/BOOTX64.EFI" ] && sudo sbctl sign -s "${esp_path}/EFI/BOOT/BOOTX64.EFI" || true
        [ -f /usr/lib/fwupd/efi/fwupdx64.efi ] && sudo sbctl sign -s -o /usr/lib/fwupd/efi/fwupdx64.efi.signed /usr/lib/fwupd/efi/fwupdx64.efi || true
    fi
}

# ============================================================================
# INSTALAÇÃO
# ============================================================================

install_base() {
    local distro=$(cat "$STATE_DIR/distro")
    
    case "$distro" in
        debian)
            sudo apt install -y podman git nano gamemode fastfetch
            ;;
        arch)
            sudo pacman -S --noconfirm podman git nano fastfetch gamemode
            ;;
    esac
}

install_nvidia_with_mok() {
    local debian_version=""
    
    if [ -f /etc/debian_version ]; then
        debian_version=$(cat /etc/debian_version)
    fi
    
    if [ -z "$debian_version" ]; then
        return 1
    fi
    
    if echo "$debian_version" | grep -qiE "testing|sid"; then
        echo "${CYAN}Digite a versão do Debian para o driver NVIDIA (ex: 12, 11, 10):${NC}"
        read -p "Versão: " user_version
        
        if [ -n "$user_version" ]; then
            debian_version="$user_version"
        else
            return 1
        fi
    else
        debian_version=$(echo "$debian_version" | cut -d. -f1)
    fi
    
    sudo apt install -y linux-headers-amd64
    
    curl -LO https://developer.download.nvidia.com/compute/cuda/repos/debian${debian_version}/x86_64/cuda-keyring_1.1-1_all.deb
    sudo dpkg -i cuda-keyring_1.1-1_all.deb
    sudo apt update
    sudo apt -y install nvidia-open
    rm -f cuda-keyring_1.1-1_all.deb
    
    if ! command -v mokutil &>/dev/null; then
        sudo apt install -y mokutil
    fi
    
    if [ ! -f /var/lib/dkms/mok.pub ]; then
        sudo dkms generate_mok
    fi
    
    if [ -f /var/lib/dkms/mok.pub ]; then
        echo "${YELLOW}Importando chave MOK para Secure Boot...${NC}"
        echo "${YELLOW}Digite uma senha (8-16 caracteres) quando solicitado:${NC}"
        sudo mokutil --import /var/lib/dkms/mok.pub
        
        echo "${GREEN}✓ Chave MOK importada com sucesso!${NC}"
        echo "${YELLOW}⚠ IMPORTANTE:${NC}"
        echo "${YELLOW}  1. Reinicie o sistema${NC}"
        echo "${YELLOW}  2. Durante a reinicialização, siga as instruções na tela para confirmar a senha${NC}"
        echo "${YELLOW}  3. Após confirmar, o driver NVIDIA será carregado corretamente${NC}"
    else
        echo "${RED}✗ Arquivo /var/lib/dkms/mok.pub não encontrado${NC}"
    fi
}

install_gpu_drivers() {
    local gpu=$(cat "$STATE_DIR/gpu_driver")
    local distro=$(cat "$STATE_DIR/distro")
    
    case "$distro" in
        debian)
            case "$gpu" in
                intel|amd)
                    sudo apt install -y mesa-vulkan-drivers
                    ;;
                nvidia)
                    install_nvidia_with_mok
                    ;;
            esac
            ;;
            
        arch)
            case "$gpu" in
                intel)
                    sudo pacman -S --noconfirm vulkan-intel
                    ;;
                amd)
                    sudo pacman -S --noconfirm vulkan-radeon
                    ;;
                nvidia)
                    sudo pacman -S --noconfirm nvidia-open
                    ;;
            esac
            ;;
    esac
}

install_cpu_microcode() {
    local cpu=$(cat "$STATE_DIR/cpu")
    local distro=$(cat "$STATE_DIR/distro")
    
    case "$distro" in
        debian)
            case "$cpu" in
                intel)
                    sudo apt install -y intel-microcode
                    ;;
                amd)
                    sudo apt install -y amd64-microcode
                    ;;
            esac
            ;;
        arch)
            case "$cpu" in
                intel)
                    sudo pacman -S --noconfirm intel-ucode
                    ;;
                amd)
                    sudo pacman -S --noconfirm amd-ucode
                    ;;
            esac
            ;;
    esac
}

install_desktop() {
    local desktop=$(cat "$STATE_DIR/desktop")
    local distro=$(cat "$STATE_DIR/distro")
    
    case "$distro" in
        debian)
            case "$desktop" in
                gnome)
                    sudo apt install -y gdm3 gnome-initial-setup gnome-console gnome-software gnome-tweaks gnome-disk-utility gnome-backgrounds
                    sudo systemctl enable gdm3
                    ;;
                kde)
                    sudo apt install -y sddm plasma-desktop plasma-workspace-wallpapers konsole dolphin discover kdeconnect partitionmanager ark
                    sudo systemctl enable sddm
                    ;;
                dank)
                    curl -fsSL https://install.danklinux.com | sh
                    ;;
                none)
                    echo "${YELLOW}Nenhum desktop instalado.${NC}"
                    ;;
            esac
            ;;
            
        arch)
            case "$desktop" in
                gnome)
                    sudo pacman -S --noconfirm gnome-initial-setup gnome-console gnome-software gnome-tweaks gnome-disk-utility gnome-backgrounds
                    sudo systemctl enable gdm
                    ;;
                kde)
                    sudo pacman -S --noconfirm plasma-meta konsole dolphin kdeconnect partitionmanager ark
                    sudo systemctl enable plasmalogin
                    ;;
                cosmic)
                    sudo pacman -S --noconfirm cosmic-session cosmic-terminal cosmic-files cosmic-store cosmic-wallpapers xdg-desktop-portal-gtk xdg-user-dirs
                    sudo systemctl enable cosmic-greeter
                    ;;
                dank)
                    curl -fsSL https://install.danklinux.com | sh
                    ;;
                none)
                    echo "${YELLOW}Nenhum desktop instalado.${NC}"
                    ;;
            esac
            ;;
    esac
}

install_produtividade() {
    local prod=$(cat "$STATE_DIR/produtividade")
    
    if [[ "$prod" == "none" ]]; then
        return
    fi
    
    for app in $prod; do
        case "$app" in
            onlyoffice)
                flatpak install --user -y flathub org.onlyoffice.desktopeditors
                ;;
            obsidian)
                flatpak install --user -y flathub md.obsidian.Obsidian
                ;;
            zen)
                flatpak install --user -y flathub app.zen_browser.zen
                ;;
            helium)
                if [[ "$(cat "$STATE_DIR/distro")" == "debian" ]]; then
                    curl -fsSL https://raw.githubusercontent.com/imputnet/helium-linux/main/pubkey.asc | sudo gpg --dearmor -o /usr/share/keyrings/helium.gpg
                    echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/helium.gpg] https://pkg.helium.computer/deb stable main" | sudo tee /etc/apt/sources.list.d/helium.list
                    sudo apt update
                    sudo apt install -y helium-bin
                else
                    sudo pacman -S --noconfirm helium-browser-bin
                fi
                ;;
            discord)
                flatpak install --user -y flathub com.discordapp.Discord
                ;;
        esac
    done
}

install_multimidia() {
    local multi=$(cat "$STATE_DIR/multimidia")
    
    if [[ "$multi" == "none" ]]; then
        return
    fi
    
    for app in $multi; do
        case "$app" in
            gimp)
                flatpak install --user -y flathub org.gimp.GIMP
                ;;
            kdenlive)
                flatpak install --user -y flathub org.kde.kdenlive
                ;;
            obs)
                flatpak install --user -y flathub com.obsproject.Studio
                ;;
            handbrake)
                flatpak install --user -y flathub fr.handbrake.ghb
                ;;
            audacity)
                flatpak install --user -y flathub org.audacityteam.Audacity
                ;;
        esac
    done
}

install_games() {
    local games=$(cat "$STATE_DIR/games")
    
    if [[ "$games" == "none" ]]; then
        return
    fi
    
    for app in $games; do
        case "$app" in
            steam)
                flatpak install --user -y flathub com.valvesoftware.Steam
                ;;
            proton)
                flatpak install --user -y flathub net.davidotek.pupgui2
                ;;
            prism)
                flatpak install --user -y flathub org.prismlauncher.PrismLauncher
                ;;
            sober)
                flatpak install --user -y flathub org.vinegarhq.Sober
                ;;
            heroic)
                flatpak install --user -y flathub com.heroicgameslauncher.hgl
                ;;
        esac
    done
}

install_extras() {
    local extras=$(cat "$STATE_DIR/extras")
    local distro=$(cat "$STATE_DIR/distro")
    
    if [[ "$extras" == "none" ]]; then
        return
    fi
    
    for app in $extras; do
        case "$app" in
            distroshelf)
                flatpak install --user -y flathub com.ranfdev.DistroShelf
                if [[ "$distro" == "debian" ]]; then
                    sudo apt install -y distrobox
                elif [[ "$distro" == "arch" ]]; then
                    sudo pacman -S --noconfirm distrobox
                fi
                ;;
            codium)
                flatpak install --user -y flathub com.vscodium.codium
                ;;
            gamescope)
                if [[ "$distro" == "arch" ]]; then
                    sudo pacman -S --noconfirm gamescope
                elif [[ "$distro" == "debian" ]]; then
                    sudo apt install -y gamescope
                fi
                ;;
            alpaca)
                flatpak install --user -y flathub com.jeffser.Alpaca
                ;;
            gearlever)
                flatpak install --user -y flathub it.mijorus.gearlever
                ;;
        esac
    done
}

# ============================================================================
# LIMPEZA
# ============================================================================

remove_packages() {
    local distro=$(cat "$STATE_DIR/distro")
    
    if [[ "$distro" == "debian" ]]; then
        sudo apt remove -y vim-common
        sudo apt autoremove -y
    fi
}

# ============================================================================
# FINALIZAÇÃO
# ============================================================================

ask_reboot() {
    echo ""
    echo "${GREEN}Instalação concluída!${NC}"
    echo "${YELLOW}Recomenda-se reiniciar o sistema.${NC}"
    if confirm "Deseja reiniciar agora?"; then
        sudo reboot
    else
        echo "${YELLOW}Lembre-se de reiniciar posteriormente.${NC}"
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    # DETECÇÃO
    detect_distro
    detect_gpu
    detect_cpu
    detect_motherboard_brand
    detect_bootloader
    detect_secureboot_support
    
    # SELEÇÃO
    select_desktop
    select_produtividade
    select_multimidia
    select_games
    select_extras
    
    # SETUP (configuração de fontes e infraestrutura)
    setup_sources
    
    # INSTALAÇÃO (pacotes e aplicativos)
    install_base
    install_cpu_microcode
    install_gpu_drivers
    install_desktop
    install_produtividade
    install_multimidia
    install_games
    install_extras
    
    # SETUP (configurações pós-instalação)
    setup_security
    setup_package_managers
    setup_network
    setup_zram
    setup_btrfs_compression
    setup_performance_vars
    remove_packages
    setup_boot_timeout
    setup_secureboot
    
    # FINALIZAÇÃO
    ask_reboot
}

main
