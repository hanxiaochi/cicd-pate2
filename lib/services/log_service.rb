# 日志服务
class LogService
  LOG_TYPES = %w[system build deploy user security audit].freeze
  LOG_LEVELS = %w[debug info warn error fatal].freeze

  def self.log(type:, level:, message:, user_id: nil, project_id: nil, ip_address: nil, source: nil, details: {})
    begin
      Log.create(
        log_type: type,
        level: level,
        message: message,
        source: source,
        user_id: user_id,
        project_id: project_id,
        ip_address: ip_address,
        details: details.any? ? details.to_json : nil
      )
    rescue => e
      # 记录日志失败时，至少输出到标准错误
      STDERR.puts "Failed to log: #{e.message}"
      STDERR.puts "Original log: [#{level.upcase}] #{message}"
    end
  end

  def self.system_log(level, message, details = {})
    log(
      type: 'system',
      level: level,
      message: message,
      source: 'system',
      details: details
    )
  end

  def self.build_log(level, message, project_id, build_id = nil, user_id = nil)
    log(
      type: 'build',
      level: level,
      message: message,
      project_id: project_id,
      user_id: user_id,
      source: "build_#{build_id}",
      details: { build_id: build_id }
    )
  end

  def self.deploy_log(level, message, project_id, deployment_id = nil, user_id = nil)
    log(
      type: 'deploy',
      level: level,
      message: message,
      project_id: project_id,
      user_id: user_id,
      source: "deploy_#{deployment_id}",
      details: { deployment_id: deployment_id }
    )
  end

  def self.user_log(level, message, user_id, ip_address = nil, details = {})
    log(
      type: 'user',
      level: level,
      message: message,
      user_id: user_id,
      ip_address: ip_address,
      source: 'user_action',
      details: details
    )
  end

  def self.security_log(level, message, user_id = nil, ip_address = nil, details = {})
    log(
      type: 'security',
      level: level,
      message: message,
      user_id: user_id,
      ip_address: ip_address,
      source: 'security',
      details: details
    )
  end

  def self.audit_log(message, user_id, action, resource_type = nil, resource_id = nil, ip_address = nil)
    details = {
      action: action,
      resource_type: resource_type,
      resource_id: resource_id
    }

    log(
      type: 'audit',
      level: 'info',
      message: message,
      user_id: user_id,
      ip_address: ip_address,
      source: 'audit',
      details: details
    )
  end

  def self.get_logs(filters = {}, page = 1, per_page = 50)
    dataset = Log.dataset
    
    # 应用过滤器
    dataset = dataset.where(log_type: filters[:log_type]) if filters[:log_type]
    dataset = dataset.where(level: filters[:level]) if filters[:level]
    dataset = dataset.where(user_id: filters[:user_id]) if filters[:user_id]
    dataset = dataset.where(project_id: filters[:project_id]) if filters[:project_id]
    dataset = dataset.where(source: filters[:source]) if filters[:source]
    
    # 时间范围过滤
    if filters[:start_time] && filters[:end_time]
      dataset = dataset.where(created_at: filters[:start_time]..filters[:end_time])
    end
    
    # 搜索
    if filters[:search]
      search_term = "%#{filters[:search]}%"
      dataset = dataset.where(Sequel.ilike(:message, search_term))
    end

    # 分页
    offset = (page - 1) * per_page
    logs = dataset.order(Sequel.desc(:created_at))
                  .limit(per_page, offset)
                  .all

    {
      logs: logs.map(&:to_hash),
      total: dataset.count,
      page: page,
      per_page: per_page,
      total_pages: (dataset.count.to_f / per_page).ceil
    }
  end

  def self.clean_old_logs(days = 30)
    cutoff_date = Time.now - (days * 24 * 60 * 60)
    deleted_count = Log.where('created_at < ?', cutoff_date).delete
    
    system_log('info', "清理了 #{deleted_count} 条超过 #{days} 天的日志记录")
    deleted_count
  end

  def self.get_log_statistics(days = 7)
    start_time = Time.now - (days * 24 * 60 * 60)
    
    stats = {
      total_logs: Log.where('created_at > ?', start_time).count,
      by_type: Log.where('created_at > ?', start_time).group(:log_type).count,
      by_level: Log.where('created_at > ?', start_time).group(:level).count,
      error_count: Log.where('created_at > ? AND level IN ?', start_time, %w[error fatal]).count,
      daily_counts: get_daily_log_counts(days)
    }

    stats
  end

  def self.export_logs(filters = {}, format = 'json')
    logs = Log.dataset
    
    # 应用过滤器
    logs = logs.where(log_type: filters[:log_type]) if filters[:log_type]
    logs = logs.where(level: filters[:level]) if filters[:level]
    
    if filters[:start_time] && filters[:end_time]
      logs = logs.where(created_at: filters[:start_time]..filters[:end_time])
    end

    case format.downcase
    when 'csv'
      export_logs_csv(logs.all)
    when 'txt'
      export_logs_txt(logs.all)
    else
      export_logs_json(logs.all)
    end
  end

  private

  def self.get_daily_log_counts(days)
    results = {}
    days.times do |i|
      date = Date.today - i
      start_time = date.to_time
      end_time = start_time + 86400
      
      count = Log.where(created_at: start_time..end_time).count
      results[date.strftime('%Y-%m-%d')] = count
    end
    
    results
  end

  def self.export_logs_csv(logs)
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

  def self.export_logs_txt(logs)
    logs.map do |log|
      "[#{log.created_at.strftime('%Y-%m-%d %H:%M:%S')}] [#{log.level.upcase}] [#{log.log_type}] #{log.message}"
    end.join("\n")
  end

  def self.export_logs_json(logs)
    { logs: logs.map(&:to_hash) }.to_json
  end
end