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
# DETECÇÃO DE HARDWARE E SISTEMA
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
    local brand=""
    
    if [ -f /sys/class/dmi/id/board_vendor ]; then
        brand=$(cat /sys/class/dmi/id/board_vendor 2>/dev/null)
    fi
    
    if [ -z "$brand" ] || [ "$brand" == "Unknown" ] || [ "$brand" == "To be filled by O.E.M." ]; then
        if [ -f /sys/class/dmi/id/sys_vendor ]; then
            brand=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)
        fi
    fi
    
    case "$brand" in
        *"ASUS"*|*"Asus"*) echo "asus" ;;
        *"Gigabyte"*|*"GIGABYTE"*) echo "gigabyte" ;;
        *"MSI"*|*"Micro-Star"*) echo "msi" ;;
        *"Acer"*) echo "acer" ;;
        *"Dell"*) echo "dell" ;;
        *"HP"*|*"Hewlett-Packard"*) echo "hp" ;;
        *"Lenovo"*) echo "lenovo" ;;
        *) echo "gigabyte" ;;
    esac
}

detect_bootloader() {
    if [ -d /boot/EFI/systemd ] || [ -f /boot/EFI/systemd/systemd-bootx64.efi ] || [ -f /boot/loader/loader.conf ]; then
        echo "systemd-boot"
        return
    fi
    
    if [ -f /boot/limine.conf ] || [ -f /boot/EFI/LIMINE/limine.efi ]; then
        echo "limine"
        return
    fi
    
    if [ -f /boot/grub/grub.cfg ] || [ -f /boot/EFI/GRUB/grubx64.efi ] || [ -f /etc/default/grub ]; then
        echo "grub"
        return
    fi
    
    if [ -d /boot/EFI/Linux ] && [ "$(ls -A /boot/EFI/Linux/*.efi 2>/dev/null | head -1)" ]; then
        echo "uki"
        return
    fi
    
    echo "none"
}

detect_secureboot_support() {
    if [ -d /sys/firmware/efi ] && command -v mokutil &>/dev/null; then
        if sudo mokutil --sb-state 2>/dev/null | grep -qi "SecureBoot enabled"; then
            echo "enabled" > "$STATE_DIR/secureboot_state"
        else
            echo "disabled" > "$STATE_DIR/secureboot_state"
        fi
        echo "supported" > "$STATE_DIR/secureboot_support"
    else
        echo "unsupported" > "$STATE_DIR/secureboot_support"
    fi
}

# ============================================================================
# CONFIGURAÇÃO DE SECURE BOOT PARA ARCH
# ============================================================================

setup_secureboot_arch() {
    local bootloader=$(cat "$STATE_DIR/bootloader")
    local motherboard_brand=$(cat "$STATE_DIR/motherboard_brand")
    local secureboot_state=$(cat "$STATE_DIR/secureboot_state")
    
    if [[ "$secureboot_state" == "enabled" ]]; then
        echo "${GREEN}✓ Secure Boot já está ativo no sistema${NC}"
        sudo sbctl status
        return 0
    fi
    
    if [[ "$secureboot_state" == "unsupported" ]]; then
        echo "${YELLOW}Secure Boot não é suportado neste sistema (modo BIOS ou sem UEFI)${NC}"
        return 1
    fi
    
    echo "${CYAN}────────────────────────────────────────────────────────────────────${NC}"
    echo "${GREEN}► Configurando Secure Boot${NC}"
    echo "${CYAN}────────────────────────────────────────────────────────────────────${NC}"
    
    if ! command -v sbctl &>/dev/null; then
        echo "${YELLOW}Instalando sbctl...${NC}"
        sudo pacman -S --noconfirm sbctl
    else
        echo "${GREEN}✓ sbctl já está instalado${NC}"
    fi
    
    echo "${YELLOW}Status sbctl:${NC}"
    sudo sbctl status
    
    if [ ! -f /etc/secureboot/keys/db/db.key ] && [ ! -f /usr/share/secureboot/keys/db/db.key ]; then
        echo "${YELLOW}Criando chaves Secure Boot...${NC}"
        sudo sbctl create-keys
    else
        echo "${GREEN}✓ Chaves Secure Boot já existem${NC}"
    fi
    
    if sudo sbctl status | grep -q "Vendor Keys:.*microsoft"; then
        echo "${GREEN}✓ Chaves já estão enrolladas${NC}"
    else
        echo "${YELLOW}Enrolando chaves...${NC}"
        if [[ "$motherboard_brand" == "asus" ]] || [[ "$motherboard_brand" == "gigabyte" ]]; then
            echo "${YELLOW}⚠ Detectada placa-mãe ${motherboard_brand}. Usando apenas --microsoft${NC}"
            sudo sbctl enroll-keys --microsoft
        else
            echo "${YELLOW}⚠ Detectada placa-mãe ${motherboard_brand}. Usando --microsoft --firmware-builtin${NC}"
            sudo sbctl enroll-keys --microsoft --firmware-builtin
        fi
    fi
    
    echo "${YELLOW}Verificando arquivos para assinar...${NC}"
    sudo sbctl verify
    
    echo "${YELLOW}Assinando arquivos...${NC}"
    
    # Kernel
    echo "  Assinando kernels..."
    if [ -f /boot/vmlinuz-linux ]; then
        sudo sbctl sign -s /boot/vmlinuz-linux || true
    fi
    if [ -f /boot/vmlinuz-linux-lts ]; then
        sudo sbctl sign -s /boot/vmlinuz-linux-lts || true
    fi
    
    # UKI
    echo "  Assinando UKI..."
    if [ -f /boot/EFI/Linux/arch-linux.efi ]; then
        sudo sbctl sign -s /boot/EFI/Linux/arch-linux.efi || true
    elif [ -f /boot/efi/Linux/arch-linux.efi ]; then
        sudo sbctl sign -s /boot/efi/Linux/arch-linux.efi || true
    else
        echo "    ⚠ UKI não encontrado. Gerando..."
        sudo mkdir -p /boot/EFI/Linux
        sudo mkinitcpio -P
        if [ -f /boot/EFI/Linux/arch-linux.efi ]; then
            sudo sbctl sign -s /boot/EFI/Linux/arch-linux.efi || true
        fi
    fi
    
    # systemd-boot
    if [[ "$bootloader" == "systemd-boot" ]] || [[ "$bootloader" == "uki" ]]; then
        echo "  Assinando systemd-boot..."
        if [ -f /boot/EFI/systemd/systemd-bootx64.efi ]; then
            sudo sbctl sign -s /boot/EFI/systemd/systemd-bootx64.efi || true
        fi
        if [ -f /usr/lib/systemd/boot/efi/systemd-bootx64.efi ]; then
            sudo sbctl sign -s -o /usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed /usr/lib/systemd/boot/efi/systemd-bootx64.efi || true
        fi
        if [ -f /boot/EFI/BOOT/BOOTX64.EFI ]; then
            sudo sbctl sign -s /boot/EFI/BOOT/BOOTX64.EFI || true
        fi
    fi
    
    # Limine
    if [[ "$bootloader" == "limine" ]]; then
        echo "  Assinando Limine..."
        if [ -f /boot/EFI/LIMINE/limine.efi ]; then
            sudo sbctl sign -s /boot/EFI/LIMINE/limine.efi || true
        fi
        if command -v limine-enroll-config &>/dev/null; then
            echo "  Configurando Limine para Secure Boot..."
            if [ -f /etc/default/limine ]; then
                sudo sed -i 's/^#ENABLE_ENROLL_LIMINE_CONFIG=.*/ENABLE_ENROLL_LIMINE_CONFIG=yes/' /etc/default/limine || \
                echo "ENABLE_ENROLL_LIMINE_CONFIG=yes" | sudo tee -a /etc/default/limine
            else
                echo "ENABLE_ENROLL_LIMINE_CONFIG=yes" | sudo tee /etc/default/limine
            fi
            sudo limine-enroll-config
            sudo limine-update
        fi
    fi
    
    # GRUB
    if [[ "$bootloader" == "grub" ]]; then
        echo "  Assinando GRUB..."
        if [ -f /boot/EFI/GRUB/grubx64.efi ]; then
            sudo sbctl sign -s /boot/EFI/GRUB/grubx64.efi || true
        fi
        if command -v grub-install &>/dev/null; then
            sudo grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --modules="tpm" --disable-shim-lock || true
        fi
    fi
    
    # fwupd
    echo "  Assinando fwupd..."
    if [ -f /usr/lib/fwupd/efi/fwupdx64.efi ]; then
        sudo sbctl sign -s -o /usr/lib/fwupd/efi/fwupdx64.efi.signed /usr/lib/fwupd/efi/fwupdx64.efi || true
    fi
    
    echo "${YELLOW}Verificando assinaturas finais...${NC}"
    sudo sbctl verify
    
    echo ""
    echo "${GREEN}✓ Secure Boot configurado!${NC}"
    echo "${YELLOW}Recomenda-se:${NC}"
    echo "  1. Reiniciar o sistema: sudo reboot"
    echo "  2. Entrar na BIOS/UEFI e ativar o Secure Boot"
    echo "  3. Verificar com: sbctl status"
}

setup_secureboot() {
    local distro=$(cat "$STATE_DIR/distro")
    
    if [[ "$distro" != "arch" ]]; then
        echo "${YELLOW}Secure Boot é suportado apenas no Arch Linux. Pulando...${NC}"
        return
    fi
    
    local secureboot_support=$(cat "$STATE_DIR/secureboot_support")
    
    if [[ "$secureboot_support" == "unsupported" ]]; then
        echo "${YELLOW}Secure Boot não é suportado neste sistema (modo BIOS ou sem UEFI). Pulando...${NC}"
        return
    fi
    
    setup_secureboot_arch
}

# ============================================================================
# CONFIGURAÇÃO DE BOOT TIMEOUT
# ============================================================================

setup_boot_timeout() {
    local bootloader=$(cat "$STATE_DIR/bootloader")
    
    case "$bootloader" in
        "systemd-boot"|"uki")
            if [ -d /boot/EFI/systemd ]; then
                local loader_conf="/boot/EFI/systemd/loader.conf"
            elif [ -d /boot/loader ]; then
                local loader_conf="/boot/loader/loader.conf"
            else
                return 1
            fi
            
            if [ -f "$loader_conf" ]; then
                if grep -q "^timeout" "$loader_conf"; then
                    sudo sed -i 's/^timeout.*/timeout 2/' "$loader_conf"
                else
                    echo "timeout 2" | sudo tee -a "$loader_conf"
                fi
            else
                echo "timeout 2" | sudo tee "$loader_conf"
            fi
            ;;
            
        "limine")
            if [ -f /boot/limine.conf ]; then
                if grep -q "^TIMEOUT" /boot/limine.conf; then
                    sudo sed -i 's/^TIMEOUT=.*/TIMEOUT=2/' /boot/limine.conf
                else
                    echo "TIMEOUT=2" | sudo tee -a /boot/limine.conf
                fi
            fi
            ;;
            
        "grub")
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
            ;;
    esac
}

# ============================================================================
# FUNÇÕES DE SELEÇÃO INTERATIVAS
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
# CONFIGURAÇÃO DE REPOSITÓRIOS
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

# ============================================================================
# INSTALAÇÃO DE PACOTES BASE
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

# ============================================================================
# CONFIGURAÇÃO DE SEGURANÇA
# ============================================================================

setup_security() {
    local distro=$(cat "$STATE_DIR/distro")
    
    case "$distro" in
        debian)
            sudo apt install -y ufw
            sudo systemctl enable ufw
            sudo systemctl start ufw
            sudo apt install -y fwupd
            sudo systemctl enable fwupd
            sudo systemctl start fwupd
            ;;
            
        arch)
            sudo pacman -S --noconfirm apparmor
            sudo systemctl enable apparmor
            sudo systemctl start apparmor
            sudo pacman -S --noconfirm fwupd
            sudo systemctl enable fwupd
            sudo systemctl start fwupd
            ;;
    esac
}

# =============================================================================
# GERENCIADORES DE PACOTES (FLATPAK, ETC)
# =============================================================================

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

# =============================================================================
# INSTALAÇÃO DE DESKTOP
# =============================================================================

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

# =============================================================================
# INSTALAÇÃO DE APLICATIVOS
# =============================================================================

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

# =============================================================================
# CONFIGURAÇÕES ESPECÍFICAS DO DEBIAN
# =============================================================================

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
        sudo tee /etc/systemd/zram-generator.conf > /dev/null <<EOF
[zram0]
zram-size = ram * 0.25
compression-algorithm = zstd
swap-priority = 100
EOF
        sudo systemctl daemon-reload
        sudo systemctl start systemd-zram-setup@zram0.service
    elif [[ "$distro" == "arch" ]]; then
        sudo tee /etc/systemd/zram-generator.conf > /dev/null <<EOF
[zram0]
zram-size = ram * 0.25
compression-algorithm = zstd
swap-priority = 100
EOF
        sudo systemctl daemon-reload
        sudo systemctl start systemd-zram-setup@zram0.service
    fi
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

# =============================================================================
# DRIVERS
# =============================================================================

import_mok_key() {
    if ! command -v mokutil &>/dev/null; then
        return
    fi
    
    if ! sudo mokutil --sb-state 2>/dev/null | grep -qi "SecureBoot enabled"; then
        return
    fi
    
    if [ ! -f /var/lib/dkms/mok.pub ]; then
        return
    fi
    
    if sudo mokutil --list-enrolled 2>/dev/null | grep -q "Debian Secure Boot"; then
        return
    fi
    
    echo "${YELLOW}Digite uma senha (8-16 caracteres) para o Secure Boot:${NC}"
    sudo mokutil --import /var/lib/dkms/mok.pub
    echo "${YELLOW}Reinicie o sistema para concluir o enrollment.${NC}"
}

install_nvidia_debian() {
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        local debian_version="${VERSION_ID:-}"
        
        if [ -z "$debian_version" ]; then
            return 1
        fi
        
        curl -LO https://developer.download.nvidia.com/compute/cuda/repos/debian${debian_version}/x86_64/cuda-keyring_1.1-1_all.deb
        sudo dpkg -i cuda-keyring_1.1-1_all.deb
        sudo apt update
        sudo apt -y install nvidia-open
        rm -f cuda-keyring_1.1-1_all.deb
        
        import_mok_key
    else
        return 1
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
                    install_nvidia_debian
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

# =============================================================================
# CONFIGURAÇÕES DE PERFORMANCE
# =============================================================================

setup_performance_vars() {
    sudo mkdir -p /etc/environment.d
    sudo tee /etc/environment.d/performance.conf > /dev/null <<EOF
MESA_SHADER_CACHE_MAX_SIZE=12G
__GL_SHADER_DISK_CACHE_SIZE=12000000000
EOF
}

# =============================================================================
# LIMPEZA DE PACOTES INDESEJADOS
# =============================================================================

remove_packages() {
    local distro=$(cat "$STATE_DIR/distro")
    
    if [[ "$distro" == "debian" ]]; then
        sudo apt remove -y vim-common
        sudo apt autoremove -y
    fi
}

# =============================================================================
# REINICIALIZAÇÃO
# =============================================================================

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

# =============================================================================
# FUNÇÃO PRINCIPAL
# =============================================================================

main() {
    detect_distro
    detect_gpu
    detect_cpu
    
    # Detecta marca da placa-mãe para Secure Boot
    if [ -f /sys/class/dmi/id/board_vendor ]; then
        detect_motherboard_brand
    else
        echo "gigabyte" > "$STATE_DIR/motherboard_brand"
    fi
    
    detect_bootloader
    detect_secureboot_support
    
    select_desktop
    select_produtividade
    select_multimidia
    select_games
    select_extras
    
    setup_sources
    install_base
    setup_security
    install_cpu_microcode
    install_gpu_drivers
    install_desktop
    setup_package_managers
    install_produtividade
    install_multimidia
    install_games
    install_extras
    setup_network
    setup_zram
    setup_btrfs_compression
    setup_performance_vars
    remove_packages
    setup_boot_timeout
    setup_secureboot
    ask_reboot
}

main
