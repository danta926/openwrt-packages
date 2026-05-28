#!/bin/bash
# ==============================================================================
# 终极一体化脚本优化要点：
# 1. 自动定位、注释 feeds.conf.default 中的旧源，并安全追加 24.10 的四个新源。
# 2. 修复 git pull --filter 带来的旧版本 Git 兼容性大坑。
# 3. 保留高并发多线程同步，整仓克隆与稀疏拉取同步进行，速度起飞。
# 4. 已移除 luci-app-samba4 与 luci-app-hd-idle 稀疏同步。
# ==============================================================================

set -uo pipefail

# ==================== 配置区 ====================
# 1. 声明普通整仓项目
declare -A FULL_PROJECTS=(
    ["https://github.com/vernesong/OpenClash"]="luci-app-openclash"
    ["https://github.com/ophub/luci-app-amlogic"]="luci-app-amlogic"
    ["https://github.com/jerrykuku/luci-theme-argon"]="luci-theme-argon"
    ["https://github.com/jerrykuku/luci-app-argon-config"]="luci-app-argon-config"
    ["https://github.com/lisaac/luci-app-diskman"]="luci-app-diskman"
)

# 2. 声明稀疏检出大仓项目
#    修改说明：将原来从 kenzok8 一次性拉取 ddns-go、luci-app-ddns-go、luci-app-dockerman 的方式，
#              拆分为三个独立源，其中 ddns-go 和 luci-app-ddns-go 改用 immortalwrt 官方源。
declare -A SPARSE_ITEMS=(
    ["https://github.com/immortalwrt/immortalwrt v25.12.0"]="package/emortal -> emortal"
    # 保留：luci-app-dockerman 仍从 kenzok8 拉取
    ["https://github.com/kenzok8/openwrt-packages master"]="luci-app-dockerman -> ."
)

ROOT_DIR="$(pwd)"
FEEDS_FILE="feeds.conf.default"

# ==================== 函数定义 ====================
clone_full_repo() {
    local repo="$1" target="$2"
    echo "🚀 [并发启动] 开始整仓克隆: $target"
    
    if git clone --depth 1 --filter=blob:none "$repo" "$target" -q; then
        rm -rf "$target/.git" "$target/.github"
        echo "✅ [整仓就绪] $target"
        return 0
    else
        echo "❌ [整仓失败] $target 克隆异常"
        return 1
    fi
}

sparse_checkout() {
    local repo="$1" branch="$2" paths="$3" target_dir="$4"
    echo "🚀 [并发启动] 开始稀疏拉取: ${target_dir:-根目录} (源自 $(basename "$repo"))"

    local tmp_dir
    tmp_dir=$(mktemp -d -t "sparse_XXXXXX")
    
    (
        cd "$tmp_dir" || exit 1
        git init -q
        git config core.sparseCheckout true
        
        for p in $paths; do
            echo "$p" >> .git/info/sparse-checkout
        done
        
        git remote add origin "$repo"
        git fetch origin "$branch" --depth 1 --filter=blob:none -q && git checkout -q FETCH_HEAD
    )
    
    if [ $? -ne 0 ]; then
        echo "❌ [稀疏失败] 无法从 $repo 拉取数据"
        rm -rf "$tmp_dir"
        return 1
    fi

    # 处理数据移动
    if [[ "$target_dir" == "." ]]; then
        for p in $paths; do
            local src_path="$tmp_dir/$p"
            local bname
            bname=$(basename "$p")
            if [[ -e "$src_path" ]]; then
                rm -rf "$ROOT_DIR/$bname"
                mv "$src_path" "$ROOT_DIR/$bname"
                echo "   📦 平铺成功: ./$bname"
            fi
        done
    else
        mkdir -p "$ROOT_DIR/$target_dir"
        for p in $paths; do
            local src_path="$tmp_dir/$p"
            if [[ -e "$src_path" ]]; then
                if [[ -d "$src_path" ]]; then
                    cp -r "$src_path/"* "$ROOT_DIR/$target_dir/" 2>/dev/null || cp -r "$src_path" "$ROOT_DIR/$target_dir/"
                else
                    cp "$src_path" "$ROOT_DIR/$target_dir/"
                fi
                echo "   📦 归流成功: $p -> $target_dir"
            fi
        done
    fi

    rm -rf "$tmp_dir"
    return 0
}

# ==================== 主流程 ====================

# ----------------- Feeds 修改逻辑 -----------------
if [ -f "$FEEDS_FILE" ]; then
    echo "⚙️  发现 $FEEDS_FILE，正在更新 Feeds 仓库源..."
    
    # 1. 使用 sed 注释掉原本的 packages, luci, routing, telephony 行（避免重复冲突）
    sed -i '/src-git packages/s/^/#/' "$FEEDS_FILE"
    sed -i '/src-git luci/s/^/#/' "$FEEDS_FILE"
    sed -i '/src-git routing/s/^/#/' "$FEEDS_FILE"
    sed -i '/src-git telephony/s/^/#/' "$FEEDS_FILE"

    # 2. 清理上一次运行可能残留的追加块，防止多次运行脚本导致文件无限膨胀
    sed -i '/# === CUSTOM OPENWRT 24.10 FEEDS ===/,/# === END CUSTOM FEEDS ===/d' "$FEEDS_FILE"

    # 3. 追加你提供的新 24.10 仓库源
    cat >> "$FEEDS_FILE" <<EOF
# === CUSTOM OPENWRT 24.10 FEEDS ===
src-git packages https://github.com/openwrt/packages.git;openwrt-24.10
src-git luci https://github.com/danta926/luci.git;openwrt-24.10
src-git routing https://github.com/openwrt/routing.git;openwrt-24.10
src-git telephony https://github.com/openwrt/telephony.git;openwrt-24.10
# === END CUSTOM FEEDS ===
EOF
    echo "✅ Feeds 仓库源已成功切换为 OpenWrt-24.10 分支（包含 danta926 自定义LuCI）"
else
    echo "⚠️  未在当前目录下找到 $FEEDS_FILE，跳过 Feeds 修改。"
fi
echo "------------------------------------------"

# ----------------- 插件清理与并发下载 -----------------
echo "🧹 开始清理旧插件文件..."
find . -maxdepth 1 ! -name '.' ! -name '..' \
    ! -name '.git' ! -name '.github' ! -name "$FEEDS_FILE" \
    ! -name "$(basename "$0")" -exec rm -rf {} +

echo "------------------------------------------"
echo "📥 正在并行同步所有插件，请稍候..."
echo "------------------------------------------"

declare -A PIDS

# 1. 后台整仓克隆
for repo in "${!FULL_PROJECTS[@]}"; do
    dir_name="${FULL_PROJECTS[$repo]}"
    clone_full_repo "$repo" "$dir_name" &
    PIDS[$!]="$dir_name (整仓)"
done

# 2. 后台稀疏检出
for key in "${!SPARSE_ITEMS[@]}"; do
    IFS=' ' read -r repo branch <<< "$key"
    target_spec="${SPARSE_ITEMS[$key]}"
    paths_part="${target_spec% -> *}"
    target_part="${target_spec#* -> }"
    
    sparse_checkout "$repo" "$branch" "$paths_part" "$target_part" &
    PIDS[$!]="$(basename "$repo") (稀疏)"
done

# ==================== 3. 智能收网与错误检查 ====================
FAILED=0
for pid in "${!PIDS[@]}"; do
    wait "$pid"
    exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "🚨 错误: 任务 [${PIDS[$pid]}] 失败，退出码: $exit_code"
        FAILED=1
    fi
done

echo "------------------------------------------"
if [ $FAILED -eq 1 ]; then
    echo "❌ 同步过程中部分插件出错，请检查上方日志！"
    exit 1
else
    echo "🎉 所有 Feeds 修改和插件并行处理完毕，完美成功！"
    exit 0
fi
