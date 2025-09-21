# 系统配置模型
class SystemConfig < BaseModel(:system_configs)
  def validate
    super
    validates_presence [:config_key]
    validates_unique :config_key
    validates_includes ['string', 'number', 'boolean', 'json'], :config_type
  end

  def self.get_config(key, default_value = nil)
    config = find(config_key: key)
    return default_value unless config
    
    case config.config_type
    when 'number'
      config.config_value.to_f
    when 'boolean'
      config.config_value == 'true'
    when 'json'
      JSON.parse(config.config_value) rescue default_value
    else
      config.config_value
    end
  end

  def self.set_config(key, value, type = 'string', description = nil)
    config_value = case type
                  when 'boolean'
                    value.to_s
                  when 'json'
                    value.to_json
                  else
                    value.to_s
                  end

    config = find_or_create(config_key: key) do |c|
      c.config_value = config_value
      c.config_type = type
      c.description = description
    end

    config.update(
      config_value: config_value,
      config_type: type,
      description: description || config.description
    )

    config
  end

  def self.delete_config(key)
    config = find(config_key: key)
    return false unless config
    return false if config.is_system
    
    config.destroy
    true
  end

  def self.initialize_default_configs
    default_configs = [
      {
        key: 'app_name',
        value: 'Jpom CICD系统',
        type: 'string',
        description: '应用程序名称',
        is_system: true
      },
      {
        key: 'app_version',
        value: '1.0.0',
        type: 'string',
        description: '应用程序版本',
        is_system: true
      },
      {
        key: 'session_timeout',
        value: '3600',
        type: 'number',
        description: '会话超时时间（秒）',
        is_system: false
      },
      {
        key: 'max_build_history',
        value: '100',
        type: 'number',
        description: '最大构建历史记录数',
        is_system: false
      },
      {
        key: 'auto_clean_logs',
        value: 'true',
        type: 'boolean',
        description: '自动清理日志',
        is_system: false
      },
      {
        key: 'log_retention_days',
        value: '30',
        type: 'number',
        description: '日志保留天数',
        is_system: false
      },
      {
        key: 'notification_settings',
        value: {
          email_enabled: false,
          webhook_enabled: false,
          build_success: true,
          build_failure: true,
          deploy_success: true,
          deploy_failure: true
        }.to_json,
        type: 'json',
        description: '通知设置',
        is_system: false
      }
    ]

    default_configs.each do |config|
      unless find(config_key: config[:key])
        create(
          config_key: config[:key],
          config_value: config[:value],
          config_type: config[:type],
          description: config[:description],
          is_system: config[:is_system]
        )
      end
    end
  end

  def typed_value
    case config_type
    when 'number'
      config_value.to_f
    when 'boolean'
      config_value == 'true'
    when 'json'
      JSON.parse(config_value) rescue {}
    else
      config_value
    end
  end

  def to_hash
    super.merge(
      typed_value: typed_value
    )
  end
end