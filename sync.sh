#!/bin/bash
set -euo pipefail  # 出错即停、未定义变量报错、管道错误传递

# ==================== 配置区 ====================
# 声明普通整仓项目 (地址 -> 本地目录名)
declare -A FULL_PROJECTS=(
    ["https://github.com/vernesong/OpenClash"]="luci-app-openclash"
    ["https://github.com/ophub/luci-app-amlogic"]="luci-app-amlogic"
    ["https://github.com/jerrykuku/luci-theme-argon"]="luci-theme-argon"
    ["https://github.com/jerrykuku/luci-app-argon-config"]="luci-app-argon-config"
    ["https://github.com/lisaac/luci-app-diskman"]="luci-app-diskman"
)

# 定义需要稀疏检出的仓库 (仓库URL 分支 要提取的目录/文件列表 目标本地目录)
# 格式：["仓库URL 分支"]="路径1 路径2 ... -> 目标目录"
declare -A SPARSE_ITEMS=(
    ["https://github.com/immortalwrt/immortalwrt v25.12.0"]="package/emortal -> emortal"
    ["https://github.com/kenzok8/openwrt-packages master"]="ddns-go luci-app-ddns-go luci-app-dockerman -> ."
    ["https://github.com/immortalwrt/luci openwrt-24.10"]="applications/luci-app-hd-idle applications/luci-app-samba4 -> ."
)

# ==================== 函数定义 ====================
# 普通全量克隆（整仓）
clone_full_repo() {
    local repo="$1"
    local target="$2"
    echo "克隆全仓: $target"
    git clone --depth 1 "$repo" "$target"
    if [[ -d "$target" ]]; then
        rm -rf "$target/.git" "$target/.github"
        echo "✅ $target 已就绪"
    else
        echo "❌ $target 克隆失败"
        return 1
    fi
}

# 稀疏检出并移动到指定位置
# 参数: repo_url branch "path1 path2 ..." target_dir
sparse_checkout() {
    local repo="$1"
    local branch="$2"
    local paths="$3"      # 空格分隔的路径列表（相对于仓库根）
    local target_dir="$4"

    local tmp_dir
    tmp_dir=$(mktemp -d -t "sparse_$(basename "$repo")_XXXXXX")
    echo "稀疏检出: ${target_dir:-根目录} <- ${paths} (from $repo $branch)"

    pushd "$tmp_dir" > /dev/null
    git init -q
    git config core.sparseCheckout true
    # 写入所有需要检出的路径
    for p in $paths; do
        echo "$p" >> .git/info/sparse-checkout
    done
    git remote add origin "$repo"
    git pull origin "$branch" --depth 1 -q
    popd > /dev/null

    # 移动结果到目标目录
    if [[ "$target_dir" == "." ]]; then
        # 平铺到当前根目录
        for p in $paths; do
            local src_path="$tmp_dir/$p"
            local basename=$(basename "$p")
            if [[ -e "$src_path" ]]; then
                mv "$src_path" "./$basename"
                echo "✅ 移动 ./$basename"
            else
                echo "❌ 未找到 $p"
            fi
        done
    else
        # 移动到指定子目录（如 emortal）
        mkdir -p "$target_dir"
        for p in $paths; do
            local src_path="$tmp_dir/$p"
            if [[ -e "$src_path" ]]; then
                cp -r "$src_path/"* "$target_dir/" 2>/dev/null || \
                cp -r "$src_path" "$target_dir/"
                echo "✅ 已复制 $p 内容到 $target_dir"
            else
                echo "❌ 未找到 $p"
            fi
        done
    fi

    rm -rf "$tmp_dir"
}

# ==================== 主流程 ====================
# 清理旧文件（保留 .git .github 和本脚本）
echo "开始清理旧文件..."
find . -maxdepth 1 ! -name '.' ! -name '..' \
    ! -name '.git' ! -name '.github' \
    ! -name "$(basename "$0")" -exec rm -rf {} +

# 1. 处理全量克隆项目
echo "开始同步普通整仓插件..."
for repo in "${!FULL_PROJECTS[@]}"; do
    dir_name="${FULL_PROJECTS[$repo]}"
    echo "------------------------------------------"
    clone_full_repo "$repo" "$dir_name"
done

# 2. 处理所有稀疏检出项目
for key in "${!SPARSE_ITEMS[@]}"; do
    IFS=' ' read -r repo branch <<< "$key"
    target_spec="${SPARSE_ITEMS[$key]}"
    # 解析 "路径列表 -> 目标目录"
    paths_part="${target_spec% -> *}"
    target_part="${target_spec#* -> }"
    echo "------------------------------------------"
    sparse_checkout "$repo" "$branch" "$paths_part" "$target_part"
done

echo "------------------------------------------"
echo "所有插件处理完毕！"
exit 0
