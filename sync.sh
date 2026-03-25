#!/bin/bash

# 1. 声明需要同步的项目 (格式: "远程仓库地址" "本地文件夹名")
# 你可以在这里自由添加更多项目
declare -A PROJECTS=(
    ["https://github.com/vernesong/OpenClash"]="luci-app-openclash"
    ["https://github.com/sirpdboy/luci-app-ddns-go"]="luci-app-ddns-go"
)

echo "开始清理旧文件..."
# 仅保留 .git, .github 和 脚本本身，删除其他所有根目录下的文件夹和文件
find . -maxdepth 1 ! -name '.' ! -name '..' ! -name '.git' ! -name '.github' ! -name 'sync.sh' -exec rm -rf {} +

echo "开始同步插件到根目录..."

for repo in "${!PROJECTS[@]}"; do
    dir_name="${PROJECTS[$repo]}"
    echo "------------------------------------------"
    echo "正在克隆: $dir_name"
    
    # 克隆项目到指定名称的文件夹
    git clone --depth 1 "$repo" "$dir_name"
    
    # 移除插件内部的 .git 信息，防止 git 嵌套冲突
    if [ -d "$dir_name" ]; then
        rm -rf "$dir_name/.git"
        rm -rf "$dir_name/.github"
        echo "✅ $dir_name 已就绪"
    else
        echo "❌ $dir_name 克隆失败"
    fi
done

echo "------------------------------------------"
echo "所有插件已平铺在根目录！"
