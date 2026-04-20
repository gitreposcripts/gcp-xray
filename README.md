# GCP Xray (VLESS-Reality) 自动化部署脚本

这是一个用于在 Google Cloud Platform (GCP) 上自动化部署 Xray-core (VLESS + Reality 协议) 代理节点的 Shell 脚本。专为在 GCP Cloud Shell 环境中执行而设计。

## 🌟 核心特性
- **无干预部署 (Zero-Touch Provisioning)**: 自动化实例创建、防火墙配置和依赖安装，在节点内部执行过程中无需手动 SSH 登录或交互式配置。
- **稳健的依赖管理 (Robust Dependency Management)**: 在 `startup-script` 中实现了 `dpkg` 锁检测循环，以防止 Ubuntu 首次启动时由于后台自动更新 (`unattended-upgrades`) 导致的包管理器死锁。
- **动态密钥提取 (Dynamic Key Extraction)**: 利用 `awk` 和正则表达式准确解析 `xray x25519` 的输出，确保兼容最新版 Xray-core 发生变更的输出格式。
- **交互式区域选择 (Interactive Region Selection)**: 通过 Bash 进程替换 (`<()`) 提供基于终端的区域选择菜单（包含台湾、香港、日本、韩国和美国西部），克服了 Cloud Shell 中标准管道 (`|`) 导致无法读取键盘输入的限制。

---

## 🛠️ 使用说明

### 前置条件
1. 拥有已绑定活跃计费账户（信用卡）的 Google Cloud Platform 账号。
2. 在 GCP 中已拥有至少一个活跃的项目 (Project)。

### 部署步骤
1. 打开浏览器，直接访问并登录 **[Google Cloud Shell](https://shell.cloud.google.com/)**。
2. 等待网页底部的终端实例初始化完成。
3. 当终端准备就绪后，复制并执行以下命令：

```bash
bash <(curl -sL https://raw.githubusercontent.com/gitreposcripts/gcp-xray/main/install.sh)
```

4. **区域选择**: 脚本将提示您选择部署区域。输入对应的数字（例如输入 `1` 选择 `asia-east1-b`）并按回车。
5. **等待配置**: 脚本将向谷歌云申请一台 `e2-micro` 实例并轮询串口控制台输出。该过程通常需要 1-2 分钟，期间实例将在后台安装软件包并生成 Xray 配置文件及 Reality 密钥。
6. **获取配置**: 节点底层的防封锁参数配置完成后，终端将打印出一个 `vless://` URI。请复制该完整的字符串，并将其导入到兼容的客户端（如 V2rayNG, Shadowrocket, Clash Meta）中。

---

## ⚙️ 技术细节与常见问题排查

- **运行架构**: 该脚本通过 `gcloud compute instances create` 命令的 `--metadata-from-file` 标志注入 `startup-script` 载荷，从而避免了 Cloud Shell 将内嵌的 JSON 对象错误解析为字典的问题。在实例创建后，主调脚本将持续轮询 `gcloud compute instances get-serial-port-output`，直到检测到由运行完毕的 `startup-script` 发出的特定标记 (`VLESS_LINK_START::::`)。
- **轮询时脚本挂起 (......)**: 如果脚本停滞等待超过 5 分钟，通常表明所选 GCP 区域的资源配额已耗尽（新账号在 `asia-east2` 香港区域中常见此情况）。请中断脚本 (`Ctrl+C`)，通过 GCP 控制台删除处于挂起状态的实例，并在其他区域重试部署。
- **计费与免费额度**: 部署在 `us-west1` 区域的 `e2-micro` 实例符合 GCP 永久免费额度 (Always Free tier) 的计算资源条件。请注意，流向特定目的地（如中国大陆）的优质出站网络流量仍可能在试用赠金外产生微量的网络传输费用。
