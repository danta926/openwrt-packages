#!/bin/bash

# 创建临时存放插件的目录
mkdir -p package/plugins
cd package/plugins

# 同步 OpenClash
git clone --depth 1 https://github.com/vernesong/OpenClash.git
rm -rf ./OpenClash/.git # 删除 git 信息，使其成为你仓库的一部分

# 同步 DDNS-Go
git clone --depth 1 https://github.com/jeessy2/ddns-go.git
rm -rf ./ddns-go/.git

# ... 继续添加其他项目
