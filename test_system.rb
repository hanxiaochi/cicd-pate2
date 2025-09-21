# 基本功能测试脚本
require_relative 'config/application'

puts "=== Jpom CICD 系统测试 ==="

# 测试数据库连接
begin
  ApplicationConfig.initialize_database
  puts "✅ 数据库连接成功"
rescue => e
  puts "❌ 数据库连接失败: #{e.message}"
  exit 1
end

# 测试模型
begin
  user_count = User.count
  project_count = Project.count
  puts "✅ 数据模型正常 (用户: #{user_count}, 项目: #{project_count})"
rescue => e
  puts "❌ 数据模型异常: #{e.message}"
end

# 测试管理员用户
begin
  admin = User.find(username: 'admin')
  if admin && admin.authenticate('admin123')
    puts "✅ 管理员账户正常"
  else
    puts "❌ 管理员账户异常"
  end
rescue => e
  puts "❌ 管理员账户测试失败: #{e.message}"
end

# 测试服务类
begin
  LogService.system_log('info', '系统测试运行')
  puts "✅ 日志服务正常"
rescue => e
  puts "❌ 日志服务异常: #{e.message}"
end

begin
  perms = PermissionService.list_user_permissions(1)
  puts "✅ 权限服务正常"
rescue => e
  puts "❌ 权限服务异常: #{e.message}"
end

# 测试配置
begin
  SystemConfig.get_config('app_name', 'Jpom CICD系统')
  puts "✅ 系统配置正常"
rescue => e
  puts "❌ 系统配置异常: #{e.message}"
end

puts "\n=== 测试完成 ==="
puts "如果所有测试通过，可以启动系统："
puts "./start_refactored.sh start"