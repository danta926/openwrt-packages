#!/bin/bash
# ==============================================================================
# 修复说明：
# 1. 将 git pull --filter 拆解为 git fetch --filter + git checkout，解决兼容性报错。
# 2. 依然保留强大的多线程并发与 PID 追踪机制，速度依然起飞。
# ==============================================================================

set -uo pipefail

# ==================== 配置区 ====================
declare -A FULL_PROJECTS=(
    ["https://github.com/vernesong/OpenClash"]="luci-app-openclash"
    ["https://github.com/ophub/luci-app-amlogic"]="luci-app-amlogic"
    ["https://github.com/jerrykuku/luci-theme-argon"]="luci-theme-argon"
    ["https://github.com/jerrykuku/luci-app-argon-config"]="luci-app-argon-config"
    ["https://github.com/lisaac/luci-app-diskman"]="luci-app-diskman"
)

declare -A SPARSE_ITEMS=(
    ["https://github.com/immortalwrt/immortalwrt v25.12.0"]="package/emortal -> emortal"
    ["https://github.com/kenzok8/openwrt-packages master"]="ddns-go luci-app-ddns-go luci-app-dockerman -> ."
    ["https://github.com/immortalwrt/luci openwrt-24.10"]="applications/luci-app-hd-idle applications/luci-app-samba4 -> ."
)

ROOT_DIR="$(pwd)"

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
    
    # 使用子 Shell 隔离环境
    (
        cd "$tmp_dir" || exit 1
        git init -q
        git config core.sparseCheckout true
        
        # 写入需要检出的路径
        for p in $paths; do
            echo "$p" >> .git/info/sparse-checkout
        done
        
        git remote add origin "$repo"
        
        # 【核心修复点】改用 fetch 配合 --filter=blob:none，完美兼容新旧 Git 版本
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
echo "🧹 开始清理旧文件..."
find . -maxdepth 1 ! -name '.' ! -name '..' \
    ! -name '.git' ! -name '.github' \
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
    echo "🎉 所有插件并行处理完毕，完美成功！"
    exit 0
fi
