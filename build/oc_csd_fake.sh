#!/bin/sh
# 秒通过 UCI 的 CSD / HostScan 检查

# 使用临时文件代替$COOKIE变量
cat > /tmp/cookie.xml <<EOF
<?xml version="1.0"?>
<HostscanReplay>
  <morgan>1</morgan>
</HostscanReplay>
EOF

# 复制到OpenConnect期望的位置
cp /tmp/cookie.xml "$1" 2>/dev/null || cp /tmp/cookie.xml /tmp/csd_cookie.xml

exit 0