# 主应用程序 - 重构后的架构
require_relative 'config/application'

# 启动时间记录
STARTUP_TIME = Time.now.to_i

# 初始化应用程序
class JpomApp < Sinatra::Base
  # 注册必要的扩展
  register Sinatra::Flash
  
  # 配置应用程序
  ApplicationConfig.configure_sinatra(self)
  
  # 初始化数据库
  ApplicationConfig.initialize_database
  
  # 加载中间件
  use LoggingMiddleware
  use PermissionMiddleware
  use SecurityMiddleware
  
  # 辅助方法
  helpers do
    def current_user
      @current_user ||= User[session[:user_id]] if session[:user_id]
    end

    def login_required
      redirect '/login' unless current_user
    end

    def admin_required
      redirect '/' unless current_user&.admin?
    end

    def json_response(data, status = 200)
      content_type :json
      status status
      data.to_json
    end

    def success_response(message = '操作成功', data = nil)
      json_response({
        success: true,
        message: message,
        data: data,
        timestamp: Time.now.to_i
      })
    end

    def error_response(message = '操作失败', status = 400)
      json_response({
        success: false,
        message: message,
        timestamp: Time.now.to_i
      }, status)
    end
  end

  # 路由定义

  # === 认证相关路由 ===
  get '/login' do
    AuthController.new(self).login_page
  end

  post '/login' do
    AuthController.new(self).login
  end

  get '/logout' do
    AuthController.new(self).logout
  end

  # === API路由 ===
  get '/api/version' do
    ApiController.new(self).version
  end

  get '/api/health' do
    ApiController.new(self).health
  end

  get '/api/stats' do
    ApiController.new(self).stats
  end

  get '/api/monitor' do
    ApiController.new(self).system_monitor
  end

  # === 用户信息API ===
  get '/api/user' do
    AuthController.new(self).current_user_info
  end

  post '/api/user/password' do
    AuthController.new(self).change_password
  end

  put '/api/user/profile' do
    AuthController.new(self).update_profile
  end

  # === 主页 ===
  get '/' do
    login_required
    @projects = PermissionService.get_user_accessible_projects(current_user).limit(10).all
    @recent_builds = Build.order(Sequel.desc(:created_at)).limit(10).all
    @system_stats = {
      projects: Project.count,
      users: User.count,
      builds_today: Build.where('created_at > ?', Date.today).count,
      online_resources: Resource.where(status: 'online').count
    }
    haml :index
  end

  # === 工作空间路由 ===
  get '/workspaces' do
    WorkspaceController.new(self).index
  end

  get '/workspaces/new' do
    WorkspaceController.new(self).new
  end

  post '/workspaces' do
    WorkspaceController.new(self).create
  end

  get '/workspaces/:id' do
    WorkspaceController.new(self).show
  end

  get '/workspaces/:id/edit' do
    WorkspaceController.new(self).edit
  end

  put '/workspaces/:id' do
    WorkspaceController.new(self).update
  end

  delete '/workspaces/:id' do
    WorkspaceController.new(self).delete
  end

  get '/workspaces/:id/members' do
    WorkspaceController.new(self).members
  end

  post '/workspaces/:id/members' do
    WorkspaceController.new(self).add_member
  end

  delete '/workspaces/:id/members/:user_id' do
    WorkspaceController.new(self).remove_member
  end

  # === 项目管理路由 ===
  get '/projects' do
    login_required
    @projects = PermissionService.get_user_accessible_projects(current_user).order(:name).all
    haml :projects
  end

  get '/projects/new' do
    login_required
    @workspaces = if current_user.admin?
      Workspace.all
    else
      Workspace.where(owner_id: current_user.id)
    end
    haml :project_form
  end

  post '/projects' do
    login_required
    project_data = params.merge(user_id: current_user.id)
    project = Project.create(project_data)
    
    LogService.user_log('info', "创建项目: #{project.name}", current_user.id, request.ip)
    
    if request.accept.include?('application/json')
      success_response('项目创建成功', project.to_hash)
    else
      flash[:success] = '项目创建成功'
      redirect '/projects'
    end
  end

  # === 资产管理路由 ===
  get '/assets' do
    AssetController.new(self).index
  end

  get '/assets/machines' do
    AssetController.new(self).machines
  end

  get '/assets/machines/new' do
    AssetController.new(self).new_machine
  end

  post '/assets/machines' do
    AssetController.new(self).create_machine
  end

  get '/assets/machines/:id' do
    AssetController.new(self).machine_detail
  end

  post '/assets/machines/:id/test' do
    AssetController.new(self).test_machine_connection
  end

  post '/assets/machines/:id/execute' do
    AssetController.new(self).execute_ssh_command
  end

  get '/assets/ssh' do
    AssetController.new(self).ssh_resources
  end

  post '/assets/machines/:id/ssh-key' do
    AssetController.new(self).upload_ssh_key
  end

  get '/assets/docker' do
    AssetController.new(self).docker_resources
  end

  get '/assets/docker/:machine_id/containers' do
    AssetController.new(self).docker_containers
  end

  post '/assets/docker/:machine_id/:action/:container_id' do
    AssetController.new(self).docker_action
  end

  # === 系统管理路由 ===
  get '/system' do
    SystemController.new(self).index
  end

  get '/system/users' do
    SystemController.new(self).users
  end

  get '/system/users/new' do
    SystemController.new(self).new_user
  end

  post '/system/users' do
    SystemController.new(self).create_user
  end

  get '/system/users/:id' do
    SystemController.new(self).user_detail
  end

  put '/system/users/:id' do
    SystemController.new(self).update_user
  end

  delete '/system/users/:id' do
    SystemController.new(self).delete_user
  end

  get '/system/configs' do
    SystemController.new(self).configs
  end

  post '/system/configs' do
    SystemController.new(self).update_config
  end

  delete '/system/configs/:id' do
    SystemController.new(self).delete_config
  end

  get '/system/monitor' do
    SystemController.new(self).monitor
  end

  get '/system/logs' do
    SystemController.new(self).logs
  end

  delete '/system/logs/clean' do
    SystemController.new(self).clean_logs
  end

  get '/system/upgrade' do
    SystemController.new(self).upgrade
  end

  post '/system/upgrade/check' do
    SystemController.new(self).check_update
  end

  post '/system/upgrade/perform' do
    SystemController.new(self).perform_upgrade
  end

  post '/system/backup' do
    SystemController.new(self).backup
  end

  post '/system/restore' do
    SystemController.new(self).restore
  end

  # === 错误处理 ===
  not_found do
    if request.accept.include?('application/json')
      json_response({ success: false, message: '页面不存在' }, 404)
    else
      haml :not_found
    end
  end

  error do
    error = env['sinatra.error']
    
    LogService.log(
      type: 'system',
      level: 'error',
      message: "应用程序错误: #{error.message}",
      user_id: current_user&.id,
      ip_address: request.ip,
      source: 'sinatra_error',
      details: {
        error_class: error.class.name,
        backtrace: error.backtrace&.first(10)
      }
    )

    if request.accept.include?('application/json')
      json_response({ success: false, message: '服务器内部错误' }, 500)
    else
      haml :error
    end
  end

  # 应用程序启动后的初始化
  configure do
    # 记录启动日志
    LogService.system_log('info', 'Jpom CICD系统启动', {
      version: '2.0.0',
      ruby_version: RUBY_VERSION,
      sinatra_version: Sinatra::VERSION
    })

    # 清理孤立权限
    Thread.new do
      sleep 5 # 等待应用完全启动
      PermissionService.cleanup_orphaned_permissions
    end

    puts "Jpom CICD系统已启动 - 端口: #{CONFIG['app_port']}"
    puts "WebSocket服务端口: #{CONFIG['websocket_port'] || 8080}"
    puts "访问地址: http://localhost:#{CONFIG['app_port']}"
  end
end

# 启动WebSocket服务器（在单独的线程中）
Thread.new do
  begin
    require_relative 'lib/websocket/websocket_server'
    WebSocketServer.start(CONFIG['websocket_port'] || 8080)
  rescue => e
    puts "WebSocket服务器启动失败: #{e.message}"
  end
end

# 运行应用程序
if __FILE__ == $0
  JpomApp.run!
end