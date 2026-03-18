#!/usr/bin/env bash
#
# ArduPilot SITL + Webots - Interactive Setup Script
# This script helps you set up all dependencies for the simulation.
#
# Features:
# - Auto-detects Linux distro and package manager
# - Interactive step-by-step installation
# - Idempotent (safe to run multiple times)
# - Choice between Podman (recommended) and Docker
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ============================================================================
# Helper Functions
# ============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
}

print_step() {
    echo -e "\n${CYAN}▶ Step $1: $2${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

ask_yes_no() {
    local prompt="$1"
    local default="${2:-y}"
    local response

    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi

    read -r -p "$prompt" response
    response=${response:-$default}

    [[ "$response" =~ ^[Yy]$ ]]
}

ask_run_command() {
    local cmd="$1"
    local description="$2"

    echo ""
    echo -e "${YELLOW}Command to run:${NC}"
    echo -e "  ${BOLD}$cmd${NC}"
    echo ""

    if ask_yes_no "Run this command?"; then
        echo ""
        eval "$cmd"
        return 0
    else
        print_warning "Skipped: $description"
        return 1
    fi
}

is_installed() {
    command -v "$1" &> /dev/null
}

# ============================================================================
# Sudo Check
# ============================================================================

check_sudo() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script requires sudo privileges for installing packages."
        echo ""
        echo "Please run with sudo:"
        echo -e "  ${BOLD}sudo $0${NC}"
        echo ""
        exit 1
    fi
    
    # Get the actual user (not root)
    if [[ -n "$SUDO_USER" ]]; then
        REAL_USER="$SUDO_USER"
        REAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    else
        REAL_USER="$USER"
        REAL_HOME="$HOME"
    fi
}

# ============================================================================
# Distro Detection
# ============================================================================

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO_ID="$ID"
        DISTRO_NAME="$NAME"
        DISTRO_VERSION="$VERSION_ID"
        DISTRO_PRETTY="$PRETTY_NAME"
    elif [[ -f /etc/lsb-release ]]; then
        . /etc/lsb-release
        DISTRO_ID="$DISTRIB_ID"
        DISTRO_NAME="$DISTRIB_ID"
        DISTRO_VERSION="$DISTRIB_RELEASE"
        DISTRO_PRETTY="$DISTRIB_DESCRIPTION"
    else
        DISTRO_ID="unknown"
        DISTRO_NAME="Unknown Linux"
        DISTRO_VERSION="unknown"
        DISTRO_PRETTY="Unknown Linux Distribution"
    fi

    # Normalize distro ID to lowercase
    DISTRO_ID=$(echo "$DISTRO_ID" | tr '[:upper:]' '[:lower:]')

    # Detect package manager based on distro
    case "$DISTRO_ID" in
        ubuntu|debian|linuxmint|pop|elementary|zorin)
            PKG_MANAGER="apt"
            PKG_UPDATE="apt update"
            PKG_INSTALL="apt install -y"
            DISTRO_FAMILY="debian"
            ;;
        fedora)
            PKG_MANAGER="dnf"
            PKG_UPDATE="dnf check-update || true"
            PKG_INSTALL="dnf install -y"
            DISTRO_FAMILY="fedora"
            ;;
        centos|rhel|rocky|almalinux)
            PKG_MANAGER="dnf"
            PKG_UPDATE="dnf check-update || true"
            PKG_INSTALL="dnf install -y"
            DISTRO_FAMILY="rhel"
            ;;
        arch|manjaro|endeavouros|cachyos)
            PKG_MANAGER="pacman"
            PKG_UPDATE="pacman -Sy"
            PKG_INSTALL="pacman -S --noconfirm"
            DISTRO_FAMILY="arch"
            ;;
        opensuse*|suse)
            PKG_MANAGER="zypper"
            PKG_UPDATE="zypper refresh"
            PKG_INSTALL="zypper install -y"
            DISTRO_FAMILY="suse"
            ;;
        *)
            # Unknown distro - try to detect package manager directly
            PKG_MANAGER="unknown"
            DISTRO_FAMILY="unknown"
            ;;
    esac

    # Fallback: detect package manager by checking installed commands
    if [[ "$PKG_MANAGER" == "unknown" ]]; then
        print_warning "Unknown distro '$DISTRO_ID' - detecting package manager..."
        
        if is_installed pacman; then
            PKG_MANAGER="pacman"
            PKG_UPDATE="pacman -Sy"
            PKG_INSTALL="pacman -S --noconfirm"
            DISTRO_FAMILY="arch"
            print_info "Detected pacman (Arch-based)"
        elif is_installed apt; then
            PKG_MANAGER="apt"
            PKG_UPDATE="apt update"
            PKG_INSTALL="apt install -y"
            DISTRO_FAMILY="debian"
            print_info "Detected apt (Debian-based)"
        elif is_installed dnf; then
            PKG_MANAGER="dnf"
            PKG_UPDATE="dnf check-update || true"
            PKG_INSTALL="dnf install -y"
            DISTRO_FAMILY="fedora"
            print_info "Detected dnf (Fedora/RHEL-based)"
        elif is_installed yum; then
            PKG_MANAGER="yum"
            PKG_UPDATE="yum check-update || true"
            PKG_INSTALL="yum install -y"
            DISTRO_FAMILY="rhel"
            print_info "Detected yum (RHEL-based)"
        elif is_installed zypper; then
            PKG_MANAGER="zypper"
            PKG_UPDATE="zypper refresh"
            PKG_INSTALL="zypper install -y"
            DISTRO_FAMILY="suse"
            print_info "Detected zypper (openSUSE-based)"
        fi
    fi
}

show_system_info() {
    print_header "System Information"
    echo ""
    echo -e "  ${BOLD}Distribution:${NC}    $DISTRO_PRETTY"
    echo -e "  ${BOLD}Distro ID:${NC}       $DISTRO_ID"
    echo -e "  ${BOLD}Version:${NC}         $DISTRO_VERSION"
    echo -e "  ${BOLD}Package Manager:${NC} $PKG_MANAGER"
    echo -e "  ${BOLD}Installing as:${NC}   $REAL_USER"
    echo ""

    if [[ "$PKG_MANAGER" == "unknown" ]]; then
        print_error "Could not detect package manager for your distribution."
        echo "Supported distributions: Ubuntu, Debian, Fedora, Arch, openSUSE, and derivatives."
        exit 1
    fi
}

# ============================================================================
# Installation Steps
# ============================================================================

show_installation_plan() {
    print_header "Installation Plan"
    echo ""
    echo "This script will guide you through the following steps:"
    echo ""
    echo -e "  ${CYAN}1.${NC} Update package lists"
    echo -e "  ${CYAN}2.${NC} Install Python 3 and pip"
    echo -e "  ${CYAN}3.${NC} Install container runtime (${BOLD}Podman${NC} recommended, or Docker)"
    echo -e "  ${CYAN}4.${NC} Install Webots R2025a (if not installed)"
    echo -e "  ${CYAN}5.${NC} Set up Python virtual environment"
    echo -e "  ${CYAN}6.${NC} Create environment configuration (.env)"
    echo ""
    echo -e "${YELLOW}Each step will show you the exact command before running.${NC}"
    echo ""

    if ! ask_yes_no "Continue with installation?"; then
        echo "Installation cancelled."
        exit 0
    fi
}

# Step 1: Update package lists
step_update_packages() {
    print_step "1" "Update package lists"

    ask_run_command "$PKG_UPDATE" "package list update"
}

# Step 2: Install Python
step_install_python() {
    print_step "2" "Install Python 3 and pip"

    if is_installed python3 && is_installed pip3; then
        print_success "Python 3 and pip are already installed"
        python3 --version
        return 0
    fi

    case "$DISTRO_FAMILY" in
        debian)
            ask_run_command "$PKG_INSTALL python3 python3-pip python3-venv" "Python installation"
            ;;
        fedora|rhel)
            ask_run_command "$PKG_INSTALL python3 python3-pip" "Python installation"
            ;;
        arch)
            ask_run_command "$PKG_INSTALL python python-pip" "Python installation"
            ;;
        suse)
            ask_run_command "$PKG_INSTALL python3 python3-pip" "Python installation"
            ;;
    esac
}

# Step 3: Install container runtime
step_install_containers() {
    print_step "3" "Install container runtime"

    # Check what's already installed
    local podman_installed=false
    local docker_installed=false

    if is_installed podman && is_installed podman-compose; then
        podman_installed=true
        print_success "Podman and podman-compose are already installed"
    fi

    if is_installed docker; then
        docker_installed=true
        print_success "Docker is already installed"
    fi

    if $podman_installed || $docker_installed; then
        if ask_yes_no "Container runtime already installed. Skip this step?" "y"; then
            return 0
        fi
    fi

    echo ""
    echo "Choose your container runtime:"
    echo ""
    echo -e "  ${GREEN}1)${NC} ${BOLD}Podman${NC} (recommended) - Daemonless, rootless containers"
    echo -e "  ${BLUE}2)${NC} ${BOLD}Docker${NC} - Traditional container runtime"
    echo ""

    local choice
    read -r -p "Enter choice [1/2] (default: 1): " choice
    choice=${choice:-1}

    case "$choice" in
        1)
            CONTAINER_RUNTIME="podman"
            install_podman
            ;;
        2)
            CONTAINER_RUNTIME="docker"
            install_docker
            ;;
        *)
            print_warning "Invalid choice, defaulting to Podman"
            CONTAINER_RUNTIME="podman"
            install_podman
            ;;
    esac
}

install_podman() {
    print_info "Installing Podman..."

    case "$DISTRO_FAMILY" in
        debian)
            ask_run_command "$PKG_INSTALL podman podman-compose" "Podman installation"
            ;;
        fedora|rhel)
            ask_run_command "$PKG_INSTALL podman podman-compose" "Podman installation"
            ;;
        arch)
            ask_run_command "$PKG_INSTALL podman podman-compose" "Podman installation"
            ;;
        suse)
            ask_run_command "$PKG_INSTALL podman podman-compose" "Podman installation"
            ;;
    esac

    if is_installed podman; then
        print_success "Podman installed successfully"
        podman --version
    fi
}

install_docker() {
    print_info "Installing Docker..."

    case "$DISTRO_FAMILY" in
        debian)
            # Install Docker from official repository for better compatibility
            echo ""
            print_info "Installing Docker from official Docker repository..."

            local cmds=(
                "$PKG_INSTALL ca-certificates curl gnupg"
            )

            for cmd in "${cmds[@]}"; do
                ask_run_command "$cmd" "Docker prerequisites"
            done

            # Add Docker GPG key and repo
            if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
                ask_run_command "install -m 0755 -d /etc/apt/keyrings && curl -fsSL https://download.docker.com/linux/$DISTRO_ID/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && chmod a+r /etc/apt/keyrings/docker.gpg" "Docker GPG key"
            fi

            if [[ ! -f /etc/apt/sources.list.d/docker.list ]]; then
                ask_run_command "echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$DISTRO_ID \$(. /etc/os-release && echo \$VERSION_CODENAME) stable\" | tee /etc/apt/sources.list.d/docker.list > /dev/null" "Docker repository"
                ask_run_command "apt update" "Update package lists"
            fi

            ask_run_command "$PKG_INSTALL docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin" "Docker installation"
            ;;
        fedora|rhel)
            ask_run_command "$PKG_INSTALL dnf-plugins-core" "Docker prerequisites"
            ask_run_command "dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo" "Docker repository"
            ask_run_command "$PKG_INSTALL docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin" "Docker installation"
            ;;
        arch)
            ask_run_command "$PKG_INSTALL docker docker-compose" "Docker installation"
            ;;
        suse)
            ask_run_command "$PKG_INSTALL docker docker-compose" "Docker installation"
            ;;
    esac

    # Add user to docker group
    if getent group docker > /dev/null 2>&1; then
        if ! groups "$REAL_USER" | grep -q docker; then
            ask_run_command "usermod -aG docker $REAL_USER" "Add user to docker group"
            print_warning "You'll need to log out and back in for docker group changes to take effect"
        fi
    fi

    # Start and enable docker service
    if is_installed systemctl; then
        ask_run_command "systemctl enable --now docker" "Enable Docker service"
    fi

    if is_installed docker; then
        print_success "Docker installed successfully"
        docker --version
    fi
}

# Step 4: Install Webots
step_install_webots() {
    print_step "4" "Install Webots R2025a"

    if is_installed webots; then
        print_success "Webots is already installed"
        webots --version 2>/dev/null || true
        if ask_yes_no "Skip Webots installation?" "y"; then
            return 0
        fi
    fi

    echo ""
    echo "Choose Webots installation method:"
    echo ""
    echo -e "  ${GREEN}1)${NC} ${BOLD}Snap${NC} (easiest, auto-updates)"
    echo -e "  ${BLUE}2)${NC} ${BOLD}.deb package${NC} (Debian/Ubuntu only)"
    echo -e "  ${CYAN}3)${NC} ${BOLD}Skip${NC} (install manually later)"
    echo ""

    local choice
    read -r -p "Enter choice [1/2/3] (default: 1): " choice
    choice=${choice:-1}

    case "$choice" in
        1)
            install_webots_snap
            ;;
        2)
            install_webots_deb
            ;;
        3)
            print_warning "Skipping Webots installation"
            echo "Please install Webots R2025a manually: https://cyberbotics.com/doc/guide/installation-procedure"
            ;;
    esac
}

install_webots_snap() {
    if ! is_installed snap; then
        print_warning "Snap is not installed. Installing snapd first..."
        case "$DISTRO_FAMILY" in
            debian)
                ask_run_command "$PKG_INSTALL snapd" "Snap installation"
                ;;
            fedora)
                ask_run_command "$PKG_INSTALL snapd" "Snap installation"
                ask_run_command "ln -sf /var/lib/snapd/snap /snap" "Create snap symlink"
                ;;
            arch)
                print_warning "For Arch, please install snapd from AUR or use the .deb method"
                return 1
                ;;
        esac
    fi

    ask_run_command "snap install webots" "Webots Snap installation"

    if snap list webots &>/dev/null; then
        print_success "Webots installed via Snap"
        WEBOTS_HOME="/snap/webots/current/usr/share/webots"
        WEBOTS_TMP_PATH="$REAL_HOME/snap/webots/common/tmp/webots"
    fi
}

install_webots_deb() {
    if [[ "$DISTRO_FAMILY" != "debian" ]]; then
        print_error ".deb installation only works on Debian/Ubuntu"
        return 1
    fi

    local deb_url="https://github.com/cyberbotics/webots/releases/download/R2025a/webots_2025a_amd64.deb"
    local deb_file="/tmp/webots_2025a_amd64.deb"

    if [[ ! -f "$deb_file" ]]; then
        ask_run_command "wget -O $deb_file $deb_url" "Download Webots"
    fi

    ask_run_command "$PKG_INSTALL $deb_file" "Install Webots .deb"

    if is_installed webots; then
        print_success "Webots installed from .deb"
        WEBOTS_HOME="/usr/local/webots"
        WEBOTS_TMP_PATH="/tmp/webots"
    fi
}

# Step 5: Set up Python virtual environment
step_setup_venv() {
    print_step "5" "Set up Python virtual environment"

    local project_dir
    project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local venv_dir="$project_dir/venv"

    if [[ -d "$venv_dir" ]]; then
        print_success "Virtual environment already exists at $venv_dir"
        if ask_yes_no "Skip virtual environment setup?" "y"; then
            return 0
        fi
    fi

    echo ""
    print_info "Creating virtual environment in: $venv_dir"

    # Run as the real user, not root
    ask_run_command "sudo -u $REAL_USER python3 -m venv $venv_dir" "Create virtual environment"

    if [[ -f "$project_dir/requirements.txt" ]]; then
        ask_run_command "sudo -u $REAL_USER $venv_dir/bin/pip install --upgrade pip" "Upgrade pip"
        ask_run_command "sudo -u $REAL_USER $venv_dir/bin/pip install -r $project_dir/requirements.txt" "Install Python dependencies"
    fi

    print_success "Virtual environment created"
}

# Step 6: Create .env file
step_create_env() {
    print_step "6" "Create environment configuration"

    local project_dir
    project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local env_file="$project_dir/.env"

    if [[ -f "$env_file" ]]; then
        print_success ".env file already exists"
        if ask_yes_no "Skip .env creation?" "y"; then
            return 0
        fi
    fi

    # Determine Webots paths based on installation
    if [[ -z "$WEBOTS_HOME" ]]; then
        if [[ -d "/snap/webots/current/usr/share/webots" ]]; then
            WEBOTS_HOME="/snap/webots/current/usr/share/webots"
            WEBOTS_TMP_PATH="$REAL_HOME/snap/webots/common/tmp/webots"
        elif [[ -d "/usr/local/webots" ]]; then
            WEBOTS_HOME="/usr/local/webots"
            WEBOTS_TMP_PATH="/tmp/webots"
        else
            WEBOTS_HOME="/usr/local/webots"
            WEBOTS_TMP_PATH="/tmp/webots"
        fi
    fi

    echo ""
    print_info "Creating .env with detected paths:"
    echo -e "  WEBOTS_HOME=$WEBOTS_HOME"
    echo -e "  WEBOTS_TMP_PATH=$WEBOTS_TMP_PATH"
    echo ""

    if ask_yes_no "Create .env with these values?"; then
        cat > "$env_file" << EOF
# ArduPilot SITL + Webots Environment Configuration
# Generated by setup.sh on $(date)

WEBOTS_HOME=$WEBOTS_HOME
WEBOTS_TMP_PATH=$WEBOTS_TMP_PATH
DISPLAY=:0
EOF
        chown "$REAL_USER:$(id -gn $REAL_USER)" "$env_file"
        print_success ".env file created"
    else
        print_warning "Skipped .env creation"
    fi
}

# ============================================================================
# Final Summary
# ============================================================================

show_summary() {
    print_header "Setup Complete!"
    echo ""
    echo "Installed components:"
    echo ""

    if is_installed python3; then
        echo -e "  ${GREEN}✓${NC} Python 3: $(python3 --version 2>&1)"
    fi

    if is_installed podman; then
        echo -e "  ${GREEN}✓${NC} Podman: $(podman --version 2>&1)"
    fi

    if is_installed docker; then
        echo -e "  ${GREEN}✓${NC} Docker: $(docker --version 2>&1)"
    fi

    if is_installed webots; then
        echo -e "  ${GREEN}✓${NC} Webots installed"
    fi

    local project_dir
    project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    if [[ -d "$project_dir/venv" ]]; then
        echo -e "  ${GREEN}✓${NC} Virtual environment: $project_dir/venv"
    fi

    if [[ -f "$project_dir/.env" ]]; then
        echo -e "  ${GREEN}✓${NC} Environment config: $project_dir/.env"
    fi

    echo ""
    echo -e "${BOLD}Next steps:${NC}"
    echo ""
    echo "  1. Start the simulation:"
    echo -e "     ${CYAN}./start.sh${NC}"
    echo ""
    echo "  2. Open Webots and load the world:"
    echo -e "     ${CYAN}webots Webots/worlds/iris_Task_2.wbt${NC}"
    echo ""
    echo "  3. Run the control script (in a new terminal):"
    echo -e "     ${CYAN}source venv/bin/activate${NC}"
    echo -e "     ${CYAN}python Task/flight.py${NC}"
    echo ""

    if [[ "${CONTAINER_RUNTIME:-}" == "docker" ]]; then
        print_warning "Note: You may need to log out and back in for Docker group permissions to take effect."
    fi
}

# ============================================================================
# Main
# ============================================================================

main() {
    print_header "ArduPilot SITL + Webots Setup"
    echo ""
    echo "This script will help you set up all dependencies for the simulation."
    echo ""

    check_sudo
    detect_distro
    show_system_info
    show_installation_plan

    step_update_packages
    step_install_python
    step_install_containers
    step_install_webots
    step_setup_venv
    step_create_env

    show_summary
}

main "$@"
