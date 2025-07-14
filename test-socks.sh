#!/bin/bash

# SOCKS5代理测试脚本

echo "=== SOCKS5代理测试 ==="
echo "测试SOCKS5代理连通性"
echo

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 测试函数
test_socks5() {
    local proxy="$1"
    local url="$2"
    
    echo -n "测试 $proxy -> $url ... "
    
    # 使用curl通过SOCKS5代理访问
    result=$(curl --socks5-hostname "$proxy" -s -m 10 "$url" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ 成功${NC}"
        
        # 解析IP信息
        ip=$(echo "$result" | grep -o '"ip":"[^"]*"' | cut -d'"' -f4)
        country=$(echo "$result" | grep -o '"country":"[^"]*"' | cut -d'"' -f4)
        org=$(echo "$result" | grep -o '"org":"[^"]*"' | cut -d'"' -f4)
        
        echo "    IP: $ip"
        echo "    国家: $country"
        echo "    组织: $org"
        echo
    else
        echo -e "${RED}❌ 失败${NC}"
        echo
    fi
}

# 测试SOCKS5代理
test_socks5 "127.0.0.1:8889" "https://ipinfo.io/json"

# 测试HTTP代理（对比）
echo "=== HTTP代理测试 (端口8888) ==="
curl -x "http://127.0.0.1:8888" -s -m 10 "https://ipinfo.io/json" | jq -r '.ip, .country, .org' 2>/dev/null || echo "HTTP代理测试失败"

echo "=== 测试完成 ==="

# 使用示例
if [ "$1" = "watch" ]; then
    echo "持续监控模式..."
    while true; do
        echo "$(date): 测试SOCKS5代理..."
        curl --socks5-hostname "127.0.0.1:8889" -s -m 5 "https://ipinfo.io/json" | jq -r '.ip' 2>/dev/null || echo "连接失败"
        sleep 5
    done
fi