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

detect_distro() {
    if [ -f /etc/debian_version ]; then
        echo "debian" > "$STATE_DIR/distro"
    elif [ -f /etc/arch-release ]; then
        echo "arch" > "$STATE_DIR/distro"
    elif [ -f /etc/almalinux-release ]; then
        echo "almalinux" > "$STATE_DIR/distro"
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

select_desktop() {
    clear_screen
    show_section "AMBIENTE DESKTOP / DESKTOP ENVIRONMENT"
    show_option "1" "GNOME"
    show_option "2" "KDE Plasma"
    show_option "3" "Nenhum"
    
    local distro=$(cat "$STATE_DIR/distro")
    
    if [[ "$distro" == "arch" ]]; then
        show_option "4" "COSMIC"
        show_option "5" "Dank Linux"
    fi
    
    echo ""
    read -p "Opção [1-3] (Enter para GNOME): " de_opt
    
    case "$de_opt" in
        1|"") echo "gnome" > "$STATE_DIR/desktop"
             echo "${GREEN}Desktop: GNOME${NC}" ;;
        2) echo "kde" > "$STATE_DIR/desktop"
           echo "${GREEN}Desktop: KDE Plasma${NC}" ;;
        3) echo "none" > "$STATE_DIR/desktop"
           echo "${GREEN}Desktop: Nenhum${NC}" ;;
        4) 
            if [[ "$distro" == "arch" ]]; then
                echo "cosmic" > "$STATE_DIR/desktop"
                echo "${GREEN}Desktop: COSMIC${NC}"
            else
                echo "${RED}Opção inválida.${NC}"
                sleep 1
                select_desktop
                return
            fi
            ;;
        5)
            if [[ "$distro" == "arch" ]]; then
                echo "dank" > "$STATE_DIR/desktop"
                echo "${GREEN}Desktop: Dank Linux${NC}"
            else
                echo "${RED}Opção inválida.${NC}"
                sleep 1
                select_desktop
                return
            fi
            ;;
        *) echo "${RED}Opção inválida.${NC}"
           sleep 1
           select_desktop
           return
    esac
    sleep 2
}

select_browser() {
    clear_screen
    show_section "SELECIONE O BROWSER"
    show_option "1" "Zen Browser (Flatpak)"
    show_option "2" "Helium Browser"
    show_option "3" "Firefox (Flatpak)"
    show_option "4" "Google Chrome (Flatpak)"
    echo ""
    read -p "Opção [1-4] (Enter para Zen Browser): " browser_opt
    
    case "$browser_opt" in
        1|"") echo "zen" > "$STATE_DIR/browser"
             echo "${GREEN}Browser: Zen Browser${NC}" ;;
        2) 
            local distro=$(cat "$STATE_DIR/distro")
            if [[ "$distro" == "almalinux" ]]; then
                echo "${RED}Helium Browser não está disponível para AlmaLinux.${NC}"
                sleep 2
                select_browser
                return
            else
                echo "helium" > "$STATE_DIR/browser"
                echo "${GREEN}Browser: Helium Browser${NC}"
            fi
            ;;
        3) echo "firefox" > "$STATE_DIR/browser"
           echo "${GREEN}Browser: Firefox${NC}" ;;
        4) echo "chrome" > "$STATE_DIR/browser"
           echo "${GREEN}Browser: Google Chrome${NC}" ;;
        *) echo "${RED}Opção inválida.${NC}"
           sleep 1
           select_browser
           return
    esac
    sleep 1
}

select_office() {
    clear_screen
    show_section "APLICATIVOS OFFICE E MULTIMÍDIA"
    echo "  Selecione os aplicativos que deseja instalar (escolha múltiplos):"
    echo ""
    show_option "1" "OnlyOffice (Suite de escritório)"
    show_option "2" "GIMP (Editor de imagens)"
    show_option "3" "Kdenlive (Editor de vídeo)"
    show_option "4" "OBS Studio (Gravação/Streaming)"
    show_option "5" "Obsidian (Notas/Knowledge base)"
    echo ""
    echo "  Digite os números separados por espaço (ex: 1 3 5) ou Enter para nenhum:"
    read -p "Opções: " -a office_opts
    
    if [[ ${#office_opts[@]} -eq 0 ]]; then
        echo "none" > "$STATE_DIR/office"
        echo "${GREEN}Nenhum aplicativo office selecionado.${NC}"
    else
        local office_list=""
        for opt in "${office_opts[@]}"; do
            case "$opt" in
                1) office_list="${office_list} onlyoffice" ;;
                2) office_list="${office_list} gimp" ;;
                3) office_list="${office_list} kdenlive" ;;
                4) office_list="${office_list} obs" ;;
                5) office_list="${office_list} obsidian" ;;
                *) echo "${RED}Opção inválida: $opt${NC}" ;;
            esac
        done
        echo "$office_list" > "$STATE_DIR/office"
        echo "${GREEN}Aplicativo(s) office selecionado(s)!${NC}"
    fi
    sleep 1
}

select_games() {
    clear_screen
    show_section "JOGOS E PLATAFORMAS"
    echo "  Selecione os jogos/plataformas que deseja instalar (escolha múltiplos):"
    echo ""
    show_option "1" "Steam"
    show_option "2" "Proton Plus"
    show_option "3" "Prism Launcher (Minecraft)"
    show_option "4" "Sober (Roblox)"
    show_option "5" "Faugus Launcher"
    echo ""
    echo "  Digite os números separados por espaço (ex: 1 3 5) ou Enter para nenhum:"
    read -p "Opções: " -a games_opts
    
    if [[ ${#games_opts[@]} -eq 0 ]]; then
        echo "none" > "$STATE_DIR/games"
        echo "${GREEN}Nenhum jogo selecionado.${NC}"
    else
        local games_list=""
        for opt in "${games_opts[@]}"; do
            case "$opt" in
                1) games_list="${games_list} steam" ;;
                2) games_list="${games_list} proton" ;;
                3) games_list="${games_list} prism" ;;
                4) games_list="${games_list} sober" ;;
                5) games_list="${games_list} faugus" ;;
                *) echo "${RED}Opção inválida: $opt${NC}" ;;
            esac
        done
        echo "$games_list" > "$STATE_DIR/games"
        echo "${GREEN}Jogo(s) selecionado(s)!${NC}"
    fi
    sleep 1
}

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
            
        almalinux)
            echo "${YELLOW}Adicionando EPEL...${NC}"
            sudo dnf install -y epel-release
            
            echo "${YELLOW}Adicionando RPM Fusion...${NC}"
            local rhel_version=$(rpm -E %rhel)
            sudo dnf install --nogpgcheck -y \
                https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-${rhel_version}.noarch.rpm \
                https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-${rhel_version}.noarch.rpm
            
            echo "${YELLOW}Habilitando CRB (CodeReady Builder)...${NC}"
            sudo /usr/bin/crb enable
            
            sudo dnf update -y
            sudo dnf upgrade -y
            ;;
    esac
}

install_base() {
    local distro=$(cat "$STATE_DIR/distro")
    
    case "$distro" in
        debian)
            sudo apt install -y podman neovim gamemode fastfetch
            ;;
        arch)
            sudo pacman -S --noconfirm podman neovim fastfetch gamemode
            ;;
        almalinux)
            sudo dnf install -y podman neovim gamemode fastfetch
            ;;
    esac
}

setup_security() {
    local distro=$(cat "$STATE_DIR/distro")
    
    echo "${CYAN}────────────────────────────────────────────────────────────────────${NC}"
    echo "${GREEN}► Configurando Firewall e Segurança${NC}"
    echo "${CYAN}────────────────────────────────────────────────────────────────────${NC}"
    
    case "$distro" in
        debian)
            echo "${YELLOW}Instalando e configurando UFW...${NC}"
            sudo apt install -y ufw
            sudo systemctl enable ufw
            sudo systemctl start ufw
            echo "${GREEN}✓ UFW instalado e habilitado${NC}"
            
            echo "${YELLOW}Verificando AppArmor...${NC}"
            sudo systemctl enable apparmor
            sudo systemctl start apparmor
            echo "${GREEN}✓ AppArmor habilitado${NC}"
            
            echo "${YELLOW}Instalando fwupd...${NC}"
            sudo apt install -y fwupd
            sudo systemctl enable fwupd
            sudo systemctl start fwupd
            echo "${GREEN}✓ fwupd instalado e habilitado${NC}"
            ;;
            
        arch)
            echo "${YELLOW}Instalando e configurando UFW...${NC}"
            sudo pacman -S --noconfirm ufw
            sudo systemctl enable ufw
            sudo systemctl start ufw
            echo "${GREEN}✓ UFW instalado e habilitado${NC}"
            
            echo "${YELLOW}Instalando e configurando AppArmor...${NC}"
            sudo pacman -S --noconfirm apparmor
            sudo systemctl enable apparmor
            sudo systemctl start apparmor
            echo "${GREEN}✓ AppArmor instalado e habilitado${NC}"
            
            echo "${YELLOW}Instalando fwupd...${NC}"
            sudo pacman -S --noconfirm fwupd
            sudo systemctl enable fwupd
            sudo systemctl start fwupd
            echo "${GREEN}✓ fwupd instalado e habilitado${NC}"
            ;;
            
        almalinux)
            echo "${YELLOW}Instalando e configurando Firewalld...${NC}"
            sudo dnf install -y firewalld
            sudo systemctl enable firewalld
            sudo systemctl start firewalld
            echo "${GREEN}✓ Firewalld instalado e habilitado${NC}"
            
            echo "${YELLOW}Instalando fwupd...${NC}"
            sudo dnf install -y fwupd
            sudo systemctl enable fwupd
            sudo systemctl start fwupd
            echo "${GREEN}✓ fwupd instalado e habilitado${NC}"
            
            echo "${YELLOW}ℹ AppArmor não é suportado no AlmaLinux (usa SELinux)${NC}"
            ;;
    esac
    
    echo ""
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
            
            sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
            ;;
        arch)
            sudo pacman -S --noconfirm flatpak
            ;;
        almalinux)
            sudo dnf install -y flatpak
            sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
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
                    sudo pacman -S --noconfirm cosmic-session cosmic-terminal cosmic-files cosmic-store cosmic-wallpapers xdg-desktop-portal-gtk
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
            
        almalinux)
            case "$desktop" in
                gnome)
                    sudo dnf install -y gnome-initial-setup gnome-software gnome-tweaks gnome-disk-utility ptyxis
                    sudo systemctl enable gdm
                    sudo systemctl set-default graphical.target
                    ;;
                kde)
                    sudo dnf install -y sddm plasma-desktop konsole dolphin
                    sudo systemctl enable sddm
                    sudo systemctl set-default graphical.target
                    ;;
                none)
                    echo "${YELLOW}Nenhum desktop instalado.${NC}"
                    ;;
            esac
            ;;
    esac
}

install_browser() {
    local browser=$(cat "$STATE_DIR/browser")
    local distro=$(cat "$STATE_DIR/distro")
    
    case "$distro" in
        debian)
            case "$browser" in
                zen)
                    flatpak install -y flathub app.zen_browser.zen
                    ;;
                helium)
                    curl -fsSL https://raw.githubusercontent.com/imputnet/helium-linux/main/pubkey.asc | sudo gpg --dearmor -o /usr/share/keyrings/helium.gpg
                    echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/helium.gpg] https://pkg.helium.computer/deb stable main" | sudo tee /etc/apt/sources.list.d/helium.list
                    sudo apt update
                    sudo apt install -y helium-bin
                    ;;
                firefox)
                    flatpak install -y flathub org.mozilla.firefox
                    ;;
                chrome)
                    flatpak install -y flathub com.google.Chrome
                    ;;
            esac
            ;;
            
        arch)
            case "$browser" in
                zen)
                    flatpak install -y flathub app.zen_browser.zen
                    ;;
                helium)
                    sudo pacman -S --noconfirm helium-browser-bin
                    ;;
                firefox)
                    flatpak install -y flathub org.mozilla.firefox
                    ;;
                chrome)
                    flatpak install -y flathub com.google.Chrome
                    ;;
            esac
            ;;
            
        almalinux)
            case "$browser" in
                zen)
                    flatpak install -y flathub app.zen_browser.zen
                    ;;
                firefox)
                    flatpak install -y flathub org.mozilla.firefox
                    ;;
                chrome)
                    flatpak install -y flathub com.google.Chrome
                    ;;
            esac
            ;;
    esac
}

install_office() {
    local office=$(cat "$STATE_DIR/office")
    
    if [[ "$office" == "none" ]]; then
        return
    fi
    
    echo "${CYAN}────────────────────────────────────────────────────────────────────${NC}"
    echo "${GREEN}► Instalando aplicativos Office${NC}"
    echo "${CYAN}────────────────────────────────────────────────────────────────────${NC}"
    
    for app in $office; do
        case "$app" in
            onlyoffice)
                flatpak install -y flathub org.onlyoffice.desktopeditors
                ;;
            gimp)
                flatpak install -y flathub org.gimp.GIMP
                ;;
            kdenlive)
                flatpak install -y flathub org.kde.kdenlive
                ;;
            obs)
                flatpak install -y flathub com.obsproject.Studio
                ;;
            obsidian)
                flatpak install -y flathub md.obsidian.Obsidian
                ;;
        esac
    done
    
    echo "${GREEN}✓ Aplicativos office instalados!${NC}"
    echo ""
}

install_games() {
    local games=$(cat "$STATE_DIR/games")
    
    if [[ "$games" == "none" ]]; then
        return
    fi
    
    echo "${CYAN}────────────────────────────────────────────────────────────────────${NC}"
    echo "${GREEN}► Instalando jogos e plataformas${NC}"
    echo "${CYAN}────────────────────────────────────────────────────────────────────${NC}"
    
    for app in $games; do
        case "$app" in
            steam)
                flatpak install -y flathub com.valvesoftware.Steam
                ;;
            proton)
                flatpak install -y flathub net.davidotek.pupgui2
                ;;
            prism)
                flatpak install -y flathub org.prismlauncher.PrismLauncher
                ;;
            sober)
                flatpak install -y flathub org.vinegarhq.Sober
                ;;
            faugus)
                flatpak install -y flathub io.github.Faugus.faugus-launcher
                ;;
        esac
    done
    
    echo "${GREEN}✓ Jogos e plataformas instalados!${NC}"
    echo ""
}

setup_network() {
    local distro=$(cat "$STATE_DIR/distro")
    
    if [[ "$distro" == "debian" ]]; then
        sudo sed -i '/^allow-hotplug /s/^/#/' /etc/network/interfaces
        sudo sed -i '/^iface .* inet /s/^/#/' /etc/network/interfaces
        sudo sed -i '/^iface .* inet6 /s/^/#/' /etc/network/interfaces
    else
        echo "${YELLOW}setup_network: Esta função é exclusiva para Debian. Pulando...${NC}"
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
    else
        echo "${YELLOW}setup_zram: Esta função é exclusiva para Debian. Pulando...${NC}"
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
            echo "${GREEN}Compressão BTRFS configurada para zstd${NC}"
        else
            echo "${YELLOW}Sistema sem BTRFS. Pulando compressão.${NC}"
        fi
    else
        echo "${YELLOW}setup_btrfs_compression: Esta função é exclusiva para Debian. Pulando...${NC}"
    fi
}

import_mok_key() {
    if ! command -v mokutil &>/dev/null; then
        echo "${YELLOW}mokutil não instalado. Pulando importação da chave MOK.${NC}"
        return
    fi
    
    if ! sudo mokutil --sb-state 2>/dev/null | grep -qi "SecureBoot enabled"; then
        echo "${YELLOW}Secure Boot não está ativo. Pulando importação da chave MOK.${NC}"
        return
    fi
    
    if [ ! -f /var/lib/dkms/mok.pub ]; then
        echo "${YELLOW}Arquivo /var/lib/dkms/mok.pub não encontrado. Pulando importação da chave MOK.${NC}"
        return
    fi
    
    if sudo mokutil --list-enrolled 2>/dev/null | grep -q "Debian Secure Boot"; then
        echo "${GREEN}Chave MOK já está enrollada no sistema. Pulando importação.${NC}"
        return
    fi
    
    echo "${YELLOW}Importando chave MOK para Secure Boot...${NC}"
    echo "${YELLOW}Digite uma senha (8-16 caracteres) quando solicitado.${NC}"
    sudo mokutil --import /var/lib/dkms/mok.pub
    echo "${GREEN}Chave MOK importada com sucesso!${NC}"
    echo "${YELLOW}Reinicie o sistema para concluir o enrollment da chave MOK.${NC}"
}

install_nvidia_debian() {
    echo "${YELLOW}Instalando drivers NVIDIA no Debian...${NC}"
    
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        local distro_name="${VERSION_CODENAME:-}"
        
        if [ -z "$distro_name" ]; then
            echo "${RED}Erro: Não foi possível detectar o codinome do Debian a partir do /etc/os-release${NC}"
            return 1
        fi
        
        echo "${YELLOW}Detectado Debian ${VERSION_ID} (${distro_name})${NC}"
        
        wget https://developer.download.nvidia.com/compute/cuda/repos/${distro_name}/x86_64/cuda-keyring_1.1-1_all.deb
        sudo dpkg -i cuda-keyring_1.1-1_all.deb
        sudo apt update
        sudo apt -y install nvidia-open
        rm -f cuda-keyring_1.1-1_all.deb
        
        echo "${GREEN}✓ Drivers NVIDIA instalados com sucesso!${NC}"
        
        import_mok_key
    else
        echo "${RED}Erro: Arquivo /etc/os-release não encontrado${NC}"
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
            
        almalinux)
            case "$gpu" in
                intel|amd)
                    sudo dnf install -y mesa-vulkan-drivers
                    ;;
                nvidia)
                    sudo dnf install -y almalinux-release-nvidia-driver
                    sudo dnf install -y nvidia-driver
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
        almalinux)
            sudo dnf install -y microcode_ctl
            ;;
    esac
}

setup_performance_vars() {
    sudo mkdir -p /etc/environment.d
    sudo tee /etc/environment.d/performance.conf > /dev/null <<EOF
MESA_SHADER_CACHE_MAX_SIZE=12G
__GL_SHADER_DISK_CACHE_SIZE=12000000000
EOF
}

remove_packages() {
    local distro=$(cat "$STATE_DIR/distro")
    
    if [[ "$distro" == "debian" ]]; then
        sudo apt remove -y nano wget vim-common
        sudo apt autoremove -y
    fi
}

ask_reboot() {
    echo ""
    echo "${GREEN}Instalação concluída com sucesso!${NC}"
    echo "${YELLOW}Recomenda-se reiniciar o sistema para aplicar todas as configurações.${NC}"
    if confirm "Deseja reiniciar agora?"; then
        echo "${GREEN}Reiniciando o sistema...${NC}"
        sudo reboot
    else
        echo "${YELLOW}Lembre-se de reiniciar o sistema posteriormente para aplicar todas as configurações.${NC}"
    fi
}

main() {
    detect_distro
    detect_gpu
    detect_cpu
    select_desktop
    select_browser
    select_office
    select_games
    setup_sources
    install_base
    setup_security
    install_cpu_microcode
    install_gpu_drivers
    install_desktop
    install_browser
    install_office
    install_games
    setup_network
    setup_zram
    setup_btrfs_compression
    setup_package_managers
    setup_performance_vars
    remove_packages
    ask_reboot
}

main
