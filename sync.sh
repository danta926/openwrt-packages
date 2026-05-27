#!/bin/bash
# ==============================================================================
# 优化要点：
# 1. 引入多进程并发 (Wait 机制)，让 8 个任务同时下载，时间缩短到原来的 1/4。
# 2. 引入 --filter=blob:none，只下载目录树，不下载历史二进制文件，大幅削减流量。
# 3. 规范错误收集，即使并行运行，任何一个子线程失败也会最终报错，拒绝“假成功”。
# ==============================================================================

set -uo pipefail  # 并行模式下，移除 -e，改用进程退出码状态数组控制中断

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
    
    # 增加 --filter=blob:none 减少无用历史对象下载
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
    
    # 使用子 Shell 保护环境，避免 cd 污染
    (
        cd "$tmp_dir"
        git init -q
        git config core.sparseCheckout true
        
        # 安全按行解开路径
        for p in $paths; do
            echo "$p" >> .git/info/sparse-checkout
        done
        
        git remote add origin "$repo"
        # 核心优化：深度1 + 过滤blob
        git pull origin "$branch" --depth 1 --filter=blob:none -q
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
                # 如果目的地已存在旧文件夹，先清理
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

# 建立后台进程 PID 追踪数组
declare -A PIDS

# 1. 发射整仓克隆任务到后台
for repo in "${!FULL_PROJECTS[@]}"; do
    dir_name="${FULL_PROJECTS[$repo]}"
    clone_full_repo "$repo" "$dir_name" &
    PIDS[$!]="$dir_name (整仓)"
done

# 2. 发射稀疏检出任务到后台
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
