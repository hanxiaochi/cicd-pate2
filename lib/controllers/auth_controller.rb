# 认证控制器
class AuthController < BaseController
  # 登录页面
  def login_page
    if current_user
      redirect '/'
    else
      haml :login
    end
  end

  # 用户登录
  def login
    validate_params([:username, :password])
    
    user = User.find(username: params[:username])
    
    if user&.authenticate(params[:password])
      if user.active
        session[:user_id] = user.id
        user.update_last_login
        
        log_action('用户登录', { username: user.username })
        
        if request.accept.include?('application/json')
          success_response('登录成功', { user: user.to_hash })
        else
          flash[:success] = '登录成功'
          redirect params[:redirect] || '/'
        end
      else
        if request.accept.include?('application/json')
          error_response('账户已被禁用', 401)
        else
          flash[:error] = '账户已被禁用'
          redirect '/login'
        end
      end
    else
      log_action('登录失败', { username: params[:username], ip: request.ip })
      
      if request.accept.include?('application/json')
        error_response('用户名或密码错误', 401)
      else
        flash[:error] = '用户名或密码错误'
        redirect '/login'
      end
    end
  end

  # 用户登出
  def logout
    if current_user
      log_action('用户登出', { username: current_user.username })
    end
    
    session.clear
    
    if request.accept.include?('application/json')
      success_response('登出成功')
    else
      flash[:success] = '已安全登出'
      redirect '/login'
    end
  end

  # 获取当前用户信息
  def current_user_info
    login_required
    success_response('获取用户信息成功', current_user.to_hash)
  end

  # 修改密码
  def change_password
    login_required
    validate_params([:current_password, :new_password])
    
    unless current_user.authenticate(params[:current_password])
      return error_response('当前密码错误', 400)
    end

    if params[:new_password].length < 6
      return error_response('新密码长度至少6位', 400)
    end

    current_user.update(
      password_hash: BCrypt::Password.create(params[:new_password])
    )

    log_action('修改密码')
    success_response('密码修改成功')
  end

  # 更新用户信息
  def update_profile
    login_required
    
    allowed_fields = [:email, :phone, :department]
    update_data = params.select { |k, v| allowed_fields.include?(k.to_sym) }
    
    if update_data.any?
      current_user.update(update_data)
      log_action('更新个人信息', update_data)
      success_response('个人信息更新成功')
    else
      error_response('没有需要更新的信息')
    end
  end
end