# CICD工具详细安装指南

## 目录

- [Docker部署（推荐）](#docker部署推荐)
  - [前提条件](#前提条件)
  - [部署步骤](#部署步骤)
  - [Docker Compose配置说明](#docker-compose配置说明)
  - [自定义Docker配置](#自定义docker配置)
- [手动安装](#手动安装)
  - [前提条件](#前提条件-1)
  - [Linux系统安装步骤](#linux系统安装步骤)
  - [MacOS系统安装步骤](#macos系统安装步骤)
  - [验证安装](#验证安装)
- [启动应用](#启动应用)
  - [使用Docker Compose启动](#使用docker-compose启动)
  - [手动启动](#手动启动-1)
- [Docker支持](#docker支持)
  - [Docker服务安装](#docker服务安装)
  - [Docker Compose安装](#docker-compose安装)
- [配置文件](#配置文件)
- [常见问题解决](#常见问题解决)
- [联系方式](#联系方式)

## Docker部署（推荐）

使用Docker Compose是部署此工具的最简单方法，适用于所有主流操作系统。

### 前提条件

- 已安装Docker 20.10+ 和 Docker Compose 1.29+
- 服务器需要开放4567端口
- 至少2GB可用内存
- 至少5GB可用磁盘空间

### 部署步骤

#### 1. 准备项目目录

```bash
# 创建项目目录
mkdir -p /opt/cicd && cd /opt/cicd

# 克隆仓库代码
# 如果您是从本地复制代码，请跳过此步骤
git clone <仓库地址> .
```

#### 2. 使用Docker Compose启动

```bash
# 在项目根目录执行以下命令
docker-compose up -d

# 查看容器状态
docker-compose ps

# 查看日志
docker-compose logs -f
```

#### 3. 访问系统

打开浏览器，访问 `http://服务器IP:4567`

默认账号：admin / admin123

首次登录后请及时修改密码。

#### 4. 停止和重启

```bash
# 停止服务
docker-compose down

# 重启服务
docker-compose restart

# 重建镜像并启动（当代码更新时）
docker-compose up -d --build
```

### Docker Compose配置说明

默认的`docker-compose.yml`配置文件包含以下内容：

```yaml
version: '3.8'

services:
  web:
    build: .
    ports:
      - "4567:4567"
    volumes:
      - .:/app
      - db_data:/app/db
    environment:
      - RACK_ENV=production
      - SINATRA_ENV=production
    restart: unless-stopped
    command: puma -p 4567 app.rb

volumes:
  db_data:
```

### 自定义Docker配置

您可以根据需要调整`docker-compose.yml`文件：

1. **修改端口映射**：将`4567:4567`中的第一个数字改为您想要的外部端口

2. **调整资源限制**：添加`deploy`部分以限制资源使用

```yaml
web:
  # ...其他配置
  deploy:
    resources:
      limits:
        cpus: '1.0'
        memory: 1G
      reservations:
        cpus: '0.5'
        memory: 512M
```

## 手动安装

如果您需要在没有Docker的环境中安装，可以按照以下步骤操作。

### 前提条件

- Ruby 3.2+ 环境
- SQLite3 3.30+ 数据库
- Git 2.0+ 版本控制系统
- 网络连接（用于下载依赖）

### Linux系统安装步骤

#### 1. 安装必要的系统依赖

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y build-essential ruby-dev sqlite3 libsqlite3-dev git

# CentOS/RHEL
sudo yum install -y gcc gcc-c++ ruby-devel sqlite-devel git
```

#### 2. 安装Ruby和Bundler

```bash
# 安装Ruby（如果尚未安装）
sudo gem install bundler -v 2.4.22
```

#### 3. 克隆项目代码

```bash
mkdir -p /opt/cicd && cd /opt/cicd
git clone <仓库地址> .
```

#### 4. 安装项目依赖

```bash
# 确保在项目目录中
bundle install
```

### MacOS系统安装步骤

#### 1. 安装Homebrew

如果您尚未安装Homebrew，请先安装：

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

#### 2. 安装必要的依赖

```bash
brew install ruby sqlite3 git
```

#### 3. 安装Bundler

```bash
gem install bundler -v 2.4.22
```

#### 4. 克隆项目代码

```bash
mkdir -p /opt/cicd && cd /opt/cicd
git clone <仓库地址> .
```

#### 5. 安装项目依赖

```bash
# 确保在项目目录中
bundle install
```

### 验证安装

```bash
# 检查Ruby版本
ruby -v

# 检查Bundler版本
bundle -v

# 检查项目依赖是否已正确安装
bundle list
```

## 启动应用

### 使用Docker Compose启动

```bash
cd /opt/cicd
docker-compose up -d
```

### 手动启动

#### 1. 使用Puma启动（生产环境推荐）

```bash
cd /opt/cicd
bundle exec puma -p 4567 -e production app.rb
```

#### 2. 使用Rackup启动

```bash
cd /opt/cicd
bundle exec rackup -p 4567 config.ru
```

#### 3. 直接使用Ruby启动

```bash
cd /opt/cicd
ruby app.rb
```

## Docker支持

如果您需要使用Docker相关功能，需要在目标服务器上安装Docker和Docker Compose。

### Docker服务安装

#### Ubuntu/Debian

```bash
sudo apt-get update
sudo apt-get install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker
```

#### CentOS/RHEL

```bash
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
```

#### 验证Docker安装

```bash
docker --version
sudo docker run hello-world
```

### Docker Compose安装

```bash
sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.6/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose --version
```

## 配置文件

项目的配置文件为根目录下的`config.json`，您可以根据需要修改以下配置：

```json
{
  "port": 4567,                // 服务端口
  "host": "0.0.0.0",          // 监听地址
  "database": "app.db",       // 数据库文件
  "session_secret": "random_secret_key",  // 会话密钥
  "temp_dir": "./tmp"          // 临时目录
}
```

## 常见问题解决

### 1. 中文显示乱码

**解决方法**：
- 在Linux/MacOS系统中，确保环境变量`LANG`设置为`en_US.UTF-8`或`zh_CN.UTF-8`
- 检查终端编码是否为UTF-8

### 2. 远程连接问题

**解决方法**：
- 检查服务器防火墙是否开放了4567端口
- 确保应用监听地址设置为`0.0.0.0`（可在config.json中修改）
- 检查网络连接是否正常

### 3. 数据库连接错误

**解决方法**：
- 确保SQLite3已正确安装
- 检查数据库文件权限是否正确
- 检查项目目录是否有写入权限

### 4. Docker相关问题

**解决方法**：
- 确保Docker服务正在运行
- 检查Docker Compose版本是否兼容
- 查看Docker日志以获取详细错误信息

## 联系方式

如果您在安装过程中遇到任何问题，请提交issue或联系技术支持。