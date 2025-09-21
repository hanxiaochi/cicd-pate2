# 系统管理控制器
class SystemController < BaseController
  # 系统管理首页
  def index
    admin_required
    
    system_info = {
      server_info: get_server_info,
      database_info: get_database_info,
      storage_info: get_storage_info,
      service_status: get_service_status,
      recent_logs: get_recent_system_logs
    }

    if request.accept.include?('application/json')
      success_response('获取系统信息成功', system_info)
    else
      @system_info = system_info
      haml :'system/index'
    end
  end

  # 用户管理
  def users
    admin_required
    
    page_params = paginate_params
    
    # 过滤条件
    filters = {}
    filters[:role] = params[:role] if params[:role] && !params[:role].empty?
    filters[:active] = params[:active] == 'true' if params[:active]
    
    # 搜索
    users_dataset = User.where(filters)
    if params[:search] && !params[:search].empty?
      search_term = "%#{params[:search]}%"
      users_dataset = users_dataset.where(
        Sequel.|(
          { username: search_term },
          { email: search_term },
          { department: search_term }
        )
      )
    end

    users = users_dataset.order(:username)
                        .paginate(**page_params)
                        .map do |user|
      user.to_hash.tap { |h| h.delete(:password_hash) }
    end

    if request.accept.include?('application/json')
      success_response('获取用户列表成功', {
        users: users,
        pagination: {
          page: page_params[:page],
          per_page: page_params[:per_page],
          total: users_dataset.count
        }
      })
    else
      @users = users
      @filters = { role: params[:role], active: params[:active], search: params[:search] }
      haml :'system/users'
    end
  end

  # 创建用户页面
  def new_user
    admin_required
    haml :'system/new_user'
  end

  # 创建用户
  def create_user
    admin_required
    validate_params([:username, :password])

    user_data = {
      username: params[:username],
      password_hash: BCrypt::Password.create(params[:password]),
      role: params[:role] || 'user',
      email: params[:email],
      phone: params[:phone],
      department: params[:department],
      active: params[:active] != 'false'
    }

    begin
      user = User.create(user_data)
      
      log_action('创建用户', { user_id: user.id, username: user.username })

      if request.accept.include?('application/json')
        user_hash = user.to_hash.tap { |h| h.delete(:password_hash) }
        success_response('用户创建成功', user_hash)
      else
        flash[:success] = '用户创建成功'
        redirect '/system/users'
      end
    rescue Sequel::ValidationFailed => e
      if request.accept.include?('application/json')
        error_response("创建失败: #{e.message}")
      else
        flash[:error] = "创建失败: #{e.message}"
        redirect '/system/users/new'
      end
    end
  end

  # 用户详情
  def user_detail
    admin_required
    user = User[params[:id]]
    
    unless user
      if request.accept.include?('application/json')
        return error_response('用户不存在', 404)
      else
        flash[:error] = '用户不存在'
        return redirect '/system/users'
      end
    end

    # 获取用户权限
    permissions = Permission.where(user_id: user.id)
                           .join(:users, id: :user_id)
                           .all

    # 获取用户操作日志
    user_logs = Log.where(user_id: user.id)
                  .order(Sequel.desc(:created_at))
                  .limit(50)
                  .all

    user_data = user.to_hash.tap { |h| h.delete(:password_hash) }
    user_data.merge!(
      permissions: permissions.map(&:to_hash),
      recent_logs: user_logs.map(&:to_hash),
      projects_count: user.projects.count
    )

    if request.accept.include?('application/json')
      success_response('获取用户详情成功', user_data)
    else
      @user_data = user_data
      haml :'system/user_detail'
    end
  end

  # 更新用户
  def update_user
    admin_required
    user = User[params[:id]]
    
    unless user
      return error_response('用户不存在', 404)
    end

    # 不允许修改超级管理员
    if user.username == 'admin' && current_user.id != user.id
      return error_response('不能修改超级管理员信息')
    end

    allowed_fields = [:role, :email, :phone, :department, :active]
    update_data = params.select { |k, v| allowed_fields.include?(k.to_sym) }
    
    # 处理密码更新
    if params[:password] && !params[:password].empty?
      update_data[:password_hash] = BCrypt::Password.create(params[:password])
    end

    begin
      user.update(update_data)
      
      log_action('更新用户信息', { user_id: user.id, changes: update_data.keys })

      success_response('用户信息更新成功')
    rescue Sequel::ValidationFailed => e
      error_response("更新失败: #{e.message}")
    end
  end

  # 删除用户
  def delete_user
    admin_required
    user = User[params[:id]]
    
    unless user
      return error_response('用户不存在', 404)
    end

    # 不允许删除超级管理员和自己
    if user.username == 'admin'
      return error_response('不能删除超级管理员')
    end

    if user.id == current_user.id
      return error_response('不能删除自己')
    end

    # 检查用户是否有关联项目
    if user.projects.count > 0
      return error_response('用户有关联项目，无法删除')
    end

    username = user.username
    user.destroy

    log_action('删除用户', { username: username })
    success_response('用户删除成功')
  end

  # 系统配置
  def configs
    admin_required
    
    configs = SystemConfig.order(:config_key).all.map(&:to_hash)
    
    if request.accept.include?('application/json')
      success_response('获取系统配置成功', { configs: configs })
    else
      @configs = configs
      haml :'system/configs'
    end
  end

  # 更新系统配置
  def update_config
    admin_required
    validate_params([:config_key, :config_value])
    
    config = SystemConfig.find_or_create(config_key: params[:config_key]) do |c|
      c.config_value = params[:config_value]
      c.config_type = params[:config_type] || 'string'
      c.description = params[:description]
    end
    
    config.update(
      config_value: params[:config_value],
      config_type: params[:config_type] || config.config_type,
      description: params[:description] || config.description
    )

    log_action('更新系统配置', { config_key: params[:config_key] })
    success_response('配置更新成功')
  end

  # 删除配置
  def delete_config
    admin_required
    config = SystemConfig[params[:id]]
    
    unless config
      return error_response('配置不存在', 404)
    end

    # 不允许删除系统配置
    if config.is_system
      return error_response('不能删除系统配置')
    end

    config_key = config.config_key
    config.destroy

    log_action('删除系统配置', { config_key: config_key })
    success_response('配置删除成功')
  end

  # 系统监控
  def monitor
    admin_required
    
    monitor_data = {
      cpu_usage: get_cpu_usage,
      memory_usage: get_memory_usage,
      disk_usage: get_disk_usage,
      network_stats: get_network_stats,
      process_count: get_process_count,
      active_connections: get_active_connections,
      timestamp: Time.now.to_i
    }

    if request.accept.include?('application/json')
      success_response('获取监控数据成功', monitor_data)
    else
      @monitor_data = monitor_data
      haml :'system/monitor'
    end
  end

  # 日志管理
  def logs
    admin_required
    
    page_params = paginate_params
    
    # 过滤条件
    filters = {}
    filters[:log_type] = params[:log_type] if params[:log_type] && !params[:log_type].empty?
    filters[:level] = params[:level] if params[:level] && !params[:level].empty?
    
    # 时间范围
    if params[:start_date] && params[:end_date]
      start_time = Date.parse(params[:start_date]).to_time
      end_time = Date.parse(params[:end_date]).to_time + 86400 # 加一天
      filters[:created_at] = start_time..end_time
    end

    logs_dataset = Log.where(filters)
    logs = logs_dataset.order(Sequel.desc(:created_at))
                      .paginate(**page_params)
                      .map(&:to_hash)

    if request.accept.include?('application/json')
      success_response('获取日志列表成功', {
        logs: logs,
        pagination: {
          page: page_params[:page],
          per_page: page_params[:per_page],
          total: logs_dataset.count
        }
      })
    else
      @logs = logs
      @filters = { 
        log_type: params[:log_type], 
        level: params[:level],
        start_date: params[:start_date],
        end_date: params[:end_date]
      }
      haml :'system/logs'
    end
  end

  # 清理日志
  def clean_logs
    admin_required
    
    days = (params[:days] || 30).to_i
    cutoff_date = Time.now - (days * 24 * 60 * 60)
    
    deleted_count = Log.where('created_at < ?', cutoff_date).delete
    
    log_action('清理系统日志', { days: days, deleted_count: deleted_count })
    success_response("日志清理完成，删除了 #{deleted_count} 条记录")
  end

  # 在线升级
  def upgrade
    admin_required
    haml :'system/upgrade'
  end

  # 检查更新
  def check_update
    admin_required
    
    begin
      # 这里可以连接到更新服务器检查版本
      current_version = get_current_version
      latest_version = get_latest_version
      
      update_available = version_compare(latest_version, current_version) > 0
      
      success_response('检查更新完成', {
        current_version: current_version,
        latest_version: latest_version,
        update_available: update_available
      })
    rescue => e
      error_response("检查更新失败: #{e.message}")
    end
  end

  # 执行升级
  def perform_upgrade
    admin_required
    
    # 这里实现升级逻辑
    begin
      log_action('开始系统升级')
      
      # 1. 备份当前版本
      backup_current_version
      
      # 2. 下载新版本
      download_new_version
      
      # 3. 执行升级脚本
      execute_upgrade_script
      
      log_action('系统升级完成')
      success_response('升级完成，请重启系统')
    rescue => e
      log_action('系统升级失败', { error: e.message })
      error_response("升级失败: #{e.message}")
    end
  end

  # 系统备份
  def backup
    admin_required
    
    begin
      backup_file = create_system_backup
      
      log_action('创建系统备份', { backup_file: backup_file })
      success_response('备份创建成功', { backup_file: backup_file })
    rescue => e
      error_response("备份失败: #{e.message}")
    end
  end

  # 系统还原
  def restore
    admin_required
    validate_params([:backup_file])
    
    unless File.exist?(params[:backup_file])
      return error_response('备份文件不存在')
    end

    begin
      restore_from_backup(params[:backup_file])
      
      log_action('恢复系统备份', { backup_file: params[:backup_file] })
      success_response('系统还原成功')
    rescue => e
      error_response("还原失败: #{e.message}")
    end
  end

  private

  def get_server_info
    {
      hostname: `hostname`.strip,
      os: `uname -s`.strip,
      kernel: `uname -r`.strip,
      architecture: `uname -m`.strip,
      uptime: `uptime`.strip,
      ruby_version: RUBY_VERSION
    }
  rescue
    {}
  end

  def get_database_info
    {
      type: 'SQLite',
      version: DB.fetch("SELECT sqlite_version()").first[:sqlite_version],
      size: File.size('cicd.db') rescue 0,
      tables: DB.tables.length
    }
  rescue
    {}
  end

  def get_storage_info
    {
      total: `df -h . | tail -1 | awk '{print $2}'`.strip,
      used: `df -h . | tail -1 | awk '{print $3}'`.strip,
      available: `df -h . | tail -1 | awk '{print $4}'`.strip,
      usage_percent: `df -h . | tail -1 | awk '{print $5}'`.strip.gsub('%', '').to_i
    }
  rescue
    {}
  end

  def get_service_status
    {
      database: DB.test_connection ? 'running' : 'stopped',
      websocket: check_websocket_status,
      web_server: 'running' # 如果能执行到这里说明web服务正常
    }
  rescue
    {}
  end

  def get_recent_system_logs
    Log.where(log_type: 'system')
       .order(Sequel.desc(:created_at))
       .limit(10)
       .map(&:to_hash)
  rescue
    []
  end

  def check_websocket_status
    # 检查WebSocket服务状态的逻辑
    'running'
  end

  def get_current_version
    '1.0.0' # 从配置文件或常量获取
  end

  def get_latest_version
    # 从远程服务器获取最新版本
    '1.0.1'
  end

  def version_compare(version1, version2)
    v1_parts = version1.split('.').map(&:to_i)
    v2_parts = version2.split('.').map(&:to_i)
    
    [v1_parts.length, v2_parts.length].max.times do |i|
      v1 = v1_parts[i] || 0
      v2 = v2_parts[i] || 0
      
      return 1 if v1 > v2
      return -1 if v1 < v2
    end
    
    0
  end

  def backup_current_version
    # 备份当前版本的逻辑
  end

  def download_new_version
    # 下载新版本的逻辑
  end

  def execute_upgrade_script
    # 执行升级脚本的逻辑
  end

  def create_system_backup
    backup_dir = File.join(CONFIG['temp_dir'], 'backups')
    FileUtils.mkdir_p(backup_dir)
    
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    backup_file = File.join(backup_dir, "system_backup_#{timestamp}.tar.gz")
    
    # 创建备份
    system("tar -czf #{backup_file} cicd.db config.json")
    
    backup_file
  end

  def restore_from_backup(backup_file)
    # 恢复系统的逻辑
    system("tar -xzf #{backup_file}")
  end

  def get_cpu_usage
    begin
      `ps -eo %cpu | awk '{s+=$1} END {print s}'`.strip.to_f
    rescue
      0
    end
  end

  def get_memory_usage
    begin
      total = `free -m | grep '^Mem:' | awk '{print $2}'`.strip.to_i
      used = `free -m | grep '^Mem:' | awk '{print $3}'`.strip.to_i
      
      {
        total: total,
        used: used,
        free: total - used,
        usage_percent: total > 0 ? (used.to_f / total * 100).round(2) : 0
      }
    rescue
      { total: 0, used: 0, free: 0, usage_percent: 0 }
    end
  end

  def get_disk_usage
    begin
      df_output = `df -h / | tail -1`.strip.split
      {
        total: df_output[1],
        used: df_output[2],
        available: df_output[3],
        usage_percent: df_output[4].gsub('%', '').to_i
      }
    rescue
      { total: '0', used: '0', available: '0', usage_percent: 0 }
    end
  end

  def get_network_stats
    begin
      rx_bytes = `cat /sys/class/net/eth0/statistics/rx_bytes 2>/dev/null || echo 0`.strip.to_i
      tx_bytes = `cat /sys/class/net/eth0/statistics/tx_bytes 2>/dev/null || echo 0`.strip.to_i
      
      {
        received: rx_bytes,
        transmitted: tx_bytes
      }
    rescue
      { received: 0, transmitted: 0 }
    end
  end

  def get_process_count
    begin
      `ps aux | wc -l`.strip.to_i - 1
    rescue
      0
    end
  end

  def get_active_connections
    begin
      `netstat -an | grep :#{CONFIG['app_port']} | grep ESTABLISHED | wc -l`.strip.to_i
    rescue
      0
    end
  end
end