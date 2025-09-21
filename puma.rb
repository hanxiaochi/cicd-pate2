# Puma配置文件

# 设置最小和最大线程数
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
threads threads_count, threads_count

# 指定Puma使用的端口
port ENV.fetch("PORT") { 4567 }

# 指定环境
environment ENV.fetch("RACK_ENV") { "development" }

# 指定工作进程数 (生产环境推荐)
if ENV["RACK_ENV"] == "production"
  workers ENV.fetch("WEB_CONCURRENCY") { 2 }
  
  # 在fork worker进程之前运行的代码
  preload_app!
  
  # 允许puma在重启时不丢失连接
  plugin :tmp_restart
end

# 指定PID文件位置
pidfile "tmp/puma.pid"

# 指定状态文件位置
state_path "tmp/puma.state"

# 指定日志文件
stdout_redirect "logs/puma.log", "logs/puma_error.log", true

# 在生产环境中后台运行
if ENV["RACK_ENV"] == "production"
  daemonize true
end

# 绑定到Unix socket (可选)
# bind "unix://tmp/puma.sock"

# 设置最大payload大小 (默认是无限制)
# max_request_size 16777216

# SSL配置 (如果需要HTTPS)
# ssl_bind "0.0.0.0", "8443", {
#   key: "path/to/server.key",
#   cert: "path/to/server.crt"
# }

# 工作目录
directory File.expand_path(".", __FILE__)

# 优雅关闭的超时时间
worker_timeout 30

# 在worker boot时执行的代码
on_worker_boot do
  # Worker特定的初始化代码
end

# 在worker shutdown时执行的代码
on_worker_shutdown do
  # 清理工作
end

# 在重启时执行的代码
on_restart do
  puts "Puma is restarting..."
end

# 在启动时执行的代码
on_booted do
  puts "Puma is booted and ready to serve requests"
end