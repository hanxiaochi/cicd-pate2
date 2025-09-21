# API控制器 - 提供RESTful API接口
class ApiController < BaseController
  # API版本信息
  def version
    json_response({
      version: '1.0.0',
      name: 'Jpom CICD API',
      description: 'Jpom持续集成部署系统API',
      timestamp: Time.now.to_i
    })
  end

  # API健康检查
  def health
    db_status = begin
      DB.test_connection
      'healthy'
    rescue
      'unhealthy'
    end

    json_response({
      status: 'ok',
      database: db_status,
      uptime: Time.now.to_i - STARTUP_TIME,
      timestamp: Time.now.to_i
    })
  end

  # API状态统计
  def stats
    login_required
    
    stats_data = {
      projects: {
        total: Project.count,
        active: Project.where(active: true).count,
        types: Project.group(:project_type).count
      },
      users: {
        total: User.count,
        active: User.where(active: true).count,
        online: User.where('last_login > ?', Time.now - 3600).count
      },
      builds: {
        total: Build.count,
        today: Build.where('created_at > ?', Date.today).count,
        success_rate: calculate_build_success_rate
      },
      deployments: {
        total: Deployment.count,
        today: Deployment.where('created_at > ?', Date.today).count,
        success_rate: calculate_deployment_success_rate
      },
      resources: {
        total: Resource.count,
        online: Resource.where(status: 'online').count
      }
    }

    success_response('获取统计信息成功', stats_data)
  end

  # 系统配置API
  def system_config
    admin_required
    
    configs = SystemConfig.all.map(&:to_hash)
    success_response('获取系统配置成功', configs)
  end

  def update_system_config
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
    success_response('系统配置更新成功', config.to_hash)
  end

  # 日志查询API
  def logs
    login_required
    
    page_params = paginate_params
    filters = {}
    
    filters[:log_type] = params[:log_type] if params[:log_type]
    filters[:level] = params[:level] if params[:level]
    filters[:user_id] = params[:user_id] if params[:user_id]
    filters[:project_id] = params[:project_id] if params[:project_id]
    
    # 时间范围过滤
    if params[:start_time] && params[:end_time]
      start_time = Time.parse(params[:start_time])
      end_time = Time.parse(params[:end_time])
      filters[:created_at] = start_time..end_time
    end

    logs_dataset = Log.where(filters)
                     .order(Sequel.desc(:created_at))
                     .paginate(**page_params)

    logs_data = logs_dataset.map(&:to_hash)
    
    success_response('获取日志成功', {
      logs: logs_data,
      pagination: {
        page: page_params[:page],
        per_page: page_params[:per_page],
        total: Log.where(filters).count
      }
    })
  end

  # 导出日志
  def export_logs
    admin_required
    
    format = params[:format] || 'json'
    filters = {}
    
    # 应用过滤条件
    filters[:log_type] = params[:log_type] if params[:log_type]
    filters[:level] = params[:level] if params[:level]
    
    if params[:start_time] && params[:end_time]
      start_time = Time.parse(params[:start_time])
      end_time = Time.parse(params[:end_time])
      filters[:created_at] = start_time..end_time
    end

    logs = Log.where(filters).order(Sequel.desc(:created_at)).all

    case format.downcase
    when 'csv'
      content_type 'text/csv'
      attachment "logs_#{Date.today}.csv"
      generate_csv_logs(logs)
    when 'txt'
      content_type 'text/plain'
      attachment "logs_#{Date.today}.txt"
      generate_text_logs(logs)
    else
      content_type 'application/json'
      attachment "logs_#{Date.today}.json"
      { logs: logs.map(&:to_hash) }.to_json
    end
  end

  # 系统监控API
  def system_monitor
    login_required
    
    monitor_data = {
      cpu: get_cpu_usage,
      memory: get_memory_usage,
      disk: get_disk_usage,
      network: get_network_stats,
      processes: get_process_count,
      timestamp: Time.now.to_i
    }

    success_response('获取监控数据成功', monitor_data)
  end

  private

  def calculate_build_success_rate
    total = Build.count
    return 0 if total == 0
    
    success = Build.where(status: 'success').count
    (success.to_f / total * 100).round(2)
  end

  def calculate_deployment_success_rate
    total = Deployment.count
    return 0 if total == 0
    
    success = Deployment.where(status: 'success').count
    (success.to_f / total * 100).round(2)
  end

  def generate_csv_logs(logs)
    require 'csv'
    
    CSV.generate do |csv|
      csv << ['时间', '类型', '级别', '消息', '来源', '用户ID', '项目ID', 'IP地址']
      
      logs.each do |log|
        csv << [
          log.created_at.strftime('%Y-%m-%d %H:%M:%S'),
          log.log_type,
          log.level,
          log.message,
          log.source,
          log.user_id,
          log.project_id,
          log.ip_address
        ]
      end
    end
  end

  def generate_text_logs(logs)
    logs.map do |log|
      "[#{log.created_at.strftime('%Y-%m-%d %H:%M:%S')}] [#{log.level.upcase}] [#{log.log_type}] #{log.message}"
    end.join("\n")
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
end