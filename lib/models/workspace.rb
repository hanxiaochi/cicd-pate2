# 工作空间模型
class Workspace < BaseModel(:workspaces)
  one_to_many :projects
  many_to_one :user, key: :owner_id

  def validate
    super
    validates_presence [:name, :owner_id]
    validates_unique :name
  end

  def project_count
    projects_dataset.count
  end

  def active_projects
    projects_dataset.where(active: true)
  end

  def recent_builds
    Build.where(project_id: projects_dataset.select(:id))
         .order(Sequel.desc(:created_at))
         .limit(10)
  end

  def can_access?(user)
    return true if user.admin?
    return true if owner_id == user.id
    
    # 检查是否有工作空间访问权限
    Permission.where(
      user_id: user.id,
      resource_type: 'workspace',
      resource_id: id
    ).count > 0
  end

  def to_hash
    super.merge(
      project_count: project_count,
      owner: user&.username
    )
  end
end