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
        *) error "不支持的架构: $ARCH" ;;
    esac

    case "$OS" in
        linux)  OS="linux" ;;
        darwin) OS="darwin" ;;
        *) error "不支持的操作系统: $OS" ;;
    esac

    BINARY_NAME="tb_server-${OS}-${ARCH}"
    info "检测到平台: $OS/$ARCH"
}

# 下载文件
download() {
    local url="$1"
    local output="$2"

    # 检查目录是否可写
    local dir=$(dirname "$output")
    if [ ! -w "$dir" ]; then
        error "目录不可写: $dir"
    fi

    # 检查磁盘空间（至少需要 50MB）
    local available=$(df -m "$dir" 2>/dev/null | awk 'NR==2 {print $4}')
    if [ -n "$available" ] && [ "$available" -lt 50 ]; then
        error "磁盘空间不足: ${available}MB 可用，需要至少 50MB"
    fi

    if command -v curl &> /dev/null; then
        # 使用 --progress-bar 显示进度，-L 跟随重定向
        curl -L --progress-bar --fail "$url" -o "$output"
    elif command -v wget &> /dev/null; then
        wget --progress=bar:force "$url" -O "$output"
    else
        error "需要 curl 或 wget"
    fi
}

# 安装
install_termbuddy() {
    info "创建安装目录: $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"

    local download_url="${RELEASE_URL}/${BINARY_NAME}"
    info "下载 TermBuddy Server (最新版)..."
    info "  来源: $download_url"

    if ! download "$download_url" "$INSTALL_DIR/tb_server"; then
        error "下载失败，请检查网络连接或访问 https://github.com/${REPO}/releases 手动下载"
    fi

    chmod +x "$INSTALL_DIR/tb_server"
    success "下载完成"
}

# 初始化配置
init_config() {
    cd "$INSTALL_DIR"

    if [ -f "config.yaml" ]; then
        warn "配置文件已存在，跳过初始化"
        return
    fi

    info "初始化配置..."
    ./tb_server init --non-interactive

    # 修改端口（如果指定了非默认端口）
    if [ "$PORT" != "8765" ]; then
        info "设置端口为 $PORT..."
        if [ "$OS" = "darwin" ]; then
            sed -i '' "s/port: 8765/port: $PORT/" config.yaml
        else
            sed -i "s/port: 8765/port: $PORT/" config.yaml
        fi
    fi

    success "配置初始化完成"
}

# 获取 Token
get_token() {
    if [ -f "$INSTALL_DIR/config.yaml" ]; then
        TOKEN=$(grep -E "^\s*token:" "$INSTALL_DIR/config.yaml" | head -1 | awk '{print $2}' | tr -d '"')
    fi
}

# 打印安装结果
print_summary() {
    get_token

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}  TermBuddy Server 安装成功！${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  安装目录: $INSTALL_DIR"
    echo "  端口:     $PORT"
    if [ -n "$TOKEN" ]; then
        echo ""
        echo -e "  ${YELLOW}认证 Token（请保存）:${NC}"
        echo "  $TOKEN"
    fi
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  下一步"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  1. 启动服务:"
    echo "     cd $INSTALL_DIR && ./tb_server serve"
    echo ""
    echo "  2. 后台运行:"
    echo "     cd $INSTALL_DIR"
    echo "     nohup ./tb_server serve > tb_server.log 2>&1 &"
    echo ""
    echo "  3. 在 iOS TermBuddy 应用中添加服务器:"
    echo "     - 输入服务器 IP 和 SSH 凭据"
    echo "     - 输入上面的 Token"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# 主流程
main() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "       TermBuddy Server 安装程序"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    detect_platform
    install_termbuddy
    init_config
    print_summary
}

main "$@"
