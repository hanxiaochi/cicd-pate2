# 日志中间件
class LoggingMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    start_time = Time.now
    request = Rack::Request.new(env)
    
    # 记录请求开始
    request_id = generate_request_id
    env['REQUEST_ID'] = request_id
    
    # 执行请求
    status, headers, response = @app.call(env)
    
    # 计算耗时
    duration = Time.now - start_time
    
    # 记录请求日志
    log_request(request, status, duration, request_id)
    
    [status, headers, response]
  rescue => e
    # 记录错误日志
    log_error(request, e, generate_request_id)
    raise e
  end

  private

  def generate_request_id
    SecureRandom.hex(8)
  end

  def log_request(request, status, duration, request_id)
    user_id = get_user_id_from_session(request)
    
    # 只记录重要的请求
    return if should_skip_logging?(request)
    
    level = case status
           when 200..299 then 'info'
           when 400..499 then 'warn'
           when 500..599 then 'error'
           else 'info'
           end

    message = "#{request.request_method} #{request.path} - #{status} (#{duration.round(3)}s)"
    
    LogService.log(
      type: 'system',
      level: level,
      message: message,
      user_id: user_id,
      ip_address: request.ip,
      source: 'web_request',
      details: {
        request_id: request_id,
        method: request.request_method,
        path: request.path,
        status: status,
        duration: duration,
        user_agent: request.user_agent,
        referer: request.referer
      }
    )
  end

  def log_error(request, error, request_id)
    user_id = get_user_id_from_session(request)
    
    LogService.log(
      type: 'system',
      level: 'error',
      message: "请求异常: #{error.message}",
      user_id: user_id,
      ip_address: request.ip,
      source: 'web_request',
      details: {
        request_id: request_id,
        method: request.request_method,
        path: request.path,
        error_class: error.class.name,
        error_message: error.message,
        backtrace: error.backtrace&.first(10)
      }
    )
  end

  def get_user_id_from_session(request)
    session = request.session
    session[:user_id] if session
  rescue
    nil
  end

  def should_skip_logging?(request)
    # 跳过静态资源请求
    return true if request.path.match?(/\.(css|js|png|jpg|gif|ico|svg)$/)
    
    # 跳过健康检查
    return true if request.path == '/health'
    
    # 跳过API心跳
    return true if request.path == '/api/ping'
    
    false
  end
end

# 权限中间件
class PermissionMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    
    # 跳过不需要权限检查的路径
    if should_skip_permission_check?(request)
      return @app.call(env)
    end

    # 检查用户是否登录
    user = get_current_user(request)
    unless user
      return redirect_to_login(request)
    end

    # 检查用户权限
    unless check_user_permission(user, request)
      return permission_denied_response(request)
    end

    # 记录访问日志
    log_access(user, request)
    
    @app.call(env)
  end

  private

  def should_skip_permission_check?(request)
    skip_paths = [
      '/login',
      '/logout',
      '/api/health',
      '/api/version',
      '/public'
    ]
    
    skip_paths.any? { |path| request.path.start_with?(path) } ||
      request.path.match?(/\.(css|js|png|jpg|gif|ico|svg)$/)
  end

  def get_current_user(request)
    session = request.session
    return nil unless session && session[:user_id]
    
    User[session[:user_id]]
  rescue
    nil
  end

  def check_user_permission(user, request)
    # 管理员有全部权限
    return true if user.admin?
    
    # 检查特定路径的权限
    case request.path
    when %r{^/admin}
      false # 只有管理员能访问管理页面
    when %r{^/system}
      PermissionService.check_system_access(user, 'system_config')
    when %r{^/projects/(\d+)}
      project_id = $1.to_i
      project = Project[project_id]
      project && PermissionService.check_project_access(user, project, get_permission_type(request))
    when %r{^/resources/(\d+)}
      resource_id = $1.to_i
      resource = Resource[resource_id]
      resource && PermissionService.check_resource_access(user, resource, get_permission_type(request))
    else
      true # 其他路径默认允许
    end
  end

  def get_permission_type(request)
    case request.request_method
    when 'GET' then 'read'
    when 'POST', 'PUT', 'PATCH' then 'write'
    when 'DELETE' then 'admin'
    else 'read'
    end
  end

  def redirect_to_login(request)
    if request.xhr? || request.content_type == 'application/json'
      json_response = { success: false, message: '请先登录', redirect: '/login' }.to_json
      [401, { 'Content-Type' => 'application/json' }, [json_response]]
    else
      redirect_url = "/login?redirect=#{CGI.escape(request.fullpath)}"
      [302, { 'Location' => redirect_url }, []]
    end
  end

  def permission_denied_response(request)
    if request.xhr? || request.content_type == 'application/json'
      json_response = { success: false, message: '权限不足' }.to_json
      [403, { 'Content-Type' => 'application/json' }, [json_response]]
    else
      [403, { 'Content-Type' => 'text/html' }, ['<h1>403 权限不足</h1>']]
    end
  end

  def log_access(user, request)
    # 只记录重要的访问
    return if request.path.match?(/\.(css|js|png|jpg|gif|ico|svg)$/)
    
    LogService.user_log(
      'info',
      "访问页面: #{request.request_method} #{request.path}",
      user.id,
      request.ip,
      {
        method: request.request_method,
        path: request.path,
        user_agent: request.user_agent
      }
    )
  end
end

# 安全中间件
class SecurityMiddleware
  def initialize(app)
    @app = app
    @failed_attempts = {}
    @blocked_ips = {}
  end

  def call(env)
    request = Rack::Request.new(env)
    
    # 检查IP是否被阻止
    if ip_blocked?(request.ip)
      return rate_limit_response
    end

    # 执行请求
    status, headers, response = @app.call(env)
    
    # 检查登录失败
    if login_failed?(request, status)
      handle_failed_login(request.ip)
    elsif login_success?(request, status)
      clear_failed_attempts(request.ip)
    end
    
    # 添加安全头
    headers = add_security_headers(headers)
    
    [status, headers, response]
  end

  private

  def ip_blocked?(ip)
    blocked_until = @blocked_ips[ip]
    return false unless blocked_until
    
    if Time.now > blocked_until
      @blocked_ips.delete(ip)
      false
    else
      true
    end
  end

  def login_failed?(request, status)
    request.path == '/login' && 
    request.request_method == 'POST' && 
    status >= 400
  end

  def login_success?(request, status)
    request.path == '/login' && 
    request.request_method == 'POST' && 
    status < 400
  end

  def handle_failed_login(ip)
    @failed_attempts[ip] ||= { count: 0, first_attempt: Time.now }
    @failed_attempts[ip][:count] += 1
    
    # 如果5分钟内失败超过5次，阻止IP 15分钟
    if @failed_attempts[ip][:count] >= 5 &&
       Time.now - @failed_attempts[ip][:first_attempt] <= 300
      
      @blocked_ips[ip] = Time.now + 900 # 15分钟后解封
      
      LogService.security_log(
        'warn',
        "IP地址 #{ip} 因登录失败次数过多被阻止",
        nil,
        ip,
        { failed_attempts: @failed_attempts[ip][:count] }
      )
    end
  end

  def clear_failed_attempts(ip)
    @failed_attempts.delete(ip)
  end

  def rate_limit_response
    [429, { 'Content-Type' => 'application/json' }, 
     [{ success: false, message: '请求过于频繁，请稍后再试' }.to_json]]
  end

  def add_security_headers(headers)
    headers.merge(
      'X-Frame-Options' => 'DENY',
      'X-Content-Type-Options' => 'nosniff',
      'X-XSS-Protection' => '1; mode=block',
      'Referrer-Policy' => 'strict-origin-when-cross-origin'
    )
  end
end