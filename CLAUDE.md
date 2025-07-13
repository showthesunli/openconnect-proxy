# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
This is a Docker-based VPN proxy solution that combines:
- **OpenConnect** client (v9.12) for VPN connectivity with support for multiple protocols (anyconnect, nc, gp, pulse, f5, fortinet, array)
- **Tinyproxy** HTTP/HTTPS proxy server (port 8888)
- **Microsocks** SOCKS5 proxy server (port 8889)
- **vpn-slice** support for selective VPN traffic routing

## Architecture
The container runs Alpine Linux 3.19 and includes:
- `/entrypoint.sh` - Main startup script handling VPN connection and proxy services
- `/etc/vpnc/vpnc-script` - Comprehensive VPN configuration script handling routing, DNS, and network setup
- `/etc/tinyproxy.conf` - Tinyproxy configuration file
- Custom DNS resolution via `/usr/local/bin/fix-dns`

## Key Components

### Entrypoint Script (`build/entrypoint.sh`)
- Starts tinyproxy and microsocks services
- Handles OpenConnect authentication with multiple methods:
  - Interactive password prompt
  - Environment variable password
  - Multi-factor authentication (MFA)
- Implements automatic restart loop (60s delay on failure)
- Supports vpn-slice for split tunneling when `VPN_SPLIT=1`

### VPN Configuration (`build/vpnc-script`)
- Comprehensive OS detection and routing setup
- IPv4/IPv6 support with split tunneling capabilities
- DNS management via multiple backends (systemd-resolved, resolvconf, etc.)
- Route management for split VPN configurations
- Platform-specific network interface handling

### Proxy Services
- **Tinyproxy**: HTTP/HTTPS proxy on port 8888 with configurable logging
- **Microsocks**: Lightweight SOCKS5 proxy on port 8889

## Common Commands

### Build
```bash
docker build -f build/Dockerfile -t wazum/openconnect-proxy:custom ./build
```

### Run Container
```bash
# Interactive mode
docker run -it --rm --privileged --env-file=.env \
  -p 8888:8888 -p 8889:8889 wazum/openconnect-proxy:latest

# Background mode
docker run -d --privileged --env-file=.env \
  -p 8888:8888 -p 8889:8889 wazum/openconnect-proxy:latest
```

### Environment Variables
Create `.env` file with:
```sh
OPENCONNECT_URL=<gateway URL>
OPENCONNECT_USER=<username>
OPENCONNECT_PASSWORD=<password>
OPENCONNECT_OPTIONS=--authgroup <VPN group> \
	--servercert <VPN server certificate> --protocol=<Protocol> \
	--reconnect-timeout 86400
VPN_SPLIT=0
```

### Split VPN Configuration
```sh
VPN_SPLIT=1
VPN_ROUTES=172.16.0.0/12 XXX.XXX.XXX.XXX/32
```

### Docker Compose
```yaml
vpn:
  container_name: openconnect_vpn
  image: wazum/openconnect-proxy:latest
  privileged: true
  env_file:
    - .env
  ports:
    - 8888:8888
    - 8889:8889
  cap_add:
    - NET_ADMIN
```

## Development Notes
- Container requires `--privileged` flag for VPN functionality
- All configuration via environment variables or `.env` file
- Automatic restart on VPN connection failure
- Support for both full tunnel and split tunnel configurations
- DNS resolution handled through container's internal mechanisms

# 在容器里连接 UCI AnyConnect VPN 的完整方案

> **目标**：把 **openconnect-proxy** 容器改造成能顺利登录 `vpn.uci.edu`，并通过 `8888` / `8889` 暴露 HTTP / SOCKS5 代理。
> **关键点**：**指定正确的组 → 关闭 XML-POST → 伪装 Windows 客户端 → “秒通过” HostScan**。

---

## 1 · 准备文件结构

```text
project-root/
├─ .env                # OpenConnect 连接参数
└─ oc_csd_fake.sh      # HostScan “秒通过”脚本
```

---

## 2 · `.env` 示例

```env
# VPN 服务器地址（一定带 https://）
OPENCONNECT_URL=https://vpn.uci.edu

# 凭据
OPENCONNECT_USER=<你的 NetID>
OPENCONNECT_PASSWORD=<你的 NetID 密码>      # 或留空 → 容器启动时交互输入

# OpenConnect 启动选项（全部放一行）
OPENCONNECT_OPTIONS="\
  --authgroup=UCIFull \                       # 选对组，避开 302→404
  --protocol=anyconnect \                     # 明确协议
  --os=win \                                  # 伪装 Windows
  --useragent='AnyConnect Windows 4.10.06079' \ # 与官方客户端一致
  --no-xmlpost \                              # 跳过不被接受的 XML-POST
  --csd-wrapper=/etc/oc_csd_fake.sh \         # HostScan 秒过
  --reconnect-timeout=86400"                  # 可选：断线自动重连 24 h

# 是否做路由分流（0=全局，1=分流）
VPN_SPLIT=0
# 若 VPN_SPLIT=1，需要再写
# VPN_ROUTES=10.0.0.0/8 172.16.0.0/12 ...
```

---

## 3 · HostScan 假回执脚本 `oc_csd_fake.sh`

```bash
#!/usr/bin/env bash
# 秒通过 UCI 的 CSD / HostScan 检查

cat > "$COOKIE" <<EOF
<?xml version="1.0"?>
<HostscanReplay>
  <morgan>1</morgan>
</HostscanReplay>
EOF

exit 0
```

> 给脚本加执行权限：
>
> ```bash
> chmod +x oc_csd_fake.sh
> ```

---

## 4 · 运行容器

```bash
docker run -it --rm --privileged \
  --env-file .env \
  -v $(pwd)/oc_csd_fake.sh:/etc/oc_csd_fake.sh \
  -p 8888:8888 -p 8889:8889 \
  openconnect-proxy:amd64
```

容器启动成功后即可使用代理：

| 代理类型         | 地址                    |
| ------------ | --------------------- |
| HTTP / HTTPS | `http://<宿主机>:8888`   |
| SOCKS5       | `socks5://<宿主机>:8889` |

---

## 5 · 参数为什么这么配？

| 选项                           | 作用                                           |
| ---------------------------- | -------------------------------------------- |
| `--authgroup=UCIFull`        | UCI VPN 必须明确选择组；缺省会被重定向到 Web Portal，继而 404。  |
| `--no-xmlpost`               | 部分新版 ASA 拒绝预登录 XML-POST，直接 404。              |
| `--os=win` + `--useragent=…` | 伪装成 Windows AnyConnect 4.10，让服务器触发 HostScan。 |
| `--csd-wrapper`              | 用脚本秒回“HostScan OK”，避免下载 `sfinst` 失败。         |
| `https://` 前缀                | 避免因协议推测导致的 301/302 重定向。                      |

---

## 6 · 常见故障排查

1. **加 `-vvv`** 查看详细日志，确认是否卡在 Duo MFA。
2. 连接超时 → 试 `--no-dtls` （禁用 UDP 443）。
3. 证书报错 → 暂用 `--servercert pin-sha256:…` 比对指纹后再恢复校验。
4. 查看版本 →

   ```bash
   docker run --rm openconnect-proxy:amd64 openconnect --version
   ```

   确保 ≥ 9.12。

---

> 将本 Markdown 文档直接交给 Claude Code（或其他 LLM）即可生成自动化部署文件（Docker Compose、K8s Manifest 等）。

