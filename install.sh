#!/bin/bash
# ==============================================================================
# GCP 台湾节点 Xray (VLESS-Reality) 全自动一键部署脚本
# ==============================================================================

# 1. 确保 Compute Engine API 处于启用状态
gcloud services enable compute.googleapis.com --quiet

# 2. 准备机器配置参数
INSTANCE_NAME="tw-node-$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 4 | head -n 1)"
ZONE="asia-east1-b"

echo "=================================================="
echo "🚀 开始全自动部署台湾 Reality 节点 (终极稳定版)..."
echo "=================================================="

# 3. 创建防火墙规则，放行 443 端口
gcloud compute firewall-rules create allow-xray-443 \
    --direction=INGRESS --network=default --action=ALLOW \
    --rules=tcp:443,udp:443 --source-ranges=0.0.0.0/0 \
    --target-tags=xray-server --quiet 2>/dev/null

# 4. 生成要在机器内部执行的启动脚本
cat << 'INLINESCRIPT' > startup.sh
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

# 【防死锁机制】等待 Ubuntu 系统后台自动更新完成
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 5; done;
while fuser /var/lib/dpkg/lock >/dev/null 2>&1; do sleep 5; done;

# 开启 BBR 网络拥塞控制算法
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

# 安装依赖并一键安装 Xray 核心
apt-get update -y && apt-get install -y curl unzip
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# 生成 Reality 协议所需的密钥参数
UUID=$(xray uuid)
KEYS=$(xray x25519)
PRI_KEY=$(echo "$KEYS" | awk -F ': ' '/PrivateKey/{print $2}')
PUB_KEY=$(echo "$KEYS" | awk -F ': ' '/PublicKey/{print $2}')
SHORT_ID=$(openssl rand -hex 4)
IP=$(curl -s https://api.ipify.org)

# 写入 Xray 配置文件
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

# 拼接最终链接并回传
LINK="vless://${UUID}@${IP}:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.apple.com&fp=chrome&pbk=${PUB_KEY}&sid=${SHORT_ID}&type=tcp&headerType=none#GCP-Taiwan"
echo "VLESS_LINK_START::::${LINK}::::VLESS_LINK_END"
INLINESCRIPT

# 5. 发起创建实例的请求
echo "➡️ 正在创建服务器，等待启动 (约需 1 分钟) ..."
gcloud compute instances create $INSTANCE_NAME \
    --zone=$ZONE --machine-type=e2-micro \
    --image-family=ubuntu-2204-lts --image-project=ubuntu-os-cloud \
    --boot-disk-size=10GB --tags=xray-server \
    --metadata-from-file=startup-script=startup.sh --quiet

# 6. 轮询监控日志获取节点链接
echo -n "➡️ 机器已启动，等待后台配置节点参数 "
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
