#!/bin/sh
# 秒通过 UCI 的 CSD / HostScan 检查

cat > "$COOKIE" <<EOF
<?xml version="1.0"?>
<HostscanReplay>
  <morgan>1</morgan>
</HostscanReplay>
EOF

exit 0