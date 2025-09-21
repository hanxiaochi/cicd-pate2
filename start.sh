#!/bin/bash

# 设置UTF-8编码
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

echo "==================================="
echo "  CICD工具启动脚本 (Linux版本)       "
echo "==================================="

# 检查Ruby是否安装
if ! command -v ruby &> /dev/null
then
    echo "错误: 未找到Ruby。请先安装Ruby 3.0或更高版本。"
    echo "Ubuntu/Debian: sudo apt-get install ruby-full"
    echo "CentOS/RHEL: sudo yum install ruby"
    echo "其他Linux发行版请参考官方文档"
    exit 1
fi

# 检查Ruby版本
RUBY_VERSION=$(ruby -e "puts RUBY_VERSION")
RUBY_MAJOR=$(echo $RUBY_VERSION | cut -d. -f1)
RUBY_MINOR=$(echo $RUBY_VERSION | cut -d. -f2)

if [ $RUBY_MAJOR -lt 3 ] || ([ $RUBY_MAJOR -eq 3 ] && [ $RUBY_MINOR -lt 0 ])
then
    echo "警告: 当前Ruby版本为 $RUBY_VERSION，建议使用Ruby 3.0或更高版本。"
fi

# 检查bundler是否安装
if ! command -v bundle &> /dev/null
then
    echo "正在安装bundler..."
    gem install bundler --no-document
    if [ $? -ne 0 ]
    then
        echo "错误: bundler安装失败，请使用以下命令手动安装:"
        echo "sudo gem install bundler --no-document"
        exit 1
    fi
fi

# 安装依赖
echo "正在安装项目依赖..."
bundle install
if [ $? -ne 0 ]
then
    echo "错误: 依赖安装失败，请检查网络连接或Gemfile配置。"
    exit 1
fi

# 创建所需目录
echo "正在创建必要的目录..."
mkdir -p views public tmp

# 启动应用
echo "\n正在启动CICD工具..."
echo "请确保端口4567未被占用"
echo "应用将在 http://localhost:4567 运行"
echo "按Ctrl+C停止应用"
echo "==================================="
echo ""

# 使用nohup后台运行（可选，取消下面的注释并注释掉直接运行的代码）
# nohup ruby app.rb > cicd.log 2>&1 &
# echo "应用已在后台启动，日志文件: cicd.log"
# echo "使用 'ps aux | grep ruby' 查看进程"
# echo "使用 'kill -9 进程ID' 停止应用"

# 直接运行（开发模式）
ruby app.rb