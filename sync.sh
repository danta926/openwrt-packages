#!/bin/bash

# 1. 声明普通的、需要整仓克隆的项目 (格式: ["远程仓库地址"]="本地文件夹名")
declare -A PROJECTS=(
    ["https://github.com/vernesong/OpenClash"]="luci-app-openclash"
    ["https://github.com/sirpdboy/luci-app-ddns-go"]="luci-app-ddns-go"
    ["https://github.com/ophub/luci-app-amlogic"]="luci-app-amlogic"
    ["https://github.com/jerrykuku/luci-theme-argon"]="luci-theme-argon"
    ["https://github.com/jerrykuku/luci-app-argon-config"]="luci-app-argon-config"
)

# 2. 声明需要提取“大仓库中某个子文件夹并平铺”的项目
# 格式: 远程仓库地址 | 分支或Tag | 子文件夹路径
# 这里配置的就是你要的 immortalwrt 25.12.0 的 emortal 核心组件包
SUB_PROJECTS=(
    "https://github.com/immortalwrt/immortalwrt|v25.12.0|package/emortal"
)

echo "开始清理旧文件..."
# 仅保留 .git, .github 和 脚本本身，删除其他所有根目录下的文件夹和文件
find . -maxdepth 1 ! -name '.' ! -name '..' ! -name '.git' ! -name '.github' ! -name 'sync.sh' -exec rm -rf {} +

echo "开始同步普通整仓插件到根目录..."
for repo in "${!PROJECTS[@]}"; do
    dir_name="${PROJECTS[$repo]}"
    echo "------------------------------------------"
    echo "正在克隆: $dir_name"
    
    # 克隆项目到指定名称的文件夹
    git clone --depth 1 "$repo" "$dir_name"
    
    # 移除插件内部的 .git 信息，防止 git 嵌套冲突
    if [ -d "$dir_name" ]; then
        rm -rf "$dir_name/.git" "$dir_name/.github"
        echo "✅ $dir_name 已就绪"
    else
        echo "❌ $dir_name 克隆失败"
    fi
done

echo "------------------------------------------"
echo "开始提取大仓库指定分支的子文件夹..."

for item in "${SUB_PROJECTS[@]}"; do
    # 解析仓库地址、分支和子路径
    IFS="|" read -r url branch sub_path <<< "$item"
    
    echo "------------------------------------------"
    echo "正在从 $url ($branch) 提取 $sub_path ..."
    
    # 创建一个临时目录用来接收数据
    mkdir -p .tmp_extract
    
    # 利用 git archive 远程下载指定分支下的指定目录（格式为 tar 包，不带任何历史记录，速度极快）
    git archive --remote="$url" "$branch" "$sub_path" | tar -x -C .tmp_extract
    
    # 检查是否成功下载
    if [ -d ".tmp_extract/$sub_path" ]; then
        # 将子文件夹内的所有核心插件（如 luci-app-xxx）移动、平铺到当前根目录
        mv .tmp_extract/$sub_path/* ./
        echo "✅ $sub_path 内的所有核心插件已成功提取并平铺！"
    else
        echo "❌ $sub_path 提取失败，请检查网络或分支/路径是否正确"
    fi
    
    # 清理临时目录
    rm -rf .tmp_extract
done

echo "------------------------------------------"
echo "所有插件已成功平铺在根目录！"
exit 0
