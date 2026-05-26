#!/bin/bash

# 1. 声明普通的、需要整仓克隆的项目 (格式: ["远程仓库地址"]="本地文件夹名")
declare -A PROJECTS=(
    ["https://github.com/vernesong/OpenClash"]="luci-app-openclash"
    ["https://github.com/ophub/luci-app-amlogic"]="luci-app-amlogic"
    ["https://github.com/jerrykuku/luci-theme-argon"]="luci-theme-argon"
    ["https://github.com/jerrykuku/luci-app-argon-config"]="luci-app-argon-config"
    ["https://github.com/lisaac/luci-app-diskman"]="luci-app-diskman"
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

# 创建临时的裸仓库目录，并进入
mkdir -p .tmp_immortalwrt && cd .tmp_immortalwrt
git init -q
git config core.sparseCheckout true
echo "package/emortal" >> .git/info/sparse-checkout
git remote add origin https://github.com/immortalwrt/immortalwrt
git pull origin v25.12.0 --depth 1 -q
cd ..

# 提取并移动
if [ -d ".tmp_immortalwrt/package/emortal" ]; then
    mkdir -p emortal
    mv .tmp_immortalwrt/package/emortal/* ./emortal/
    echo "✅ emortal 文件夹内的核心插件已成功提取并平铺在 ./emortal/ 目录中！"
else
    echo "❌ emortal 文件夹同步失败，请检查网络！"
fi
rm -rf .tmp_immortalwrt


echo "------------------------------------------"
echo "开始按需拉取 kenzok8 中的插件并【平铺到根目录】..."

# 1. 创建临时区
mkdir -p .tmp_kenzok8 && cd .tmp_kenzok8
git init -q
git config core.sparseCheckout true

# 2. 写入要拉取的三个插件
echo "ddns-go" >> .git/info/sparse-checkout
echo "luci-app-ddns-go" >> .git/info/sparse-checkout
echo "luci-app-dockerman" >> .git/info/sparse-checkout

# 3. 拉取核心数据
git remote add origin https://github.com/kenzok8/openwrt-packages
git pull origin master --depth 1 -q
cd ..

# 4. 核心：直接【平铺移动到当前根目录】
for folder in "ddns-go" "luci-app-ddns-go" "luci-app-dockerman"; do
    if [ -d ".tmp_kenzok8/$folder" ]; then
        # mv 到 ./ 即代表当前脚本所在的根目录
        mv ".tmp_kenzok8/$folder" ./
        echo "✅ [根目录] $folder 已经成功平铺到根目录！"
    else
        echo "❌ [失败] 未能提取到 $folder，请检查网络或仓库目录名"
    fi
done

# 5. 清理临时缓存
rm -rf .tmp_kenzok8


echo "------------------------------------------"
echo "所有插件处理完毕！"
exit 0
