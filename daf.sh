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

select_desktop() {
    clear_screen
    show_section "AMBIENTE DESKTOP / DESKTOP ENVIRONMENT"
    
    local distro=$(cat "$STATE_DIR/distro")
    
    if [[ "$distro" == "debian" ]]; then
        show_option "1" "GNOME"
        show_option "2" "KDE Plasma"
        show_option "3" "Nenhum"
        echo ""
        read -p "Opção [1-3] (Enter para GNOME): " de_opt
        
        case "$de_opt" in
            1|"") echo "gnome" > "$STATE_DIR/desktop"
                 echo "${GREEN}Desktop: GNOME${NC}" ;;
            2) echo "kde" > "$STATE_DIR/desktop"
               echo "${GREEN}Desktop: KDE Plasma${NC}" ;;
            3) echo "none" > "$STATE_DIR/desktop"
               echo "${GREEN}Desktop: Nenhum${NC}" ;;
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
    echo "  Selecione os aplicativos que deseja instalar (escolha múltiplos):"
    echo ""
    show_option "1" "OnlyOffice (Suite de escritório)"
    show_option "2" "Obsidian (Notas/Knowledge base)"
    show_option "3" "VSCodium (Editor de código)"
    show_option "4" "Zen Browser (Navegador)"
    show_option "5" "Helium Browser"
    echo ""
    echo "  Digite os números separados por espaço (ex: 1 3 5) ou Enter para nenhum:"
    read -p "Opções: " -a prod_opts
    
    if [[ ${#prod_opts[@]} -eq 0 ]]; then
        echo "none" > "$STATE_DIR/produtividade"
        echo "${GREEN}Nenhum aplicativo de produtividade selecionado.${NC}"
    else
        local prod_list=""
        for opt in "${prod_opts[@]}"; do
            case "$opt" in
                1) prod_list="${prod_list} onlyoffice" ;;
                2) prod_list="${prod_list} obsidian" ;;
                3) prod_list="${prod_list} codium" ;;
                4) prod_list="${prod_list} zen" ;;
                5) prod_list="${prod_list} helium" ;;
                *) echo "${RED}Opção inválida: $opt${NC}" ;;
            esac
        done
        echo "$prod_list" > "$STATE_DIR/produtividade"
        echo "${GREEN}Aplicativo(s) de produtividade selecionado(s)!${NC}"
    fi
    sleep 1
}

select_multimidia() {
    clear_screen
    show_section "MULTIMÍDIA"
    echo "  Selecione os aplicativos que deseja instalar (escolha múltiplos):"
    echo ""
    show_option "1" "GIMP (Editor de imagens)"
    show_option "2" "Kdenlive (Editor de vídeo)"
    show_option "3" "OBS Studio (Gravação/Streaming)"
    show_option "4" "Upscayl (Upscaling de imagens com IA)"
    show_option "5" "HandBrake (Conversor de vídeos)"
    show_option "6" "Audacity (Editor de áudio)"
    echo ""
    echo "  Digite os números separados por espaço (ex: 1 3 5) ou Enter para nenhum:"
    read -p "Opções: " -a multi_opts
    
    if [[ ${#multi_opts[@]} -eq 0 ]]; then
        echo "none" > "$STATE_DIR/multimidia"
        echo "${GREEN}Nenhum aplicativo multimídia selecionado.${NC}"
    else
        local multi_list=""
        for opt in "${multi_opts[@]}"; do
            case "$opt" in
                1) multi_list="${multi_list} gimp" ;;
                2) multi_list="${multi_list} kdenlive" ;;
                3) multi_list="${multi_list} obs" ;;
                4) multi_list="${multi_list} upscayl" ;;
                5) multi_list="${multi_list} handbrake" ;;
                6) multi_list="${multi_list} audacity" ;;
                *) echo "${RED}Opção inválida: $opt${NC}" ;;
            esac
        done
        echo "$multi_list" > "$STATE_DIR/multimidia"
        echo "${GREEN}Aplicativo(s) multimídia selecionado(s)!${NC}"
    fi
    sleep 1
}

select_games() {
    clear_screen
    show_section "JOGOS"
    echo "  Selecione os jogos/plataformas que deseja instalar (escolha múltiplos):"
    echo ""
    show_option "1" "Steam"
    show_option "2" "Proton Plus"
    show_option "3" "Prism Launcher (Minecraft)"
    show_option "4" "Sober (Roblox)"
    show_option "5" "Heroic Games Launcher"
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
                5) games_list="${games_list} heroic" ;;
                *) echo "${RED}Opção inválida: $opt${NC}" ;;
            esac
        done
        echo "$games_list" > "$STATE_DIR/games"
        echo "${GREEN}Jogo(s) selecionado(s)!${NC}"
    fi
    sleep 1
}

select_extras() {
    clear_screen
    show_section "EXTRAS"
    echo "  Selecione os aplicativos extras que deseja instalar (escolha múltiplos):"
    echo ""
    show_option "1" "GPU Viewer (Monitoramento de GPU)"
    show_option "2" "BoxBuddyRS (Gerenciador de box)"
    show_option "3" "CPU-X (Informações da CPU)"
    show_option "4" "Chatterino (Chat para Twitch)"
    show_option "5" "Alpaca (Cliente para LLMs)"
    echo ""
    echo "  Digite os números separados por espaço (ex: 1 3) ou Enter para nenhum:"
    read -p "Opções: " -a extras_opts
    
    if [[ ${#extras_opts[@]} -eq 0 ]]; then
        echo "none" > "$STATE_DIR/extras"
        echo "${GREEN}Nenhum aplicativo extra selecionado.${NC}"
    else
        local extras_list=""
        for opt in "${extras_opts[@]}"; do
            case "$opt" in
                1) extras_list="${extras_list} gpuviewer" ;;
                2) extras_list="${extras_list} boxbuddy" ;;
                3) extras_list="${extras_list} cpux" ;;
                4) extras_list="${extras_list} chatterino" ;;
                5) extras_list="${extras_list} alpaca" ;;
                *) echo "${RED}Opção inválida: $opt${NC}" ;;
            esac
        done
        echo "$extras_list" > "$STATE_DIR/extras"
        echo "${GREEN}Aplicativo(s) extra(s) selecionado(s)!${NC}"
    fi
    sleep 1
}

select_ferramentas() {
    clear_screen
    show_section "FERRAMENTAS"
    echo "  Selecione as ferramentas que deseja instalar (escolha múltiplos):"
    echo ""
    show_option "1" "Yay (AUR helper - Arch)"
    show_option "2" "Snap (Universal package manager - Debian)"
    show_option "3" "Pacstall (AUR-like for Debian)"
    show_option "4" "Gamescope (Micro-compositor para jogos)"
    echo ""
    echo "  Digite os números separados por espaço (ex: 1 3) ou Enter para nenhum:"
    read -p "Opções: " -a ferramentas_opts
    
    if [[ ${#ferramentas_opts[@]} -eq 0 ]]; then
        echo "none" > "$STATE_DIR/ferramentas"
        echo "${GREEN}Nenhuma ferramenta selecionada.${NC}"
    else
        local ferramentas_list=""
        for opt in "${ferramentas_opts[@]}"; do
            case "$opt" in
                1) ferramentas_list="${ferramentas_list} yay" ;;
                2) ferramentas_list="${ferramentas_list} snap" ;;
                3) ferramentas_list="${ferramentas_list} pacstall" ;;
                4) ferramentas_list="${ferramentas_list} gamescope" ;;
                *) echo "${RED}Opção inválida: $opt${NC}" ;;
            esac
        done
        echo "$ferramentas_list" > "$STATE_DIR/ferramentas"
        echo "${GREEN}Ferramenta(s) selecionada(s)!${NC}"
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
    esac
}

install_base() {
    local distro=$(cat "$STATE_DIR/distro")
    
    case "$distro" in
        debian)
            sudo apt install -y podman distrobox git neovim gamemode fastfetch lshw
            ;;
        arch)
            sudo pacman -S --noconfirm podman distrobox git neovim fastfetch gamemode lshw
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
            
            flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
            ;;
        arch)
            sudo pacman -S --noconfirm flatpak
            flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
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
    esac
}

install_produtividade() {
    local prod=$(cat "$STATE_DIR/produtividade")
    
    if [[ "$prod" == "none" ]]; then
        return
    fi
    
    echo "${CYAN}────────────────────────────────────────────────────────────────────${NC}"
    echo "${GREEN}► Instalando aplicativos de Produtividade${NC}"
    echo "${CYAN}────────────────────────────────────────────────────────────────────${NC}"
    
    for app in $prod; do
        case "$app" in
            onlyoffice)
                flatpak install --user -y flathub org.onlyoffice.desktopeditors
                ;;
            obsidian)
                flatpak install --user -y flathub md.obsidian.Obsidian
                ;;
            codium)
                flatpak install --user -y flathub com.vscodium.codium
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
        esac
    done
    
    echo "${GREEN}✓ Aplicativos de produtividade instalados!${NC}"
    echo ""
}

install_multimidia() {
    local multi=$(cat "$STATE_DIR/multimidia")
    
    if [[ "$multi" == "none" ]]; then
        return
    fi
    
    echo "${CYAN}────────────────────────────────────────────────────────────────────${NC}"
    echo "${GREEN}► Instalando aplicativos Multimídia${NC}"
    echo "${CYAN}────────────────────────────────────────────────────────────────────${NC}"
    
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
            upscayl)
                flatpak install --user -y flathub org.upscayl.Upscayl
                ;;
            handbrake)
                flatpak install --user -y flathub fr.handbrake.ghb
                ;;
            audacity)
                flatpak install --user -y flathub org.audacityteam.Audacity
                ;;
        esac
    done
    
    echo "${GREEN}✓ Aplicativos multimídia instalados!${NC}"
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
    
    echo "${GREEN}✓ Jogos e plataformas instalados!${NC}"
    echo ""
}

install_extras() {
    local extras=$(cat "$STATE_DIR/extras")
    
    if [[ "$extras" == "none" ]]; then
        return
    fi
    
    echo "${CYAN}────────────────────────────────────────────────────────────────────${NC}"
    echo "${GREEN}► Instalando aplicativos Extras${NC}"
    echo "${CYAN}────────────────────────────────────────────────────────────────────${NC}"
    
    for app in $extras; do
        case "$app" in
            gpuviewer)
                flatpak install --user -y flathub io.github.arunsivaramanneo.GPUViewer
                ;;
            boxbuddy)
                flatpak install --user -y flathub io.github.dvlv.boxbuddyrs
                ;;
            cpux)
                flatpak install --user -y flathub io.github.thetumultuousunicornofdarkness.cpu-x
                ;;
            chatterino)
                flatpak install --user -y flathub com.chatterino.chatterino
                ;;
            alpaca)
                flatpak install --user -y flathub com.jeffser.Alpaca
                ;;
        esac
    done
    
    echo "${GREEN}✓ Aplicativos extras instalados!${NC}"
    echo ""
}

install_ferramentas() {
    local ferramentas=$(cat "$STATE_DIR/ferramentas")
    local distro=$(cat "$STATE_DIR/distro")
    
    if [[ "$ferramentas" == "none" ]]; then
        return
    fi
    
    echo "${CYAN}────────────────────────────────────────────────────────────────────${NC}"
    echo "${GREEN}► Instalando ferramentas${NC}"
    echo "${CYAN}────────────────────────────────────────────────────────────────────${NC}"
    
    for tool in $ferramentas; do
        case "$tool" in
            yay)
                if [[ "$distro" == "arch" ]]; then
                    echo "${YELLOW}Instalando Yay (AUR helper)...${NC}"
                    sudo pacman -S --noconfirm yay
                    echo "${GREEN}✓ Yay instalado!${NC}"
                else
                    echo "${YELLOW}⚠ Yay é exclusivo para Arch Linux. Pulando...${NC}"
                fi
                ;;
            snap)
                if [[ "$distro" == "debian" ]]; then
                    echo "${YELLOW}Instalando Snap...${NC}"
                    sudo apt install -y snapd
                    sudo systemctl enable snapd
                    sudo systemctl start snapd
                    echo "${GREEN}✓ Snap instalado!${NC}"
                else
                    echo "${YELLOW}⚠ Snap está disponível apenas para Debian. Pulando...${NC}"
                fi
                ;;
            pacstall)
                if [[ "$distro" == "debian" ]]; then
                    echo "${YELLOW}Instalando Pacstall...${NC}"
                    sudo bash -c "$(curl -fsSL https://pacstall.dev/q/install)"
                    echo "${GREEN}✓ Pacstall instalado!${NC}"
                else
                    echo "${YELLOW}⚠ Pacstall é exclusivo para Debian. Pulando...${NC}"
                fi
                ;;
            gamescope)
                if [[ "$distro" == "arch" ]]; then
                    echo "${YELLOW}Instalando Gamescope...${NC}"
                    sudo pacman -S --noconfirm gamescope
                    echo "${GREEN}✓ Gamescope instalado!${NC}"
                else
                    echo "${YELLOW}⚠ Gamescope está disponível apenas para Arch Linux. Pulando...${NC}"
                fi
                ;;
        esac
    done
    
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
        local debian_version="${VERSION_ID:-}"
        
        if [ -z "$debian_version" ]; then
            echo "${RED}Erro: Não foi possível detectar a versão do Debian a partir do /etc/os-release${NC}"
            return 1
        fi
        
        echo "${YELLOW}Detectado Debian ${debian_version}${NC}"
        
        wget https://developer.download.nvidia.com/compute/cuda/repos/debian${debian_version}/x86_64/cuda-keyring_1.1-1_all.deb
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
    echo "${GREEN}Instalação concluída com sucesso
