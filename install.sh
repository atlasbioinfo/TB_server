#!/bin/bash
#
# TermBuddy Server 一键安装脚本
#
# 使用方法：
#   curl -fsSL https://raw.githubusercontent.com/atlasbioinfo/TB_server/main/install.sh | bash
#   或
#   wget -qO- https://raw.githubusercontent.com/atlasbioinfo/TB_server/main/install.sh | bash
#
# 可选环境变量：
#   TERMBUDDY_INSTALL_DIR  安装目录（默认：~/.termbuddy）
#   TERMBUDDY_PORT         端口号（默认：8765）
#

set -e

# 配置
INSTALL_DIR="${TERMBUDDY_INSTALL_DIR:-$HOME/.termbuddy}"
PORT="${TERMBUDDY_PORT:-8765}"
REPO="atlasbioinfo/TB_server"
RELEASE_URL="https://github.com/${REPO}/releases/latest/download"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# 检测平台
detect_platform() {
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)

    case "$ARCH" in
        x86_64|amd64)  ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        *) error "Unsupported architecture: $ARCH" ;;
    esac

    case "$OS" in
        linux)  OS="linux" ;;
        darwin) OS="darwin" ;;
        *) error "Unsupported OS: $OS" ;;
    esac

    BINARY_NAME="tb_server-${OS}-${ARCH}"
    info "Detected platform: $OS/$ARCH"
}

# 下载文件
download() {
    local url="$1"
    local output="$2"

    local dir=$(dirname "$output")
    if [ ! -w "$dir" ]; then
        error "Directory not writable: $dir"
    fi

    # Check disk space (need at least 50MB)
    local available=$(df -m "$dir" 2>/dev/null | awk 'NR==2 {print $4}')
    if [ -n "$available" ] && [ "$available" -lt 50 ]; then
        error "Insufficient disk space: ${available}MB available, need 50MB"
    fi

    if command -v curl &> /dev/null; then
        curl -L --progress-bar --fail "$url" -o "$output"
    elif command -v wget &> /dev/null; then
        wget --progress=bar:force "$url" -O "$output"
    else
        error "curl or wget required"
    fi
}

# Install
install_termbuddy() {
    info "Creating install directory: $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"

    local download_url="${RELEASE_URL}/${BINARY_NAME}"
    info "Downloading TermBuddy Server (latest)..."
    info "  From: $download_url"

    if ! download "$download_url" "$INSTALL_DIR/tb_server"; then
        error "Download failed. Check network or visit https://github.com/${REPO}/releases"
    fi

    chmod +x "$INSTALL_DIR/tb_server"
    success "Download complete"
}

# Initialize config
init_config() {
    cd "$INSTALL_DIR"

    if [ -f "config.yaml" ]; then
        warn "Config already exists, skipping init"
        return
    fi

    info "Initializing config..."
    ./tb_server init --non-interactive

    if [ "$PORT" != "8765" ]; then
        info "Setting port to $PORT..."
        if [ "$OS" = "darwin" ]; then
            sed -i '' "s/port: 8765/port: $PORT/" config.yaml
        else
            sed -i "s/port: 8765/port: $PORT/" config.yaml
        fi
    fi

    success "Config initialized"
}

# 获取 Token
get_token() {
    if [ -f "$INSTALL_DIR/config.yaml" ]; then
        TOKEN=$(grep -E "^\s*token:" "$INSTALL_DIR/config.yaml" | head -1 | awk '{print $2}' | tr -d '"')
    fi
}

# Setup PATH
setup_path() {
    local path_line="export PATH=\"\$HOME/.termbuddy:\$PATH\""

    # Detect shell config file
    SHELL_RC=""
    if [ -n "$ZSH_VERSION" ] || [ "$SHELL" = "/bin/zsh" ] || [ "$SHELL" = "/usr/bin/zsh" ]; then
        SHELL_RC="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ] || [ "$SHELL" = "/bin/bash" ] || [ "$SHELL" = "/usr/bin/bash" ]; then
        if [ -f "$HOME/.bashrc" ]; then
            SHELL_RC="$HOME/.bashrc"
        else
            SHELL_RC="$HOME/.bash_profile"
        fi
    else
        SHELL_RC="$HOME/.profile"
    fi

    # Check if already added
    if grep -q "\.termbuddy" "$SHELL_RC" 2>/dev/null; then
        info "PATH already configured in $SHELL_RC"
        return
    fi

    # Add to config file
    echo "" >> "$SHELL_RC"
    echo "# TermBuddy Server" >> "$SHELL_RC"
    echo "$path_line" >> "$SHELL_RC"

    success "Added PATH to $SHELL_RC"
}

# Print summary
print_summary() {
    get_token

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}  TermBuddy Server installed and running!${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  Install dir: $INSTALL_DIR"
    echo "  Port:        $PORT"
    echo "  Status:      Running in background"
    if [ -n "$TOKEN" ]; then
        echo ""
        echo -e "  ${YELLOW}Auth Token (save this):${NC}"
        echo "  $TOKEN"
    fi
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Connect from iOS TermBuddy app"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  1. Add server with SSH credentials"
    echo "  2. Enter the Token shown above"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Useful commands"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  Check status:  pgrep -f 'tb_server serve'"
    echo "  View logs:     tail -f ~/.termbuddy/tb_server.log"
    echo "  Stop server:   pkill -f 'tb_server serve'"
    echo "  Restart:       pkill -f 'tb_server serve' && tb_server serve &"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# 检测已安装
check_existing() {
    if [ -f "$INSTALL_DIR/tb_server" ]; then
        echo ""
        warn "TermBuddy Server is already installed at $INSTALL_DIR"
        echo ""
        echo "  1) Upgrade   - Update binary only, keep config"
        echo "  2) Reinstall - Remove everything and start fresh"
        echo "  3) Cancel    - Exit without changes"
        echo ""
        printf "Choose [1/2/3]: "
        read -r choice < /dev/tty

        case "$choice" in
            1)
                info "Upgrading..."
                UPGRADE_MODE=true
                ;;
            2)
                info "Reinstalling..."
                rm -rf "$INSTALL_DIR"
                UPGRADE_MODE=false
                ;;
            3|"")
                info "Cancelled."
                exit 0
                ;;
            *)
                error "Invalid choice"
                ;;
        esac
    else
        UPGRADE_MODE=false
    fi
}

# Start server in background
start_server() {
    cd "$INSTALL_DIR"

    # Check if already running
    if pgrep -f "tb_server serve" > /dev/null 2>&1; then
        warn "Server is already running"
        return
    fi

    info "Starting server in background..."
    nohup ./tb_server serve > tb_server.log 2>&1 &

    # Wait a moment and check if it started
    sleep 1
    if pgrep -f "tb_server serve" > /dev/null 2>&1; then
        success "Server started (PID: $(pgrep -f 'tb_server serve'))"
        info "Log file: $INSTALL_DIR/tb_server.log"
    else
        error "Failed to start server. Check $INSTALL_DIR/tb_server.log"
    fi
}

# 主流程
main() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "       TermBuddy Server Installer"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    detect_platform
    check_existing
    install_termbuddy

    if [ "$UPGRADE_MODE" = false ]; then
        init_config
    else
        success "Binary upgraded. Config preserved."
    fi

    setup_path
    start_server
    print_summary
}

main "$@"
