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

ask_extras() {
    clear_screen
    show_section "EXTRAS - SELEÇÃO INDIVIDUAL"
    echo "${YELLOW}Digite a soma dos números dos extras que deseja instalar:${NC}"
    echo ""
    echo "${CYAN}────────────────────────────────────────────────────────────────────${NC}"
    echo "  1) Snapd (Snap packages)"
    echo "  2) Pacstall (AUR-style package manager for Debian)"
    echo "  4) Waydroid (Container Android)"
    echo "  8) WinBoat (Windows emulator)"
    echo " 16) Yay (AUR helper for Arch)"
    echo ""
    echo "${CYAN}────────────────────────────────────────────────────────────────────${NC}"
    echo "${YELLOW}Exemplos:${NC}"
    echo "  - Apenas Yay: digite 16"
    echo "  - WinBoat + Yay: digite 24"
    echo "  - Todos: digite 31"
    echo "  - Nenhum: digite 0"
    echo ""
    read -p "Digite a soma das opções desejadas [0-31]: " extra_sum
    
    if [[ ! "$extra_sum" =~ ^[0-9]|[12][0-9]|3[01]$ ]]; then
        echo "${RED}Opção inválida. Digite um número entre 0 e 31.${NC}"
        sleep 2
        ask_extras
        return
    fi
    
    echo "$extra_sum" > "$STATE_DIR/extras_sum"
    
    echo ""
    echo "${GREEN}Opções selecionadas:${NC}"
    if [[ "$extra_sum" == "0" ]]; then
        echo "  ${YELLOW}Nenhum extra selecionado${NC}"
    else
        if [[ $((extra_sum & 1)) -ne 0 ]]; then
            echo "  ${GREEN}✓ Snapd${NC}"
        fi
        if [[ $((extra_sum & 2)) -ne 0 ]]; then
            echo "  ${GREEN}✓ Pacstall${NC}"
        fi
        if [[ $((extra_sum & 4)) -ne 0 ]]; then
            echo "  ${GREEN}✓ Waydroid${NC}"
        fi
        if [[ $((extra_sum & 8)) -ne 0 ]]; then
            echo "  ${GREEN}✓ WinBoat${NC}"
        fi
        if [[ $((extra_sum & 16)) -ne 0 ]]; then
            echo "  ${GREEN}✓ Yay${NC}"
        fi
    fi
    echo ""
    sleep 2
}

ask_productivity() {
    clear_screen
    show_section "PRODUTIVIDADE - SELEÇÃO INDIVIDUAL"
    echo "${YELLOW}Digite a soma dos números dos aplicativos que deseja instalar:${NC}"
    echo ""
    echo "${CYAN}────────────────────────────────────────────────────────────────────${NC}"
    echo "  1) OnlyOffice (Suite de escritório)"
    echo "  2) OBS Studio (Gravação/transmissão de tela)"
    echo "  4) Obsidian (Notas e conhecimento)"
    echo "  8) GIMP (Edição de imagens)"
    echo " 16) Audacity (Edição de áudio)"
    echo ""
    echo "${CYAN}────────────────────────────────────────────────────────────────────${NC}"
    echo "${YELLOW}Exemplos:${NC}"
    echo "  - Apenas OnlyOffice: digite 1"
    echo "  - OnlyOffice + OBS: digite 3"
    echo "  - GIMP + Audacity: digite 24"
    echo "  - Todos: digite 31"
    echo "  - Nenhum: digite 0"
    echo ""
    read -p "Digite a soma das opções desejadas [0-31]: " prod_sum
    
    if [[ ! "$prod_sum" =~ ^[0-9]|[12][0-9]|3[01]$ ]]; then
        echo "${RED}Opção inválida. Digite um número entre 0 e 31.${NC}"
        sleep 2
        ask_productivity
        return
    fi
    
    echo "$prod_sum" > "$STATE_DIR/productivity_sum"
    
    echo ""
    echo "${GREEN}Aplicativos selecionados:${NC}"
    if [[ "$prod_sum" == "0" ]]; then
        echo "  ${YELLOW}Nenhum aplicativo selecionado${NC}"
    else
        if [[ $((prod_sum & 1)) -ne 0 ]]; then
            echo "  ${GREEN}✓ OnlyOffice${NC}"
        fi
        if [[ $((prod_sum & 2)) -ne 0 ]]; then
            echo "  ${GREEN}✓ OBS Studio${NC}"
        fi
        if [[ $((prod_sum & 4)) -ne 0 ]]; then
            echo "  ${GREEN}✓ Obsidian${NC}"
        fi
        if [[ $((prod_sum & 8)) -ne 0 ]]; then
            echo "  ${GREEN}✓ GIMP${NC}"
        fi
        if [[ $((prod_sum & 16)) -ne 0 ]]; then
            echo "  ${GREEN}✓ Audacity${NC}"
        fi
    fi
    echo ""
    sleep 2
}

ask_games() {
    clear_screen
    show_section "GAMES - SELEÇÃO INDIVIDUAL"
    echo "${YELLOW}Digite a soma dos números dos jogos/launchers que deseja instalar:${NC}"
    echo ""
    echo "${CYAN}────────────────────────────────────────────────────────────────────${NC}"
    echo "  1) Hydra Launcher (Game launcher)"
    echo "  2) Sober (Roblox client)"
    echo "  4) Faugus Launcher (Wine/Proton games)"
    echo "  8) shadPS4 (PS4 emulator)"
    echo " 16) Ryujinx (Switch emulator)"
    echo ""
    echo "${CYAN}────────────────────────────────────────────────────────────────────${NC}"
    echo "${YELLOW}Exemplos:${NC}"
    echo "  - Apenas Hydra: digite 1"
    echo "  - Hydra + Sober: digite 3"
    echo "  - shadPS4 + Ryujinx: digite 24"
    echo "  - Todos: digite 31"
    echo "  - Nenhum: digite 0"
    echo ""
    read -p "Digite a soma das opções desejadas [0-31]: " games_sum
    
    if [[ ! "$games_sum" =~ ^[0-9]|[12][0-9]|3[01]$ ]]; then
        echo "${RED}Opção inválida. Digite um número entre 0 e 31.${NC}"
        sleep 2
        ask_games
        return
    fi
    
    echo "$games_sum" > "$STATE_DIR/games_sum"
    
    echo ""
    echo "${GREEN}Jogos/Launchers selecionados:${NC}"
    if [[ "$games_sum" == "0" ]]; then
        echo "  ${YELLOW}Nenhum jogo/launcher selecionado${NC}"
    else
        if [[ $((games_sum & 1)) -ne 0 ]]; then
            echo "  ${GREEN}✓ Hydra Launcher${NC}"
        fi
        if [[ $((games_sum & 2)) -ne 0 ]]; then
            echo "  ${GREEN}✓ Sober${NC}"
        fi
        if [[ $((games_sum & 4)) -ne 0 ]]; then
            echo "  ${GREEN}✓ Faugus Launcher${NC}"
        fi
        if [[ $((games_sum & 8)) -ne 0 ]]; then
            echo "  ${GREEN}✓ shadPS4${NC}"
        fi
        if [[ $((games_sum & 16)) -ne 0 ]]; then
            echo "  ${GREEN}✓ Ryujinx${NC}"
        fi
    fi
    echo ""
    sleep 2
}

ask_browser() {
    clear_screen
    show_section "BROWSERS - SELEÇÃO INDIVIDUAL"
    echo "${YELLOW}Digite a soma dos números dos browsers que deseja instalar:${NC}"
    echo ""
    echo "${CYAN}────────────────────────────────────────────────────────────────────${NC}"
    echo "  1) Zen Browser"
    echo "  2) Helium Browser"
    echo "  4) Firefox"
    echo "  8) Google Chrome"
    echo ""
    echo "${CYAN}────────────────────────────────────────────────────────────────────${NC}"
    echo "${YELLOW}Exemplos:${NC}"
    echo "  - Apenas Firefox: digite 4"
    echo "  - Firefox + Chrome: digite 12"
    echo "  - Zen + Helium: digite 3"
    echo "  - Todos: digite 15"
    echo "  - Nenhum: digite 0"
    echo ""
    read -p "Digite a soma das opções desejadas [0-15]: " browser_sum
    
    if [[ ! "$browser_sum" =~ ^[0-9]|1[0-5]$ ]]; then
        echo "${RED}Opção inválida. Digite um número entre 0 e 15.${NC}"
        sleep 2
        ask_browser
        return
    fi
    
    echo "$browser_sum" > "$STATE_DIR/browser_sum"
    
    echo ""
    echo "${GREEN}Browsers selecionados:${NC}"
    if [[ "$browser_sum" == "0" ]]; then
        echo "  ${YELLOW}Nenhum browser selecionado${NC}"
    else
        if [[ $((browser_sum & 1)) -ne 0 ]]; then
            echo "  ${GREEN}✓ Zen Browser${NC}"
        fi
        if [[ $((browser_sum & 2)) -ne 0 ]]; then
            echo "  ${GREEN}✓ Helium Browser${NC}"
        fi
        if [[ $((browser_sum & 4)) -ne 0 ]]; then
            echo "  ${GREEN}✓ Firefox${NC}"
        fi
        if [[ $((browser_sum & 8)) -ne 0 ]]; then
            echo "  ${GREEN}✓ Google Chrome${NC}"
        fi
    fi
    echo ""
    sleep 2
}

setup_sources() {
    local distro=$(cat "$STATE_DIR/distro")
    
    if [[ "$distro" == "debian" ]]; then
        if [ -f /etc/apt/sources.list ]; then
            sudo sed -i 's/\(main\)/\1 contrib non-free/g' /etc/apt/sources.list
        fi
        
        if [ -f /etc/apt/sources.list.d/debian.sources ]; then
            sudo sed -i '/^Components:/ s/\(main\)/\1 contrib non-free/' /etc/apt/sources.list.d/debian.sources
        fi
        
        sudo apt update
        sudo apt upgrade -y
    elif [[ "$distro" == "arch" ]]; then
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
    fi
}

install_base() {
    local distro=$(cat "$STATE_DIR/distro")
    
    if [[ "$distro" == "debian" ]]; then
        sudo apt install -y podman neovim gamemode fastfetch
    elif [[ "$distro" == "arch" ]]; then
        sudo pacman -S --noconfirm podman neovim fastfetch gamemode
    fi
}

setup_security() {
    local distro=$(cat "$STATE_DIR/distro")
    
    echo "${GREEN}Configurando ferramentas de segurança...${NC}"
    
    if [[ "$distro" == "debian" ]]; then
        sudo apt install -y ufw
        sudo systemctl enable ufw
        sudo systemctl start ufw
        sudo systemctl enable apparmor
        sudo systemctl start apparmor
    elif [[ "$distro" == "arch" ]]; then
        sudo pacman -S --noconfirm apparmor fwupd
        sudo systemctl enable ufw
        sudo systemctl start ufw
        sudo systemctl enable apparmor
        sudo systemctl start apparmor
        sudo systemctl enable fwupd
        sudo systemctl start fwupd
    fi
    
    echo "${GREEN}Ferramentas de segurança configuradas!${NC}"
}

setup_package_managers() {
    local desktop=$(cat "$STATE_DIR/desktop")
    local distro=$(cat "$STATE_DIR/distro")
    local extras_sum=$(cat "$STATE_DIR/extras_sum")
    local install_snapd=0
    local install_pacstall=0
    local install_yay=0
    
    if [[ $((extras_sum & 1)) -ne 0 ]]; then
        install_snapd=1
    fi
    if [[ $((extras_sum & 2)) -ne 0 ]]; then
        install_pacstall=1
    fi
    if [[ $((extras_sum & 16)) -ne 0 ]]; then
        install_yay=1
    fi
    
    if [[ "$distro" == "debian" ]]; then
        sudo apt install -y flatpak
        
        if [[ "$desktop" == "gnome" ]]; then
            sudo apt install -y gnome-software-plugin-flatpak
        elif [[ "$desktop" == "kde" ]]; then
            sudo apt install -y plasma-discover-backend-flatpak
        fi
        
        sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
        
        if [[ "$install_snapd" == "1" ]]; then
            sudo apt install -y snapd
            sudo systemctl enable snapd
            sudo systemctl start snapd
        fi
        
        if [[ "$install_pacstall" == "1" ]]; then
            sudo bash -c "$(curl -fsSL https://pacstall.dev/q/install)"
        fi
    elif [[ "$distro" == "arch" ]]; then
        sudo pacman -S --noconfirm flatpak
        
        if [[ "$install_yay" == "1" ]]; then
            sudo pacman -S --noconfirm yay
        fi
    fi
}

install_flatpak_base() {
    echo "${GREEN}Instalando Flatpak Base obrigatório...${NC}"
    flatpak install -y flathub com.valvesoftware.Steam
    flatpak install -y flathub com.vysp3r.ProtonPlus
    flatpak install -y flathub org.prismlauncher.PrismLauncher
    echo "${GREEN}Flatpak Base instalado com sucesso!${NC}"
}

install_waydroid() {
    local distro=$(cat "$STATE_DIR/distro")
    local extras_sum=$(cat "$STATE_DIR/extras_sum")
    local install_waydroid=0
    
    if [[ $((extras_sum & 4)) -ne 0 ]]; then
        install_waydroid=1
    fi
    
    if [[ "$install_waydroid" != "1" ]]; then
        return
    fi
    
    echo "${GREEN}Instalando Waydroid...${NC}"
    
    if [[ "$distro" == "debian" ]]; then
        sudo apt install -y waydroid
    elif [[ "$distro" == "arch" ]]; then
        sudo pacman -S --noconfirm waydroid
    fi
    
    echo "${GREEN}Waydroid instalado com sucesso!${NC}"
}

install_winboat() {
    local distro=$(cat "$STATE_DIR/distro")
    local extras_sum=$(cat "$STATE_DIR/extras_sum")
    local install_winboat=0
    
    if [[ $((extras_sum & 8)) -ne 0 ]]; then
        install_winboat=1
    fi
    
    if [[ "$install_winboat" != "1" ]]; then
        return
    fi
    
    echo "${GREEN}Instalando WinBoat...${NC}"
    
    if [[ "$distro" == "debian" ]]; then
        local latest_url=$(curl -s https://api.github.com/repos/winboat-org/winboat/releases/latest | grep "browser_download_url.*amd64.deb" | cut -d '"' -f 4)
        
        if [ -z "$latest_url" ]; then
            echo "${RED}Erro: Não foi possível encontrar a URL do pacote mais recente.${NC}"
            return 1
        fi
        
        local deb_file=$(basename "$latest_url")
        wget "$latest_url" -O "$deb_file"
        sudo dpkg -i "$deb_file"
        rm -f "$deb_file"
        
    elif [[ "$distro" == "arch" ]]; then
        sudo pacman -S --noconfirm winboat
    fi
    
    echo "${GREEN}WinBoat instalado com sucesso!${NC}"
}

install_productivity() {
    local prod_sum=$(cat "$STATE_DIR/productivity_sum")
    
    if [[ "$prod_sum" == "0" ]]; then
        return
    fi
    
    echo "${GREEN}Instalando aplicativos de produtividade...${NC}"
    
    if [[ $((prod_sum & 1)) -ne 0 ]]; then
        echo "Instalando OnlyOffice..."
        flatpak install -y flathub org.onlyoffice.desktopeditors
    fi
    
    if [[ $((prod_sum & 2)) -ne 0 ]]; then
        echo "Instalando OBS Studio..."
        flatpak install -y flathub com.obsproject.Studio
    fi
    
    if [[ $((prod_sum & 4)) -ne 0 ]]; then
        echo "Instalando Obsidian..."
        flatpak install -y flathub md.obsidian.Obsidian
    fi
    
    if [[ $((prod_sum & 8)) -ne 0 ]]; then
        echo "Instalando GIMP..."
        flatpak install -y flathub org.gimp.GIMP
    fi
    
    if [[ $((prod_sum & 16)) -ne 0 ]]; then
        echo "Instalando Audacity..."
        flatpak install -y flathub org.audacityteam.Audacity
    fi
    
    echo "${GREEN}Aplicativos de produtividade instalados com sucesso!${NC}"
}

install_games() {
    local games_sum=$(cat "$STATE_DIR/games_sum")
    
    if [[ "$games_sum" == "0" ]]; then
        return
    fi
    
    echo "${GREEN}Instalando jogos e launchers...${NC}"
    
    if [[ $((games_sum & 1)) -ne 0 ]]; then
        echo "Instalando Hydra Launcher..."
        curl -fsSL https://hydra.la/install.sh | bash
    fi
    
    if [[ $((games_sum & 2)) -ne 0 ]]; then
        echo "Instalando Sober..."
        flatpak install -y flathub org.vinegarhq.Sober
    fi
    
    if [[ $((games_sum & 4)) -ne 0 ]]; then
        echo "Instalando Faugus Launcher..."
        flatpak install -y flathub io.github.Faugus.faugus-launcher
    fi
    
    if [[ $((games_sum & 8)) -ne 0 ]]; then
        echo "Instalando shadPS4..."
        flatpak install -y flathub net.shadps4.shadPS4
    fi
    
    if [[ $((games_sum & 16)) -ne 0 ]]; then
        echo "Instalando Ryujinx..."
        flatpak install -y flathub io.github.ryubing.Ryujinx
    fi
    
    echo "${GREEN}Jogos e launchers instalados com sucesso!${NC}"
}

install_browsers() {
    local browser_sum=$(cat "$STATE_DIR/browser_sum")
    
    if [[ "$browser_sum" == "0" ]]; then
        return
    fi
    
    echo "${GREEN}Instalando browsers...${NC}"
    
    if [[ $((browser_sum & 1)) -ne 0 ]]; then
        echo "Instalando Zen Browser..."
        flatpak install -y flathub app.zen_browser.zen
    fi
    
    if [[ $((browser_sum & 2)) -ne 0 ]]; then
        echo "Instalando Helium Browser..."
        local distro=$(cat "$STATE_DIR/distro")
        if [[ "$distro" == "debian" ]]; then
            curl -fsSL https://raw.githubusercontent.com/imputnet/helium-linux/main/pubkey.asc | sudo gpg --dearmor -o /usr/share/keyrings/helium.gpg
            echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/helium.gpg] https://pkg.helium.computer/deb stable main" | sudo tee /etc/apt/sources.list.d/helium.list
            sudo apt update
            sudo apt install -y helium-bin
        elif [[ "$distro" == "arch" ]]; then
            sudo pacman -S --noconfirm helium-browser-bin
        fi
    fi
    
    if [[ $((browser_sum & 4)) -ne 0 ]]; then
        echo "Instalando Firefox..."
        flatpak install -y flathub org.mozilla.firefox
    fi
    
    if [[ $((browser_sum & 8)) -ne 0 ]]; then
        echo "Instalando Google Chrome..."
        flatpak install -y flathub com.google.Chrome
    fi
    
    echo "${GREEN}Browsers instalados com sucesso!${NC}"
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
    fi
}

setup_btrfs_compression() {
    if mount | grep -q "btrfs"; then
        sudo sed -i '/btrfs.*compress,/s/compress,/compress=zstd,/g' /etc/fstab
        sudo sed -i '/btrfs.*compress[^=]/s/compress/compress=zstd/g' /etc/fstab
        sudo sed -i '/btrfs.*compress=zlib/s/compress=zlib/compress=zstd/g' /etc/fstab
        sudo mount -o remount /
        echo "${GREEN}Compressão BTRFS configurada para zstd${NC}"
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

install_gpu_drivers() {
    local gpu=$(cat "$STATE_DIR/gpu_driver")
    local distro=$(cat "$STATE_DIR/distro")
    
    if [[ "$distro" == "debian" ]]; then
        case "$gpu" in
            "intel"|"amd")
                sudo apt install -y mesa-vulkan-drivers
                ;;
            "nvidia")
                sudo apt install -y linux-headers-amd64
                wget https://developer.download.nvidia.com/compute/cuda/repos/debian13/x86_64/cuda-keyring_1.1-1_all.deb
                sudo dpkg -i cuda-keyring_1.1-1_all.deb
                sudo apt update
                sudo apt -y install nvidia-open
                rm -f cuda-keyring_1.1-1_all.deb
                import_mok_key
                ;;
        esac
    elif [[ "$distro" == "arch" ]]; then
        case "$gpu" in
            "intel")
                sudo pacman -S --noconfirm vulkan-intel
                ;;
            "amd")
                sudo pacman -S --noconfirm vulkan-radeon
                ;;
            "nvidia")
                sudo pacman -S --noconfirm nvidia-open
                ;;
        esac
    fi
}

install_cpu_microcode() {
    local cpu=$(cat "$STATE_DIR/cpu")
    local distro=$(cat "$STATE_DIR/distro")
    
    if [[ "$distro" == "debian" ]]; then
        case "$cpu" in
            "intel")
                sudo apt install -y intel-microcode
                ;;
            "amd")
                sudo apt install -y amd64-microcode
                ;;
        esac
    elif [[ "$distro" == "arch" ]]; then
        case "$cpu" in
            "intel")
                sudo pacman -S --noconfirm intel-ucode
                ;;
            "amd")
                sudo pacman -S --noconfirm amd-ucode
                ;;
        esac
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

install_desktop() {
    local desktop=$(cat "$STATE_DIR/desktop")
    local distro=$(cat "$STATE_DIR/distro")
    
    if [[ "$distro" == "debian" ]]; then
        case "$desktop" in
            "gnome")
                sudo apt install -y gdm3 gnome-initial-setup gnome-console gnome-software gnome-tweaks gnome-disk-utility gnome-backgrounds
                sudo systemctl enable gdm3
                ;;
            "kde")
                sudo apt install -y sddm plasma-desktop plasma-workspace-wallpapers konsole dolphin discover kdeconnect partitionmanager ark
                sudo systemctl enable sddm
                ;;
            "none")
                echo "${YELLOW}Nenhum desktop instalado.${NC}"
                ;;
        esac
    elif [[ "$distro" == "arch" ]]; then
        case "$desktop" in
            "gnome")
                sudo pacman -S --noconfirm gnome-initial-setup gnome-console gnome-software gnome-tweaks gnome-disk-utility gnome-backgrounds
                sudo systemctl enable gdm
                ;;
            "kde")
                sudo pacman -S --noconfirm plasma-meta konsole dolphin kdeconnect partitionmanager ark
                sudo systemctl enable plasmalogin
                ;;
            "cosmic")
                sudo pacman -S --noconfirm cosmic-session cosmic-terminal cosmic-files cosmic-store cosmic-wallpapers
                sudo systemctl enable cosmic-greeter
                ;;
            "dank")
                curl -fsSL https://install.danklinux.com | sh
                ;;
            "none")
                echo "${YELLOW}Nenhum desktop instalado.${NC}"
                ;;
        esac
    fi
}

setup_network() {
    local distro=$(cat "$STATE_DIR/distro")
    
    if [[ "$distro" == "debian" ]]; then
        sudo sed -i '/^allow-hotplug /s/^/#/' /etc/network/interfaces
        sudo sed -i '/^iface .* inet /s/^/#/' /etc/network/interfaces
        sudo sed -i '/^iface .* inet6 /s/^/#/' /etc/network/interfaces
    fi
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
    ask_extras
    ask_productivity
    ask_games
    ask_browser
    setup_sources
    install_base
    setup_security
    install_cpu_microcode
    install_gpu_drivers
    install_desktop
    setup_network
    setup_zram
    setup_btrfs_compression
    setup_package_managers
    install_flatpak_base
    install_waydroid
    install_winboat
    install_productivity
    install_games
    install_browsers
    setup_performance_vars
    remove_packages
    ask_reboot
}

main
