#!/bin/bash

# 1. 声明普通的、需要整仓克隆的项目 (格式: ["远程仓库地址"]="本地文件夹名")
declare -A PROJECTS=(
    ["https://github.com/vernesong/OpenClash"]="luci-app-openclash"
    ["https://github.com/sirpdboy/luci-app-ddns-go"]="luci-app-ddns-go"
    ["https://github.com/ophub/luci-app-amlogic"]="luci-app-amlogic"
    ["https://github.com/jerrykuku/luci-theme-argon"]="luci-theme-argon"
    ["https://github.com/jerrykuku/luci-app-argon-config"]="luci-app-argon-config"
)

echo "开始清理旧文件..."
# 仅保留 .git, .github 和 脚本本身，删除其他所有根目录下的文件夹和文件
find . -maxdepth 1 ! -name '.' ! -name '..' ! -name '.git' ! -name '.github' ! -name 'sync.sh' -exec rm -rf {} +

echo "开始同步普通整仓插件到根目录..."
for repo in "${!PROJECTS[@]}"; do
    dir_name="${PROJECTS[$repo]}"
    echo "------------------------------------------"
    echo "正在克隆: $dir_name"
    
    git clone --depth 1 "$repo" "$dir_name"
    
    if [ -d "$dir_name" ]; then
        rm -rf "$dir_name/.git" "$dir_name/.github"
        echo "✅ $dir_name 已就绪"
    else
        echo "❌ $dir_name 克隆失败"
    fi
done

echo "------------------------------------------"
echo "开始拉取 immortalwrt v25.12.0 的 emortal 文件夹..."

# 1. 创建一个临时的裸仓库目录，并进入
mkdir -p .tmp_immortalwrt && cd .tmp_immortalwrt

# 2. 初始化 git 并开启稀疏检出（只下载指定文件夹的核心功能）
git init -q
git config core.sparseCheckout true

# 3. 设置只下载 package/emortal 目录
echo "package/emortal" >> .git/info/sparse-checkout

# 4. 添加远程源并拉取指定分支（使用 --depth 1 极大限度减少下载量）
git remote add origin https://github.com/immortalwrt/immortalwrt
git pull origin v25.12.0 --depth 1 -q

# 5. 回到上级根目录，将下载下来的插件平铺移出来
cd ..
if [ -d ".tmp_immortalwrt/package/emortal" ]; then
    # 把 emortal 目录下的所有子插件移到根目录
    mv .tmp_immortalwrt/package/emortal/* ./
    echo "✅ emortal 文件夹内的核心插件已成功提取并平铺！"
else
    echo "❌ emortal 文件夹同步失败，请检查网络！"
fi

# 6. 清理临时遗留的隐藏文件和文件夹
rm -rf .tmp_immortalwrt

echo "------------------------------------------"
echo "所有插件已成功平铺在根目录！"
exit 0
