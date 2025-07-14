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
- Supports HostScan bypass via `--csd-wrapper` parameter

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
# VPN服务器地址（带https://前缀）
OPENCONNECT_URL=vpn.company.com

# 用户凭据
OPENCONNECT_USER=your_username
OPENCONNECT_PASSWORD=your_password

# OpenConnect连接选项（使用双引号包裹）
OPENCONNECT_OPTIONS="--authgroup=Employees --protocol=anyconnect --os=win --useragent='AnyConnect Windows 4.10.06079' --no-xmlpost --csd-wrapper=/etc/csd-post.sh --script=/etc/vpnc/vpnc-script --reconnect-timeout=86400"

# 服务器证书验证（可选）
# --servercert=pin-sha256:YOUR_CERT_FINGERPRINT_HERE

# 多因素认证（可选）
OPENCONNECT_MFA_CODE=push

# VPN路由配置
# 0 = 全局VPN（所有流量走VPN）
# 1 = 分流VPN（只路由指定网段）
VPN_SPLIT=0

# 当VPN_SPLIT=1时，指定需要走VPN的网段（空格分隔）
# VPN_ROUTES=10.0.0.0/8 172.16.0.0/12 192.168.0.0/16
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
- HostScan bypass via professional CSD script (`/etc/csd-post.sh`)
- SOCKS5/HTTP proxy testing via `test-socks.sh` script


