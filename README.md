# GCP Xray (VLESS-Reality) Automated Deployment Script

An automated, shell-based deployment script for provisioning Xray-core (VLESS + Reality protocol) proxies on Google Cloud Platform (GCP). Designed specifically for execution within the GCP Cloud Shell environment.

## 🌟 Key Features
- **Zero-Touch Provisioning**: Automates instance creation, firewall configuration, and dependency installation without requiring manual SSH access or interactive prompts during execution.
- **Robust Dependency Management**: Implements `dpkg` lock detection loops within the `startup-script` to prevent deadlocks caused by Ubuntu's `unattended-upgrades` on first boot.
- **Dynamic Key Extraction**: Utilizes `awk` and regular expressions to accurately parse `xray x25519` output, ensuring compatibility with the latest Xray-core release formatting.
- **Interactive Region Selection**: Provides a terminal-based UI for selecting deployment zones (Taiwan, Hong Kong, Japan, Korea, and US-West) via Bash Process Substitution (`<()`), overcoming standard pipe (`|`) limitations in Cloud Shell.

---

## 🛠️ Usage Instructions

### Prerequisites
1. A Google Cloud Platform account with an active billing profile.
2. An active GCP Project selected in the console.

### Deployment Steps
1. Navigate to the [Google Cloud Console](https://console.cloud.google.com/).
2. Open the **Cloud Shell** by clicking the `>_` icon in the top-right navigation bar.
3. Once the Cloud Shell terminal is ready, execute the following command:

```bash
bash <(curl -sL https://raw.githubusercontent.com/gitreposcripts/gcp-xray/main/install.sh)
```

4. **Region Selection**: The script will prompt you to select a deployment region. Enter the corresponding number (e.g., `1` for `asia-east1-b`) and press Enter.
5. **Wait for Provisioning**: The script will provision an `e2-micro` instance and poll the serial console output. This process typically takes 1-2 minutes while the instance installs packages and generates the Xray configuration.
6. **Retrieve Configuration**: Upon completion, a `vless://` URI will be printed to the terminal. Copy this entire string and import it into a compatible client (e.g., V2rayNG, Shadowrocket, Clash Meta).

---

## ⚙️ Technical Details

### Architecture
- The script operates by injecting a `startup-script` payload via the `gcloud compute instances create` command's `--metadata-from-file` flag. This prevents Cloud Shell from incorrectly parsing JSON objects as dictionaries.
- After instance creation, the orchestrating script continuously polls `gcloud compute instances get-serial-port-output` until it detects a specific marker (`VLESS_LINK_START::::`) emitted by the completed `startup-script`.

### Troubleshooting
- **Script hangs at polling (......)**: If the script stalls for more than 5 minutes, it generally indicates a resource quota exhaustion in the selected GCP zone (common in `asia-east2` for new accounts). Interrupt the script (`Ctrl+C`), delete the stalled instance via the GCP console, and retry deployment in a different region.
- **Pricing & Free Tier**: Deployments in `us-west1` regions are eligible for the GCP Always Free tier (`e2-micro` instance). Note that egress network traffic to certain destinations may still incur minimal charges outside the trial credits.
