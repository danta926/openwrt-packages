#!/bin/bash

# 定义同步函数
sync_pkg() {
    REPO_URL=$1
    SRC_PATH=$2
    LOCAL_NAME=$3

    echo "正在拉取: $LOCAL_NAME"
    # 创建独立临时文件夹，防止冲突
    TMP_DIR="temp_$LOCAL_NAME"
    git clone --depth 1 $REPO_URL $TMP_DIR
    
    # 核心修复：检查路径并拷贝
    if [ -d "$TMP_DIR/$SRC_PATH" ]; then
        rm -rf "$LOCAL_NAME"
        cp -rf "$TMP_DIR/$SRC_PATH" "$LOCAL_NAME"
        echo "✅ $LOCAL_NAME 同步成功"
    else
        echo "❌ 错误：找不到路径 $SRC_PATH"
        exit 1
    fi
    rm -rf "$TMP_DIR"
}

# --- 这里是你的插件配置区 ---
# OpenClash 路径没问题
sync_pkg "https://github.com/vernesong/OpenClash.git" "luci-app-openclash" "luci-app-openclash"

# ddns-go 路径必须修正为这个：
sync_pkg "https://github.com/jeessy2/ddns-go.git" "openwrt/luci-app-ddns-go" "luci-app-ddns-go"

echo "所有同步任务完成！"
