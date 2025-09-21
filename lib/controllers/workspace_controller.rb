# 工作空间控制器
class WorkspaceController < BaseController
  # 获取工作空间列表
  def index
    login_required
    
    page_params = paginate_params
    
    # 根据用户权限过滤工作空间
    workspaces_dataset = if current_user.admin?
      Workspace.all
    else
      # 获取用户拥有的和有权限访问的工作空间
      owned_workspaces = Workspace.where(owner_id: current_user.id)
      accessible_workspace_ids = Permission.where(
        user_id: current_user.id,
        resource_type: 'workspace'
      ).select(:resource_id)
      
      Workspace.where(
        Sequel.|({ id: owned_workspaces.select(:id) }, { id: accessible_workspace_ids })
      )
    end
    
    workspaces = workspaces_dataset.order(:name)
                                  .paginate(**page_params)
                                  .map(&:to_hash)

    if request.accept.include?('application/json')
      success_response('获取工作空间列表成功', {
        workspaces: workspaces,
        pagination: {
          page: page_params[:page],
          per_page: page_params[:per_page],
          total: workspaces_dataset.count
        }
      })
    else
      @workspaces = workspaces
      haml :'workspace/index'
    end
  end

  # 获取单个工作空间详情
  def show
    login_required
    workspace = Workspace[params[:id]]
    
    unless workspace
      if request.accept.include?('application/json')
        return error_response('工作空间不存在', 404)
      else
        flash[:error] = '工作空间不存在'
        return redirect '/workspaces'
      end
    end

    unless workspace.can_access?(current_user)
      if request.accept.include?('application/json')
        return error_response('权限不足', 403)
      else
        flash[:error] = '权限不足'
        return redirect '/workspaces'
      end
    end

    workspace_data = workspace.to_hash.merge(
      projects: workspace.projects.map(&:to_hash),
      recent_builds: workspace.recent_builds.map(&:to_hash)
    )

    if request.accept.include?('application/json')
      success_response('获取工作空间详情成功', workspace_data)
    else
      @workspace = workspace_data
      haml :'workspace/show'
    end
  end

  # 创建工作空间页面
  def new
    login_required
    haml :'workspace/new'
  end

  # 创建工作空间
  def create
    login_required
    validate_params([:name])

    workspace_data = {
      name: params[:name],
      description: params[:description],
      owner_id: current_user.id
    }

    begin
      workspace = Workspace.create(workspace_data)
      
      log_action('创建工作空间', { workspace_id: workspace.id, name: workspace.name })

      if request.accept.include?('application/json')
        success_response('工作空间创建成功', workspace.to_hash)
      else
        flash[:success] = '工作空间创建成功'
        redirect "/workspaces/#{workspace.id}"
      end
    rescue Sequel::ValidationFailed => e
      if request.accept.include?('application/json')
        error_response("创建失败: #{e.message}")
      else
        flash[:error] = "创建失败: #{e.message}"
        redirect '/workspaces/new'
      end
    end
  end

  # 编辑工作空间页面
  def edit
    login_required
    @workspace = find_workspace_with_permission('write')
    haml :'workspace/edit'
  end

  # 更新工作空间
  def update
    login_required
    workspace = find_workspace_with_permission('write')

    allowed_fields = [:name, :description]
    update_data = params.select { |k, v| allowed_fields.include?(k.to_sym) }

    begin
      workspace.update(update_data)
      
      log_action('更新工作空间', { workspace_id: workspace.id, changes: update_data })

      if request.accept.include?('application/json')
        success_response('工作空间更新成功', workspace.to_hash)
      else
        flash[:success] = '工作空间更新成功'
        redirect "/workspaces/#{workspace.id}"
      end
    rescue Sequel::ValidationFailed => e
      if request.accept.include?('application/json')
        error_response("更新失败: #{e.message}")
      else
        flash[:error] = "更新失败: #{e.message}"
        redirect "/workspaces/#{workspace.id}/edit"
      end
    end
  end

  # 删除工作空间
  def delete
    login_required
    workspace = find_workspace_with_permission('admin')

    # 检查工作空间是否有项目
    if workspace.project_count > 0
      if request.accept.include?('application/json')
        return error_response('工作空间包含项目，无法删除')
      else
        flash[:error] = '工作空间包含项目，无法删除'
        return redirect "/workspaces/#{workspace.id}"
      end
    end

    workspace_name = workspace.name
    workspace.destroy

    log_action('删除工作空间', { workspace_name: workspace_name })

    if request.accept.include?('application/json')
      success_response('工作空间删除成功')
    else
      flash[:success] = '工作空间删除成功'
      redirect '/workspaces'
    end
  end

  # 工作空间成员管理
  def members
    login_required
    workspace = find_workspace_with_permission('admin')

    # 获取工作空间成员
    members = Permission.where(resource_type: 'workspace', resource_id: workspace.id)
                       .join(:users, id: :user_id)
                       .select(:users__id, :users__username, :users__email, :permission_type)
                       .all

    workspace_data = workspace.to_hash.merge(
      members: members.map do |member|
        {
          user_id: member[:id],
          username: member[:username],
          email: member[:email],
          permission: member[:permission_type]
        }
      end
    )

    if request.accept.include?('application/json')
      success_response('获取工作空间成员成功', workspace_data)
    else
      @workspace = workspace_data
      @all_users = User.where(active: true).exclude(id: workspace.owner_id).all
      haml :'workspace/members'
    end
  end

  # 添加工作空间成员
  def add_member
    login_required
    workspace = find_workspace_with_permission('admin')
    validate_params([:user_id, :permission_type])

    user = User[params[:user_id]]
    unless user
      return error_response('用户不存在', 404)
    end

    # 检查是否已经是成员
    existing_permission = Permission.where(
      user_id: user.id,
      resource_type: 'workspace',
      resource_id: workspace.id
    ).first

    if existing_permission
      return error_response('用户已经是工作空间成员')
    end

    Permission.create(
      user_id: user.id,
      resource_type: 'workspace',
      resource_id: workspace.id,
      permission_type: params[:permission_type]
    )

    log_action('添加工作空间成员', { 
      workspace_id: workspace.id, 
      user_id: user.id,
      permission: params[:permission_type]
    })

    success_response('添加成员成功')
  end

  # 移除工作空间成员
  def remove_member
    login_required
    workspace = find_workspace_with_permission('admin')
    validate_params([:user_id])

    permission = Permission.where(
      user_id: params[:user_id],
      resource_type: 'workspace',
      resource_id: workspace.id
    ).first

    unless permission
      return error_response('用户不是工作空间成员', 404)
    end

    permission.destroy

    log_action('移除工作空间成员', { 
      workspace_id: workspace.id, 
      user_id: params[:user_id]
    })

    success_response('移除成员成功')
  end

  # 更新成员权限
  def update_member_permission
    login_required
    workspace = find_workspace_with_permission('admin')
    validate_params([:user_id, :permission_type])

    permission = Permission.where(
      user_id: params[:user_id],
      resource_type: 'workspace',
      resource_id: workspace.id
    ).first

    unless permission
      return error_response('用户不是工作空间成员', 404)
    end

    permission.update(permission_type: params[:permission_type])

    log_action('更新工作空间成员权限', { 
      workspace_id: workspace.id, 
      user_id: params[:user_id],
      new_permission: params[:permission_type]
    })

    success_response('权限更新成功')
  end

  private

  def find_workspace_with_permission(required_permission = 'read')
    workspace = Workspace[params[:id]]
    
    unless workspace
      if request.accept.include?('application/json')
        halt 404, error_response('工作空间不存在', 404)
      else
        flash[:error] = '工作空间不存在'
        halt redirect('/workspaces')
      end
    end

    unless workspace.can_access?(current_user)
      if request.accept.include?('application/json')
        halt 403, error_response('权限不足', 403)
      else
        flash[:error] = '权限不足'
        halt redirect('/workspaces')
      end
    end

    # 检查特定权限
    if required_permission != 'read'
      unless current_user.admin? || workspace.owner_id == current_user.id
        permission = Permission.where(
          user_id: current_user.id,
          resource_type: 'workspace',
          resource_id: workspace.id,
          permission_type: required_permission
        ).first

        unless permission
          if request.accept.include?('application/json')
            halt 403, error_response('权限不足', 403)
          else
            flash[:error] = '权限不足'
            halt redirect("/workspaces/#{workspace.id}")
          end
        end
      end
    end

    workspace
  end
end