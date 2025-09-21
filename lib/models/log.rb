# 日志模型
class Log < BaseModel(:logs)
  many_to_one :user
  many_to_one :project

  def validate
    super
    validates_presence [:log_type, :level, :message]
    validates_includes LogService::LOG_TYPES, :log_type
    validates_includes LogService::LOG_LEVELS, :level
  end

  def parsed_details
    return {} if details.nil? || details.empty?
    
    begin
      JSON.parse(details)
    rescue JSON::ParserError
      {}
    end
  end

  def formatted_message
    timestamp = created_at.strftime('%Y-%m-%d %H:%M:%S')
    level_str = level.upcase.ljust(5)
    type_str = log_type.upcase.ljust(8)
    
    "[#{timestamp}] [#{level_str}] [#{type_str}] #{message}"
  end

  def to_hash
    super.merge(
      user_name: user&.username,
      project_name: project&.name,
      parsed_details: parsed_details,
      formatted_message: formatted_message
    )
  end

  def self.recent_errors(limit = 10)
    where(level: %w[error fatal])
      .order(Sequel.desc(:created_at))
      .limit(limit)
      .all
  end

  def self.by_type(log_type)
    where(log_type: log_type)
  end

  def self.by_level(level)
    where(level: level)
  end

  def self.by_user(user_id)
    where(user_id: user_id)
  end

  def self.by_project(project_id)
    where(project_id: project_id)
  end

  def self.in_date_range(start_date, end_date)
    where(created_at: start_date..end_date)
  end

  def self.search(query)
    where(Sequel.ilike(:message, "%#{query}%"))
  end
end

# 权限模型
class Permission < BaseModel(:permissions)
  many_to_one :user

  def validate
    super
    validates_presence [:user_id, :resource_type, :permission_type]
    validates_includes PermissionService::RESOURCE_TYPES, :resource_type
    validates_includes PermissionService::PERMISSION_TYPES, :permission_type
    validates_unique [:user_id, :resource_type, :resource_id]
  end

  def resource_name
    case resource_type
    when 'project'
      Project[resource_id]&.name
    when 'workspace'
      Workspace[resource_id]&.name
    when 'resource'
      Resource[resource_id]&.name
    when 'script'
      Script[resource_id]&.name
    else
      resource_id.to_s
    end
  end

  def resource_info
    case resource_type
    when 'project'
      Project[resource_id]&.to_hash
    when 'workspace'
      Workspace[resource_id]&.to_hash
    when 'resource'
      Resource[resource_id]&.to_hash
    when 'script'
      Script[resource_id]&.to_hash
    else
      { id: resource_id, type: resource_type }
    end
  end

  def to_hash
    super.merge(
      user_name: user&.username,
      resource_name: resource_name
    )
  end

  def self.for_user(user_id)
    where(user_id: user_id)
  end

  def self.for_resource(resource_type, resource_id)
    where(resource_type: resource_type, resource_id: resource_id)
  end

  def self.with_permission(permission_type)
    where(permission_type: permission_type)
  end

  def self.admin_permissions
    where(permission_type: 'admin')
  end

  def self.read_permissions
    where(permission_type: 'read')
  end

  def self.write_permissions
    where(permission_type: 'write')
  end
end