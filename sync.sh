#!/bin/bash

# 配置 Git 用户信息（Action 环境必需）
git config --local user.email "action@github.com"
git config --local user.name "GitHub Action"

# 定义同步函数
# 参数1: 项目GitHub路径, 参数2: 分支
function merge_to_root() {
    REPO_URL="https://github.com/$1.git"
    BRANCH=$2
    REPO_NAME=$(echo $1 | cut -d'/' -f2)

    echo "正在合并 $REPO_NAME 的内容到根目录..."
    
    # 添加远程仓库
    git remote add -f $REPO_NAME $REPO_URL
    
    # 强制将远程分支的内容拉取并合并到当前根目录
    # --allow-unrelated-histories 是关键，允许合并完全不同的项目
    # -X theirs 表示如果文件冲突（如 README），以上游项目为准
    git merge $REPO_NAME/$BRANCH --allow-unrelated-histories -X theirs --no-commit
    
    # 清理远程引用防止冲突
    git remote remove $REPO_NAME
}

# --- 在这里添加你想合并的项目 ---
# 注意：如果两个项目都有 Makefile，后合并的会覆盖先合并的
merge_to_root "vernesong/OpenClash" "master"
merge_to_root "jeessy2/ddns-go" "master"

# 合并后手动清理掉不需要的文件夹（可选）
rm -rf .gitattributes .github
