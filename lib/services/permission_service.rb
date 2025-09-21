# 权限控制服务
class PermissionService
  RESOURCE_TYPES = %w[project workspace resource node script system].freeze
  PERMISSION_TYPES = %w[read write admin].freeze

  def self.check_permission(user, resource_type, resource_id = nil, permission_type = 'read')
    return true if user&.admin?
    
    # 检查用户是否有特定权限
    Permission.where(
      user_id: user.id,
      resource_type: resource_type,
      resource_id: resource_id,
      permission_type: permission_type
    ).count > 0
  end

  def self.grant_permission(user_id, resource_type, resource_id, permission_type, granted_by = nil)
    # 验证参数
    raise ArgumentError, "无效的资源类型" unless RESOURCE_TYPES.include?(resource_type)
    raise ArgumentError, "无效的权限类型" unless PERMISSION_TYPES.include?(permission_type)
    
    user = User[user_id]
    raise ArgumentError, "用户不存在" unless user

    # 检查权限是否已存在
    existing_permission = Permission.where(
      user_id: user_id,
      resource_type: resource_type,
      resource_id: resource_id
    ).first

    if existing_permission
      # 更新现有权限
      existing_permission.update(permission_type: permission_type)
      permission = existing_permission
    else
      # 创建新权限
      permission = Permission.create(
        user_id: user_id,
        resource_type: resource_type,
        resource_id: resource_id,
        permission_type: permission_type
      )
    end

    # 记录审计日志
    LogService.audit_log(
      "授予权限: #{permission_type} on #{resource_type}:#{resource_id} to user:#{user_id}",
      granted_by,
      'grant_permission',
      resource_type,
      resource_id
    )

    permission
  end

  def self.revoke_permission(user_id, resource_type, resource_id, revoked_by = nil)
    permission = Permission.where(
      user_id: user_id,
      resource_type: resource_type,
      resource_id: resource_id
    ).first

    return false unless permission

    permission_info = permission.to_hash
    permission.destroy

    # 记录审计日志
    LogService.audit_log(
      "撤销权限: #{permission_info[:permission_type]} on #{resource_type}:#{resource_id} from user:#{user_id}",
      revoked_by,
      'revoke_permission',
      resource_type,
      resource_id
    )

    true
  end

  def self.list_user_permissions(user_id)
    Permission.where(user_id: user_id)
              .order(:resource_type, :resource_id)
              .all
              .map(&:to_hash)
  end

  def self.list_resource_permissions(resource_type, resource_id)
    Permission.where(resource_type: resource_type, resource_id: resource_id)
              .join(:users, id: :user_id)
              .select_all(:permissions)
              .select_append(:users__username)
              .all
              .map do |perm|
      perm.to_hash.merge(username: perm[:username])
    end
  end

  def self.copy_permissions(from_user_id, to_user_id, resource_type = nil, copied_by = nil)
    from_user = User[from_user_id]
    to_user = User[to_user_id]
    
    raise ArgumentError, "源用户不存在" unless from_user
    raise ArgumentError, "目标用户不存在" unless to_user

    permissions_query = Permission.where(user_id: from_user_id)
    permissions_query = permissions_query.where(resource_type: resource_type) if resource_type

    copied_count = 0
    permissions_query.each do |permission|
      # 检查目标用户是否已有此权限
      existing = Permission.where(
        user_id: to_user_id,
        resource_type: permission.resource_type,
        resource_id: permission.resource_id
      ).first

      unless existing
        Permission.create(
          user_id: to_user_id,
          resource_type: permission.resource_type,
          resource_id: permission.resource_id,
          permission_type: permission.permission_type
        )
        copied_count += 1
      end
    end

    # 记录审计日志
    LogService.audit_log(
      "复制权限: 从 user:#{from_user_id} 到 user:#{to_user_id}, 复制了 #{copied_count} 个权限",
      copied_by,
      'copy_permissions'
    )

    copied_count
  end

  def self.check_project_access(user, project, permission_type = 'read')
    return true if user&.admin?
    return true if project.user_id == user.id

    # 检查项目直接权限
    if check_permission(user, 'project', project.id, permission_type)
      return true
    end

    # 检查工作空间权限
    if project.workspace_id
      if check_permission(user, 'workspace', project.workspace_id, permission_type)
        return true
      end
    end

    false
  end

  def self.check_resource_access(user, resource, permission_type = 'read')
    return true if user&.admin?
    
    check_permission(user, 'resource', resource.id, permission_type)
  end

  def self.check_system_access(user, feature)
    return true if user&.admin?
    
    case feature
    when 'user_management', 'system_config', 'system_monitor'
      check_permission(user, 'system', feature, 'admin')
    when 'log_view'
      check_permission(user, 'system', feature, 'read')
    else
      false
    end
  end

  def self.get_user_accessible_projects(user)
    return Project.all if user&.admin?

    # 用户拥有的项目
    owned_projects = Project.where(user_id: user.id)

    # 用户有权限的项目
    accessible_project_ids = Permission.where(
      user_id: user.id,
      resource_type: 'project'
    ).select(:resource_id)

    # 用户有权限的工作空间中的项目
    accessible_workspace_ids = Permission.where(
      user_id: user.id,
      resource_type: 'workspace'
    ).select(:resource_id)

    workspace_projects = Project.where(workspace_id: accessible_workspace_ids)

    # 合并所有项目
    Project.where(
      Sequel.|(
        { id: owned_projects.select(:id) },
        { id: accessible_project_ids },
        { id: workspace_projects.select(:id) }
      )
    )
  end

  def self.get_user_accessible_resources(user)
    return Resource.all if user&.admin?

    accessible_resource_ids = Permission.where(
      user_id: user.id,
      resource_type: 'resource'
    ).select(:resource_id)

    Resource.where(id: accessible_resource_ids)
  end

  def self.cleanup_orphaned_permissions
    # 清理用户已删除的权限
    orphaned_user_permissions = Permission.where(
      user_id: User.dataset.exclude(id: Permission.select(:user_id).distinct)
    )
    deleted_user_count = orphaned_user_permissions.delete

    # 清理项目已删除的权限
    orphaned_project_permissions = Permission.where(
      resource_type: 'project',
      resource_id: Project.dataset.exclude(id: Permission.where(resource_type: 'project').select(:resource_id).distinct)
    )
    deleted_project_count = orphaned_project_permissions.delete

    # 清理工作空间已删除的权限
    orphaned_workspace_permissions = Permission.where(
      resource_type: 'workspace',
      resource_id: Workspace.dataset.exclude(id: Permission.where(resource_type: 'workspace').select(:resource_id).distinct)
    )
    deleted_workspace_count = orphaned_workspace_permissions.delete

    # 清理资源已删除的权限
    orphaned_resource_permissions = Permission.where(
      resource_type: 'resource',
      resource_id: Resource.dataset.exclude(id: Permission.where(resource_type: 'resource').select(:resource_id).distinct)
    )
    deleted_resource_count = orphaned_resource_permissions.delete

    LogService.system_log(
      'info',
      "清理孤立权限: 用户#{deleted_user_count}, 项目#{deleted_project_count}, 工作空间#{deleted_workspace_count}, 资源#{deleted_resource_count}"
    )

    {
      deleted_user_permissions: deleted_user_count,
      deleted_project_permissions: deleted_project_count,
      deleted_workspace_permissions: deleted_workspace_count,
      deleted_resource_permissions: deleted_resource_count
    }
  end

  def self.bulk_grant_permissions(user_ids, resource_type, resource_id, permission_type, granted_by = nil)
    granted_count = 0
    
    user_ids.each do |user_id|
      begin
        grant_permission(user_id, resource_type, resource_id, permission_type, granted_by)
        granted_count += 1
      rescue => e
        LogService.system_log('error', "批量授权失败 user:#{user_id} - #{e.message}")
      end
    end

    LogService.audit_log(
      "批量授权权限: #{permission_type} on #{resource_type}:#{resource_id} to #{granted_count} users",
      granted_by,
      'bulk_grant_permissions',
      resource_type,
      resource_id
    )

    granted_count
  end

  def self.bulk_revoke_permissions(user_ids, resource_type, resource_id, revoked_by = nil)
    revoked_count = 0
    
    user_ids.each do |user_id|
      if revoke_permission(user_id, resource_type, resource_id, revoked_by)
        revoked_count += 1
      end
    end

    LogService.audit_log(
      "批量撤销权限: #{resource_type}:#{resource_id} from #{revoked_count} users",
      revoked_by,
      'bulk_revoke_permissions',
      resource_type,
      resource_id
    )

    revoked_count
  end

  def self.get_permission_matrix(resource_type = nil)
    query = Permission.dataset
    query = query.where(resource_type: resource_type) if resource_type

    permissions = query.join(:users, id: :user_id)
                       .select_all(:permissions)
                       .select_append(:users__username)
                       .all

    matrix = {}
    permissions.each do |perm|
      matrix[perm[:username]] ||= {}
      resource_key = "#{perm[:resource_type]}:#{perm[:resource_id]}"
      matrix[perm[:username]][resource_key] = perm[:permission_type]
    end

    matrix
  end
end