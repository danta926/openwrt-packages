#!/bin/bash
set -euo pipefail

# 临时目录
TEMP_DIR="temp"

# 创建临时目录
mkdir -p "${TEMP_DIR}"

# 同步插件函数（直接输出到当前根目录）
sync_pkg() {
    local REPO_URL="$1"
    local PKG_PATH="$2"
    local LOCAL_NAME="$3"

    echo -e "\n========================================"
    echo "开始同步: ${LOCAL_NAME}"
    echo -e "========================================\n"

    # 稀疏克隆
    git clone --depth 1 --filter=blob:none --sparse "${REPO_URL}" "${TEMP_DIR}/${LOCAL_NAME}"
    cd "${TEMP_DIR}/${LOCAL_NAME}"
    git sparse-checkout set "${PKG_PATH}"
    cd - > /dev/null

    # 直接复制到当前根目录
    rm -rf "./${LOCAL_NAME}"
    cp -rf "${TEMP_DIR}/${LOCAL_NAME}/${PKG_PATH}" "./${LOCAL_NAME}"

    echo -e "✅ ${LOCAL_NAME} 同步完成！"
}

# ===================== 插件列表 =====================
# OpenClash
sync_pkg \
    "https://github.com/vernesong/OpenClash.git" \
    "luci-app-openclash" \
    "luci-app-openclash"

# ddns-go
sync_pkg \
    "https://github.com/jeessy2/ddns-go.git" \
    "openwrt" \
    "luci-app-ddns-go"
# ======================================================

# 清理临时文件
rm -rf "${TEMP_DIR}"

echo -e "\n🎉 所有插件已同步到当前根目录！"
