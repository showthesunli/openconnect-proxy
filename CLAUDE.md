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