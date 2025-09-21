# CICD工具Linux部署指南

## 概述

本指南提供了如何在Linux服务器上安装和运行CICD自动化部署工具的详细步骤。我们优先推荐使用Docker Compose方式部署，这是最简便且兼容性最好的方法。

## 系统要求

### Docker部署要求
- Linux操作系统（Ubuntu、Debian、CentOS、RHEL等）
- Docker 20.10+ 和 Docker Compose 1.29+
- 至少2GB可用内存
- 至少5GB可用磁盘空间
- 服务器需要开放4567端口

### 传统部署要求
- Linux操作系统
- Ruby 3.2或更高版本
- RubyGems包管理器
- Git客户端
- SSH客户端
- SQLite3数据库
- 网络连接

## Docker Compose部署（推荐）

### 1. 安装Docker和Docker Compose

**Ubuntu/Debian:**
```bash
# 安装Docker
sudo apt-get update
sudo apt-get install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker

# 安装Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.6/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

**CentOS/RHEL:**
```bash
# 安装Docker
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker

# 安装Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.6/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

**验证安装:**
```bash
docker --version
docker-compose --version
```

### 2. 准备项目代码

```bash
# 创建项目目录
mkdir -p /opt/cicd && cd /opt/cicd

# 克隆项目代码
git clone <仓库地址> .
```

### 3. 启动服务

```bash
# 在项目根目录执行
docker-compose up -d

# 查看容器状态
docker-compose ps

# 查看日志
docker-compose logs -f
```

### 4. 访问应用

打开浏览器，访问以下地址：
```
http://your_server_ip:4567
```

使用默认账号登录：
- 用户名：admin
- 密码：admin123
- **首次登录后请及时修改密码**

### 5. 管理服务

```bash
# 停止服务
docker-compose down

# 重启服务
docker-compose restart

# 更新代码后重建镜像
docker-compose up -d --build

# 查看容器日志
docker-compose logs -f
```

## 传统部署方式（备选）

如果您因特殊原因需要在没有Docker的环境中安装，可以参考以下步骤：

### 1. 安装系统依赖

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y build-essential ruby-dev sqlite3 libsqlite3-dev git
sudo gem install bundler -v 2.4.22
```

**CentOS/RHEL:**
```bash
sudo yum install -y gcc gcc-c++ ruby-devel sqlite-devel git
sudo gem install bundler -v 2.4.22
```

### 2. 准备项目代码

```bash
mkdir -p /opt/cicd && cd /opt/cicd
git clone <仓库地址> .
```

### 3. 安装项目依赖

```bash
# 在项目目录中执行
bundle install
```

### 4. 启动应用

**开发模式启动（控制台运行）：**
```bash
./start.sh
```

**后台模式启动：**
```bash
nohup ruby app.rb > cicd.log 2>&1 &
```

**使用Systemd管理（推荐生产环境）：**

创建服务文件：`sudo nano /etc/systemd/system/cicd.service`

```ini
[Unit]
Description=CICD自动化部署工具
After=network.target

[Service]
Type=simple
User=your_username
WorkingDirectory=/opt/cicd
ExecStart=/usr/bin/ruby app.rb
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

启用并启动服务：
```bash
sudo systemctl daemon-reload
sudo systemctl enable cicd
sudo systemctl start cicd

# 查看服务状态
sudo systemctl status cicd
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

### 端口占用问题

如果4567端口已被占用，有两种解决方法：

**Docker部署方式：**
修改`docker-compose.yml`文件中的端口映射：
```yaml
ports:
  - "8080:4567"  # 将8080改为您想要的外部端口
```

**传统部署方式：**
修改`config.json`文件中的端口设置：
```json
{"port": 8080}
```

### 权限问题

如果遇到文件操作权限问题，请确保当前用户有足够的权限：

```bash
# 为项目目录设置适当的权限
sudo chown -R your_username:your_username /opt/cicd
sudo chmod -R 755 /opt/cicd
```

### Docker相关问题

**Docker服务无法启动：**
```bash
sudo systemctl status docker
sudo journalctl -u docker
```

**容器启动失败：**
```bash
docker-compose logs -f
```

### SSH连接问题

确保您的服务器上已安装SSH客户端，并且目标服务器允许SSH连接：

```bash
# 安装SSH客户端
sudo apt-get install openssh-client -y  # Ubuntu/Debian
sudo yum install openssh-clients -y    # CentOS/RHEL
```

## 安全建议

1. **修改默认密码**：登录后立即修改管理员密码
2. **设置防火墙**：限制对4567端口的访问，只允许可信IP访问
   ```bash
   # 使用ufw设置防火墙（Ubuntu/Debian）
   sudo ufw allow from 192.168.1.0/24 to any port 4567
   sudo ufw enable
   
   # 使用firewalld设置防火墙（CentOS/RHEL）
   sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.0/24" port protocol="tcp" port="4567" accept'
   sudo firewall-cmd --reload
   ```
3. **使用HTTPS**：在生产环境中，建议配置HTTPS（可使用Nginx作为反向代理）
4. **定期备份数据库**：Docker部署方式下，数据库数据存储在卷中；传统部署方式下，定期备份app.db文件

## 卸载指南

### Docker部署卸载

```bash
# 停止并删除容器
docker-compose down -v

# 删除项目目录
rm -rf /opt/cicd
```

### 传统部署卸载

```bash
# 停止Systemd服务（如果使用了）
sudo systemctl stop cicd
sudo systemctl disable cicd
sudo rm /etc/systemd/system/cicd.service
sudo systemctl daemon-reload

# 删除项目目录
rm -rf /opt/cicd
```

## 联系方式

如果您在安装过程中遇到任何问题，请参考主目录下的 `README.md` 文件，或联系技术支持获取帮助。