# 用户模型
class User < BaseModel(:users)
  def validate
    super
    validates_presence [:username, :password_hash]
    validates_unique :username
    validates_format /\A[a-zA-Z0-9_]{3,20}\z/, :username, message: '用户名只能包含字母、数字和下划线，长度3-20位'
  end

  def authenticate(password)
    BCrypt::Password.new(password_hash) == password
  end

  def admin?
    role == 'admin'
  end

  def can_access?(resource_type, resource_id = nil, permission_type = 'read')
    return true if admin?
    
    # 检查用户权限
    Permission.where(
      user_id: id,
      resource_type: resource_type,
      resource_id: resource_id,
      permission_type: permission_type
    ).count > 0
  end

  def projects
    return Project.all if admin?
    Project.where(user_id: id)
  end

  def update_last_login
    update(last_login: Time.now)
  end

  def before_create
    super
    self.created_at = Time.now
    self.updated_at = Time.now
  end

  def before_update
    super
    self.updated_at = Time.now
  end
end