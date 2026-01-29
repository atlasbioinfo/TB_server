# TB_Server

TermBuddy Server - 用于 iOS TermBuddy 应用的远程终端服务端

## 一键安装（推荐）

```bash
curl -fsSL https://raw.githubusercontent.com/atlasbioinfo/TB_server/main/install.sh | bash
```

自动完成：下载 → 安装到 `~/.termbuddy` → 生成配置和 Token

安装完成后启动：

```bash
cd ~/.termbuddy && ./tb_server serve
```

---

## 手动安装

### 1. 下载二进制文件

根据你的服务器系统选择对应的文件：

| 系统 | 架构 | 文件 |
|------|------|------|
| Linux | x86_64 (AMD64) | `tb_server-linux-amd64` |
| Linux | ARM64 (如树莓派、AWS Graviton) | `tb_server-linux-arm64` |
| macOS | Intel | `tb_server-darwin-amd64` |
| macOS | Apple Silicon (M1/M2/M3) | `tb_server-darwin-arm64` |

### 2. 安装

```bash
# 下载后，复制到服务器并设置权限
chmod +x tb_server-linux-amd64

# 创建安装目录
mkdir -p ~/.termbuddy

# 移动到安装目录（重命名为 tb_server）
mv tb_server-linux-amd64 ~/.termbuddy/tb_server

# 进入目录
cd ~/.termbuddy
```

### 3. 初始化配置

```bash
./tb_server init
```

这会创建配置文件 `~/.termbuddy/config.yaml`，并自动生成认证 Token。

**重要：** 记下输出中的 Token，iOS 应用连接时需要使用。

### 4. 启动服务

```bash
./tb_server serve
```

输出示例：
```
TermBuddy Server started
Listening on 127.0.0.1:8765
Auth token: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
Storage: memory
```

## 使用方式

### 命令列表

```bash
./tb_server init      # 初始化配置文件
./tb_server serve     # 启动服务
./tb_server version   # 查看版本
./tb_server status    # 检查运行状态
./tb_server qrcode    # 生成连接二维码（支持 Tailscale）
```

### 配置文件

位置：`~/.termbuddy/config.yaml`

```yaml
server:
  host: "127.0.0.1"     # 监听地址（默认仅本地，通过 SSH 隧道访问）
  port: 8765            # 监听端口

auth:
  token: "xxx..."       # 认证 Token（自动生成）
  tokenExpiry: "24h"    # 会话有效期

session:
  defaultShell: "/bin/bash"   # 默认 Shell
  historyLimit: 1000          # 消息历史上限

storage:
  type: "memory"        # 存储类型：memory 或 sqlite
  path: "./data/termbuddy.db"
```

### 后台运行

**方式一：使用 nohup**

```bash
cd ~/.termbuddy
nohup ./tb_server serve > tb_server.log 2>&1 &

# 查看日志
tail -f tb_server.log

# 停止服务
pkill tb_server
```

**方式二：使用 systemd（推荐用于 Linux 服务器）**

```bash
# 以 root 安装系统服务
sudo ./tb_server install

# 启动服务
sudo systemctl start termbuddy

# 设置开机自启
sudo systemctl enable termbuddy

# 查看状态
sudo systemctl status termbuddy

# 查看日志
sudo journalctl -u termbuddy -f
```

## 连接方式

### 方式一：SSH 隧道（推荐）

服务默认监听 `127.0.0.1:8765`，只能从本机访问。iOS 应用通过 SSH 隧道连接：

1. iOS 应用先建立 SSH 连接到服务器
2. 通过 SSH 隧道执行 curl 命令访问本地服务
3. 所有流量都经过 SSH 加密

**优点：** 无需开放额外端口，安全性高

### 方式二：Tailscale/VPN 直连

如果使用 Tailscale 或其他 VPN，可以直接连接：

1. 修改配置文件，将 `host` 改为 `0.0.0.0`：
   ```yaml
   server:
     host: "0.0.0.0"
     port: 8765
   ```

2. 重启服务

3. 生成连接二维码：
   ```bash
   ./tb_server qrcode
   ```

4. 用 iOS 应用扫描二维码即可连接

## API 端点

| 端点 | 方法 | 说明 |
|------|------|------|
| `/health` | GET | 健康检查（无需认证） |
| `/api/v1/auth/login` | POST | 登录获取会话 Token |
| `/api/v1/sessions` | GET | 列出所有会话 |
| `/api/v1/sessions` | POST | 创建新会话 |
| `/api/v1/sessions/:id` | GET | 获取会话详情 |
| `/api/v1/sessions/:id` | DELETE | 删除会话 |
| `/api/v1/sessions/:id/input` | POST | 发送命令 |
| `/api/v1/sessions/:id/messages` | GET | 获取消息历史 |
| `/api/v1/sessions/:id/resize` | POST | 调整终端大小 |

## 常见问题

### Q: 忘记 Token 怎么办？

查看配置文件：
```bash
cat ~/.termbuddy/config.yaml | grep token
```

### Q: Shell 找不到？

服务会自动检测可用的 Shell，按以下顺序尝试：
1. `/bin/bash`
2. `/bin/sh`
3. `/bin/zsh`
4. PATH 中的 bash、sh、zsh

如果仍有问题，在配置文件中手动指定：
```yaml
session:
  defaultShell: "/usr/bin/bash"
```

### Q: 如何查看服务状态？

```bash
# 检查进程
ps aux | grep tb_server

# 检查端口
netstat -tlnp | grep 8765

# 健康检查
curl http://127.0.0.1:8765/health
```

### Q: 如何升级？

1. 停止服务
2. 下载新版本二进制文件
3. 替换 `~/.termbuddy/tb_server`
4. 重启服务

配置文件会保留，无需重新初始化。

## 安全建议

1. **使用 SSH 隧道**：不要将服务直接暴露在公网
2. **保护 Token**：不要泄露配置文件中的 Token
3. **定期更新**：保持服务端版本最新
4. **检查日志**：定期查看 `~/.termbuddy/termbuddy.log`

## License

MIT License
