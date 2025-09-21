# 基础控制器
class BaseController
  include Sinatra::Flash

  def initialize(app)
    @app = app
  end

  # 通用辅助方法
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

  def log_action(action, details = {})
    LogService.log(
      type: 'user',
      level: 'info',
      message: action,
      user_id: current_user&.id,
      ip_address: request.ip,
      details: details
    )
  end

  def validate_params(required_params)
    missing = required_params.select { |param| params[param].nil? || params[param].empty? }
    
    unless missing.empty?
      halt 400, error_response("缺少必要参数: #{missing.join(', ')}")
    end
  end

  def paginate_params
    {
      page: (params[:page] || 1).to_i,
      per_page: [(params[:per_page] || 20).to_i, 100].min
    }
  end

  # 检查用户权限
  def check_permission(resource_type, resource_id = nil, permission_type = 'read')
    unless current_user.can_access?(resource_type, resource_id, permission_type)
      halt 403, error_response('权限不足')
    end
  end
end