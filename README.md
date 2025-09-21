# Jpom CICD 系统 v2.0 - 重构版

## 🎯 系统概述

基于现代化架构重新设计的持续集成部署系统，采用模块化设计，提供完整的项目生命周期管理功能。

## 🏛️ 架构设计

系统采用四层架构：

1. **访问层** - VUE浏览器界面、HTTP REST API、WebSocket实时通信
2. **服务端** - 工作空间管理、资产管理、系统管理模块
3. **插件层** - Java项目管理器、脚本管理引擎
4. **数据层** - 日志记录系统、权限控制系统

## ✨ 功能特性

- 🏢 **工作空间管理** - 多工作空间隔离、成员管理、权限控制
- 📦 **项目管理** - 多语言支持、自动化构建部署、版本管理
- 🖥️ **资产管理** - 机器资源管理、SSH连接、Docker容器管理
- 👥 **用户权限** - RBAC权限模型、细粒度控制、审计日志
- 📊 **监控日志** - 实时监控、WebSocket推送、性能统计
- 🔧 **脚本管理** - 多语言脚本、模板库、安全检查

## 🛠️ 技术栈

- **后端**: Ruby 3.0+, Sinatra 3.0, Sequel ORM, SQLite3
- **前端**: Haml, HTML5/CSS3, JavaScript, WebSocket
- **工具**: BCrypt, Net-SSH, EventMachine, Puma

## 🚀 快速开始

### 安装依赖

```bash
# 克隆项目
git clone <repository-url> jpom-cicd
cd jpom-cicd

# 一键安装
chmod +x start_refactored.sh
./start_refactored.sh install
```

### 启动系统

```bash
# 开发模式
./start_refactored.sh start development

# 生产模式  
./start_refactored.sh start production
```

### 访问系统

- 地址: http://localhost:4567
- 用户名: `admin`
- 密码: `admin123`

## ⚙️ 配置说明

编辑 `config.json`:

```json
{
  "app_port": 4567,
  "websocket_port": 8080,
  "log_level": "info",
  "temp_dir": "./tmp",
  "docker_support": true
}
```

## 📚 使用指南

### 1. 工作空间管理
- 创建工作空间进行项目分组
- 管理成员权限
- 配置资源访问

### 2. 项目管理  
- 支持Java、Node.js、Python等
- 配置Git/SVN仓库
- 自动化构建和部署

### 3. 资产管理
- 添加服务器资源
- 配置SSH连接
- 管理Docker容器

### 4. 系统管理
- 用户和权限管理
- 系统配置
- 监控和日志

## 🔌 API示例

```bash
# 登录
curl -X POST http://localhost:4567/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'

# 获取项目列表
curl http://localhost:4567/api/projects

# WebSocket连接
ws://localhost:8080?user_id=1&room=general
```

## 👨‍💻 开发指南

### 目录结构
```
├── app_refactored.rb      # 主应用
├── config/               # 配置文件
├── lib/                  # 核心库
│   ├── controllers/      # 控制器
│   ├── models/          # 数据模型
│   ├── services/        # 业务服务
│   ├── plugins/         # 插件
│   └── middleware/      # 中间件
├── views/               # 视图模板
└── public/              # 静态资源
```

### 添加新功能
1. 创建模型 (`lib/models/`)
2. 创建控制器 (`lib/controllers/`)
3. 添加路由 (`app_refactored.rb`)
4. 创建视图 (`views/`)

## 🔧 故障排除

### 常见问题

1. **启动失败**
   ```bash
   # 检查端口占用
   netstat -tuln | grep 4567
   # 查看日志
   tail -f logs/puma.log
   ```

2. **SSH连接失败**
   ```bash
   # 测试连接
   ssh -p 22 user@host
   # 检查密钥权限
   chmod 600 ssh_keys/*.key
   ```

3. **权限问题**
   ```bash
   chmod 700 tmp ssh_keys
   chmod 755 logs backups
   ```

## 📞 支持与贡献

- 问题反馈: 提交Issue
- 功能建议: 创建Feature Request  
- 贡献代码: 提交Pull Request

## 📄 许可证

MIT License - 详见 LICENSE 文件