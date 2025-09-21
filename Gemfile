# Gemfile for Jpom CICD System
source 'https://rubygems.org'

ruby '>= 3.0.0'

# Web框架
gem 'sinatra', '~> 3.0'
gem 'sinatra-flash', '~> 0.3'
gem 'puma', '~> 6.0'

# 模板引擎
gem 'haml', '~> 6.0'

# 数据库
gem 'sequel', '~> 5.0'
gem 'sqlite3', '~> 1.6'

# 认证和安全
gem 'bcrypt', '~> 3.1'

# HTTP客户端
gem 'httparty', '~> 0.21'

# SSH连接
gem 'net-ssh', '~> 7.0'

# WebSocket支持
gem 'websocket-eventmachine-server', '~> 1.0'
gem 'eventmachine', '~> 1.2'

# JSON处理
gem 'json', '~> 2.6'

# 文件处理
gem 'fileutils'

# 系统信息
gem 'sys-filesystem', '~> 1.4'

# 开发和测试依赖
group :development, :test do
  gem 'rake', '~> 13.0'
  gem 'rspec', '~> 3.11'
  gem 'rack-test', '~> 2.0'
  gem 'factory_bot', '~> 6.2'
  gem 'faker', '~> 3.0'
end

# 生产环境依赖
group :production do
  gem 'foreman', '~> 0.87'
end