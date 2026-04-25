#!/bin/bash
# ==============================================================================
# GCP Xray (VLESS-Reality) 全自动一键部署脚本 (多区域交互版)
# ==============================================================================

echo "=================================================="
echo "🚀 欢迎使用 GCP Reality 节点全自动部署向导"
echo "=================================================="
echo "请选择服务器物理位置 (机型: e2-micro, 10G 硬盘):"
echo "  1) 🇹🇼 台湾 (asia-east1-b)        - 约 \$6.5 ~ \$7.0 / 月"
echo "  2) 🇸🇬 新加坡 (asia-southeast1-b) - 约 \$6.5 ~ \$7.0 / 月"
echo "  3) 🇭🇰 香港 (asia-east2-a)        - 约 \$7.0 ~ \$8.0 / 月"
echo "  4) 🇯🇵 日本 (asia-northeast1-b)   - 约 \$6.5 ~ \$7.0 / 月"
echo "  5) 🇺🇸 美国 (us-west1-b)          - 包含在 GCP 永久免费额度内 (0\$)"
echo "--------------------------------------------------"
read -p "请输入数字 [默认 1]: " REGION_CHOICE

case "$REGION_CHOICE" in
    2) ZONE="asia-southeast1-b"; PREFIX="SG" ;;
    3) ZONE="asia-east2-a"; PREFIX="HK" ;;
    4) ZONE="asia-northeast1-b"; PREFIX="JP" ;;
    5) ZONE="us-west1-b"; PREFIX="US" ;;
    *) ZONE="asia-east1-b"; PREFIX="TW" ;;
esac

PREFIX_LOWER=$(echo "$PREFIX" | tr 'A-Z' 'a-z')
INSTANCE_NAME="${PREFIX_LOWER}-node-$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 4 | head -n 1)"

echo ""
echo "🎯 已选择区域: $ZONE"
echo "🖥️  即将创建的实例名称: $INSTANCE_NAME"
echo "=================================================="

# 1. 确保 Compute Engine API 处于启用状态
echo "⏳ 正在检查并启用 Compute Engine API (首次运行必备)..."
gcloud services enable compute.googleapis.com --quiet

# 2. 创建防火墙规则，放行 443 端口
echo "🛡️  正在配置云端防火墙 (放行 443 端口)..."
gcloud compute firewall-rules create allow-xray-443 \
    --direction=INGRESS --network=default --action=ALLOW \
    --rules=tcp:443,udp:443 --source-ranges=0.0.0.0/0 \
    --target-tags=xray-server --quiet 2>/dev/null || true

# 3. 生成要在机器内部执行的启动脚本
cat << 'INLINESCRIPT' > startup.sh
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 5; done;
while fuser /var/lib/dpkg/lock >/dev/null 2>&1; do sleep 5; done;

echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

apt-get update -y && apt-get install -y curl unzip
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

UUID=$(xray uuid)
KEYS=$(xray x25519)
PRI_KEY=$(echo "$KEYS" | awk -F ': ' '/PrivateKey/{print $2}')
PUB_KEY=$(echo "$KEYS" | awk -F ': ' '/PublicKey/{print $2}')
SHORT_ID=$(openssl rand -hex 4)
IP=$(curl -s https://api.ipify.org)

cat << EOF_JSON > /usr/local/etc/xray/config.json
{
  "inbounds": [{
      "listen": "0.0.0.0", "port": 443, "protocol": "vless",
      "settings": {"clients": [{"id": "$UUID", "flow": "xtls-rprx-vision"}], "decryption": "none"},
      "streamSettings": {
        "network": "tcp", "security": "reality",
        "realitySettings": {
          "show": false, "dest": "www.apple.com:443", "xver": 0,
          "serverNames": ["www.apple.com", "apple.com"],
          "privateKey": "$PRI_KEY", "shortIds": ["$SHORT_ID"]
        }
      }
    }],
  "outbounds": [{"protocol": "freedom", "tag": "direct"}]
}
EOF_JSON

systemctl restart xray

LINK="vless://${UUID}@${IP}:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.apple.com&fp=chrome&pbk=${PUB_KEY}&sid=${SHORT_ID}&type=tcp&headerType=none#GCP-MARKER_PREFIX"
echo "VLESS_LINK_START::::${LINK}::::VLESS_LINK_END"
INLINESCRIPT

sed -i "s/MARKER_PREFIX/${PREFIX}/g" startup.sh

# 4. 发起创建实例的请求
echo "➡️ 正在向谷歌云申请创建服务器，等待启动 (约需 1 分钟) ..."
gcloud compute instances create $INSTANCE_NAME \
    --zone=$ZONE --machine-type=e2-micro \
    --image-family=ubuntu-2204-lts --image-project=ubuntu-os-cloud \
    --boot-disk-size=10GB --tags=xray-server \
    --metadata-from-file=startup-script=startup.sh --quiet

# 5. 轮询监控日志获取节点链接
echo -n "➡️ 机器已启动，等待后台自动配置底层防封锁参数 "
LINK=""
while true; do
    OUTPUT=$(gcloud compute instances get-serial-port-output $INSTANCE_NAME --zone=$ZONE --quiet 2>/dev/null | grep "VLESS_LINK_START::::")
    if [ ! -z "$OUTPUT" ]; then
        LINK=$(echo "$OUTPUT" | sed 's/.*VLESS_LINK_START:::://' | sed 's/::::VLESS_LINK_END.*//')
        break
    fi
    echo -n "."
    sleep 5
done

echo ""
echo "=================================================="
echo "🎉 部署大功告成！"
echo "=================================================="
echo "📎 请全选复制下方这段长链接，导入到 V2rayNG 或 Shadowrocket 中："
echo ""
echo "$LINK"
echo ""
echo "=================================================="

rm -f startup.sh
