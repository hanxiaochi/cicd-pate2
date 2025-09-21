# 数据库初始化器
class DatabaseInitializer
  def self.create_tables
    create_users_table
    create_workspaces_table
    create_projects_table
    create_resources_table
    create_docker_resources_table
    create_services_table
    create_nodes_table
    create_builds_table
    create_deployments_table
    create_scripts_table
    create_script_executions_table
    create_logs_table
    create_permissions_table
    create_system_configs_table
    
    # 创建默认数据
    create_default_admin
    create_default_workspace
    SystemConfig.initialize_default_configs
  end

  private

  def self.create_users_table
    unless DB.table_exists?(:users)
      DB.create_table :users do
        primary_key :id
        String :username, null: false, unique: true
        String :password_hash, null: false
        String :role, default: 'user'
        String :email
        String :phone
        String :department
        Boolean :active, default: true
        Time :last_login
        Time :created_at, default: Time.now
        Time :updated_at, default: Time.now
      end
    end
  end

  def self.create_projects_table
    unless DB.table_exists?(:projects)
      DB.create_table :projects do
        primary_key :id
        String :name, null: false
        String :project_type, default: 'java' # java, nodejs, python, etc.
        String :repo_type, null: false # git, svn
        String :repo_url, null: false
        String :branch, default: 'master'
        String :build_script
        String :artifact_path
        String :deploy_server
        String :deploy_path
        String :start_script
        String :stop_script
        String :backup_path
        String :start_mode, default: 'default'
        String :stop_mode, default: 'sh_script'
        String :jvm_options
        String :environment_vars
        Boolean :auto_start, default: false
        Integer :user_id # 项目所有者
        Integer :workspace_id # 工作空间ID
        Time :created_at, default: Time.now
        Time :updated_at, default: Time.now
      end
    end
  end

  def self.create_resources_table
    unless DB.table_exists?(:resources)
      DB.create_table :resources do
        primary_key :id
        String :name, null: false
        String :ip, null: false
        Integer :ssh_port, default: 22
        String :username
        String :password_hash
        String :ssh_key_path
        String :description
        String :os_type, default: 'linux'
        String :status, default: 'online'
        Time :last_check
        Time :created_at, default: Time.now
        Time :updated_at, default: Time.now
      end
    end
  end

  def self.create_docker_resources_table
    unless DB.table_exists?(:docker_resources)
      DB.create_table :docker_resources do
        primary_key :id
        String :name, null: false
        Integer :resource_id, null: false
        String :docker_host
        Integer :docker_port, default: 2376
        String :tls_cert_path
        String :status, default: 'stopped'
        String :version
        String :description
        Time :last_check
        Time :created_at, default: Time.now
        Time :updated_at, default: Time.now
      end
    end
  end

  def self.create_services_table
    unless DB.table_exists?(:services)
      DB.create_table :services do
        primary_key :id
        String :name, null: false
        String :service_type, default: 'system'
        String :description
        String :command
        String :config_file
        String :log_file
        Integer :resource_id
        String :status, default: 'stopped'
        Time :created_at, default: Time.now
        Time :updated_at, default: Time.now
      end
    end
  end

  def self.create_nodes_table
    unless DB.table_exists?(:nodes)
      DB.create_table :nodes do
        primary_key :id
        String :name, null: false
        String :ip, null: false
        Integer :port, default: 22
        String :username
        String :password_hash
        String :ssh_key_path
        String :node_type, default: 'agent' # agent, docker
        String :status, default: 'offline'
        String :version
        Time :last_heartbeat
        Time :created_at, default: Time.now
        Time :updated_at, default: Time.now
      end
    end
  end

  def self.create_builds_table
    unless DB.table_exists?(:builds)
      DB.create_table :builds do
        primary_key :id
        Integer :project_id, null: false
        String :build_number
        String :commit_id
        String :branch
        String :status, default: 'pending' # pending, running, success, failed
        String :build_log
        String :artifact_path
        Time :start_time
        Time :end_time
        Integer :duration # 构建耗时（秒）
        Integer :user_id # 触发构建的用户
        Time :created_at, default: Time.now
      end
    end
  end

  def self.create_deployments_table
    unless DB.table_exists?(:deployments)
      DB.create_table :deployments do
        primary_key :id
        Integer :project_id, null: false
        Integer :build_id
        String :version
        String :status, default: 'pending' # pending, running, success, failed, rolled_back
        String :deploy_log
        Time :start_time
        Time :end_time
        Integer :duration # 部署耗时（秒）
        Integer :user_id # 触发部署的用户
        Time :created_at, default: Time.now
      end
    end
  end

  def self.create_scripts_table
    unless DB.table_exists?(:scripts)
      DB.create_table :scripts do
        primary_key :id
        String :name, null: false, unique: true
        String :script_type, null: false
        String :file_path, null: false
        String :description
        String :content_hash
        Integer :author_id
        Boolean :active, default: true
        Time :created_at, default: Time.now
        Time :updated_at, default: Time.now
      end
    end
  end

  def self.create_script_executions_table
    unless DB.table_exists?(:script_executions)
      DB.create_table :script_executions do
        primary_key :id
        Integer :script_id, null: false
        String :command, null: false
        Boolean :success, default: false
        String :output
        String :error
        Integer :exit_code
        Integer :resource_id
        Integer :user_id
        Time :start_time
        Time :end_time
        Time :execution_time, default: Time.now
        Time :created_at, default: Time.now
      end
    end
  end

  def self.create_logs_table
    unless DB.table_exists?(:logs)
      DB.create_table :logs do
        primary_key :id
        String :log_type # system, build, deploy, user
        String :level # info, warn, error, debug
        String :message
        String :source # 日志来源
        Integer :user_id
        Integer :project_id
        String :ip_address
        Time :created_at, default: Time.now
      end
    end
  end

  def self.create_permissions_table
    unless DB.table_exists?(:permissions)
      DB.create_table :permissions do
        primary_key :id
        Integer :user_id, null: false
        String :resource_type # project, node, system
        Integer :resource_id
        String :permission_type # read, write, admin
        Time :created_at, default: Time.now
      end
    end
  end

  def self.create_system_configs_table
    unless DB.table_exists?(:system_configs)
      DB.create_table :system_configs do
        primary_key :id
        String :config_key, null: false, unique: true
        String :config_value
        String :config_type, default: 'string'
        String :description
        Boolean :is_system, default: false
        Time :created_at, default: Time.now
        Time :updated_at, default: Time.now
      end
    end
  end

  def self.create_workspaces_table
    unless DB.table_exists?(:workspaces)
      DB.create_table :workspaces do
        primary_key :id
        String :name, null: false, unique: true
        String :description
        Integer :owner_id, null: false
        Boolean :active, default: true
        Time :created_at, default: Time.now
        Time :updated_at, default: Time.now
      end
    end
  end

  def self.create_default_admin
    unless DB[:users].where(username: 'admin').count > 0
      DB[:users].insert(
        username: 'admin',
        password_hash: BCrypt::Password.create('admin123'),
        role: 'admin',
        email: 'admin@example.com'
      )
    end
  end

  def self.create_default_workspace
    unless DB[:workspaces].where(name: 'default').count > 0
      admin_user = DB[:users].where(username: 'admin').first
      if admin_user
        DB[:workspaces].insert(
          name: 'default',
          description: '默认工作空间',
          owner_id: admin_user[:id]
        )
      end
    end
  end
end