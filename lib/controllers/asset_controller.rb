# 资产管理控制器
class AssetController < BaseController
  # 资产总览
  def index
    login_required
    
    assets_summary = {
      machines: {
        total: Resource.count,
        online: Resource.where(status: 'online').count,
        offline: Resource.where(status: 'offline').count
      },
      ssh_resources: {
        total: Resource.where(Sequel.~(ssh_key_path: nil)).count,
        key_auth: Resource.where(Sequel.~(ssh_key_path: nil)).count,
        password_auth: Resource.where(ssh_key_path: nil).count
      },
      docker_resources: {
        total: DockerResource.count,
        running: DockerResource.where(status: 'running').count,
        stopped: DockerResource.where(status: 'stopped').count
      }
    }

    if request.accept.include?('application/json')
      success_response('获取资产概览成功', assets_summary)
    else
      @assets_summary = assets_summary
      @recent_resources = Resource.order(Sequel.desc(:created_at)).limit(10).all
      haml :'assets/index'
    end
  end

  # 机器资源列表
  def machines
    login_required
    check_permission('resource', nil, 'read')
    
    page_params = paginate_params
    
    # 过滤条件
    filters = {}
    filters[:status] = params[:status] if params[:status] && !params[:status].empty?
    filters[:os_type] = params[:os_type] if params[:os_type] && !params[:os_type].empty?
    
    # 搜索
    machines_dataset = Resource.where(filters)
    if params[:search] && !params[:search].empty?
      search_term = "%#{params[:search]}%"
      machines_dataset = machines_dataset.where(
        Sequel.|(
          { name: search_term },
          { ip: search_term },
          { description: search_term }
        )
      )
    end

    machines = machines_dataset.order(:name)
                              .paginate(**page_params)
                              .map(&:to_hash)

    if request.accept.include?('application/json')
      success_response('获取机器资源列表成功', {
        machines: machines,
        pagination: {
          page: page_params[:page],
          per_page: page_params[:per_page],
          total: machines_dataset.count
        }
      })
    else
      @machines = machines
      @filters = { status: params[:status], os_type: params[:os_type], search: params[:search] }
      haml :'assets/machines'
    end
  end

  # 创建机器资源页面
  def new_machine
    login_required
    check_permission('resource', nil, 'write')
    haml :'assets/new_machine'
  end

  # 创建机器资源
  def create_machine
    login_required
    check_permission('resource', nil, 'write')
    validate_params([:name, :ip])

    machine_data = {
      name: params[:name],
      ip: params[:ip],
      ssh_port: params[:ssh_port] || 22,
      username: params[:username],
      description: params[:description],
      os_type: params[:os_type] || 'linux'
    }

    # 处理认证方式
    if params[:auth_type] == 'password' && params[:password]
      machine_data[:password_hash] = BCrypt::Password.create(params[:password])
    elsif params[:auth_type] == 'ssh_key' && params[:ssh_key_path]
      machine_data[:ssh_key_path] = params[:ssh_key_path]
    end

    begin
      machine = Resource.create(machine_data)
      
      # 测试连接
      if params[:test_connection] == 'true'
        Thread.new { machine.check_connectivity }
      end

      log_action('创建机器资源', { machine_id: machine.id, name: machine.name, ip: machine.ip })

      if request.accept.include?('application/json')
        success_response('机器资源创建成功', machine.to_hash)
      else
        flash[:success] = '机器资源创建成功'
        redirect '/assets/machines'
      end
    rescue Sequel::ValidationFailed => e
      if request.accept.include?('application/json')
        error_response("创建失败: #{e.message}")
      else
        flash[:error] = "创建失败: #{e.message}"
        redirect '/assets/machines/new'
      end
    end
  end

  # 机器资源详情
  def machine_detail
    login_required
    machine = find_machine_with_permission
    
    # 获取机器上的服务
    services = machine.services.map(&:to_hash)
    
    # 获取最近的操作日志
    recent_logs = Log.where(source: "machine_#{machine.id}")
                    .order(Sequel.desc(:created_at))
                    .limit(20)
                    .map(&:to_hash)

    machine_data = machine.to_hash.merge(
      services: services,
      recent_logs: recent_logs
    )

    if request.accept.include?('application/json')
      success_response('获取机器详情成功', machine_data)
    else
      @machine = machine_data
      haml :'assets/machine_detail'
    end
  end

  # 测试机器连接
  def test_machine_connection
    login_required
    machine = find_machine_with_permission
    
    result = machine.check_connectivity
    
    log_action('测试机器连接', { 
      machine_id: machine.id, 
      result: result ? 'success' : 'failed' 
    })

    if result
      success_response('连接测试成功', { status: 'online' })
    else
      error_response('连接测试失败', 400)
    end
  end

  # 执行SSH命令
  def execute_ssh_command
    login_required
    machine = find_machine_with_permission('write')
    validate_params([:command])

    begin
      result = machine.execute_command(params[:command])
      
      log_action('执行SSH命令', {
        machine_id: machine.id,
        command: params[:command],
        success: result[:success]
      })

      if result[:success]
        success_response('命令执行成功', result)
      else
        error_response("命令执行失败: #{result[:error]}")
      end
    rescue => e
      log_action('SSH命令执行异常', {
        machine_id: machine.id,
        command: params[:command],
        error: e.message
      })
      error_response("执行异常: #{e.message}")
    end
  end

  # SSH资源管理
  def ssh_resources
    login_required
    check_permission('resource', nil, 'read')
    
    page_params = paginate_params
    
    # 只显示配置了SSH的资源
    ssh_resources_dataset = Resource.where(Sequel.~(username: nil))
    
    # 过滤条件
    if params[:auth_type] == 'key'
      ssh_resources_dataset = ssh_resources_dataset.where(Sequel.~(ssh_key_path: nil))
    elsif params[:auth_type] == 'password'
      ssh_resources_dataset = ssh_resources_dataset.where(ssh_key_path: nil)
    end

    ssh_resources = ssh_resources_dataset.order(:name)
                                       .paginate(**page_params)
                                       .map do |resource|
      resource.to_hash.merge(
        auth_type: resource.ssh_key_path ? 'key' : 'password',
        has_key: !resource.ssh_key_path.nil?,
        key_file_exists: resource.ssh_key_path && File.exist?(resource.ssh_key_path)
      )
    end

    if request.accept.include?('application/json')
      success_response('获取SSH资源列表成功', {
        ssh_resources: ssh_resources,
        pagination: {
          page: page_params[:page],
          per_page: page_params[:per_page],
          total: ssh_resources_dataset.count
        }
      })
    else
      @ssh_resources = ssh_resources
      haml :'assets/ssh_resources'
    end
  end

  # 上传SSH密钥
  def upload_ssh_key
    login_required
    machine = find_machine_with_permission('write')
    
    unless params[:ssh_key] && params[:ssh_key][:tempfile]
      return error_response('请选择SSH密钥文件')
    end

    begin
      # 创建SSH密钥目录
      ssh_keys_dir = File.join(CONFIG['temp_dir'], 'ssh_keys')
      FileUtils.mkdir_p(ssh_keys_dir)
      
      # 保存SSH密钥文件
      key_filename = "#{machine.id}_#{Time.now.to_i}.key"
      key_path = File.join(ssh_keys_dir, key_filename)
      
      File.open(key_path, 'wb') do |f|
        f.write(params[:ssh_key][:tempfile].read)
      end
      
      # 设置密钥文件权限
      File.chmod(0600, key_path)
      
      # 更新机器配置
      machine.update(ssh_key_path: key_path)
      
      log_action('上传SSH密钥', { machine_id: machine.id, key_path: key_path })
      
      success_response('SSH密钥上传成功')
    rescue => e
      error_response("上传失败: #{e.message}")
    end
  end

  # Docker资源管理
  def docker_resources
    login_required
    check_permission('resource', nil, 'read')
    
    page_params = paginate_params
    
    docker_resources = DockerResource.order(:name)
                                   .paginate(**page_params)
                                   .map(&:to_hash)

    if request.accept.include?('application/json')
      success_response('获取Docker资源列表成功', {
        docker_resources: docker_resources,
        pagination: {
          page: page_params[:page],
          per_page: page_params[:per_page],
          total: DockerResource.count
        }
      })
    else
      @docker_resources = docker_resources
      haml :'assets/docker_resources'
    end
  end

  # 获取Docker容器列表
  def docker_containers
    login_required
    machine = find_machine_with_permission
    
    begin
      result = machine.execute_command('docker ps -a --format "table {{.ID}}\t{{.Image}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"')
      
      if result[:success]
        containers = parse_docker_containers(result[:output])
        success_response('获取容器列表成功', { containers: containers })
      else
        error_response("获取容器列表失败: #{result[:error]}")
      end
    rescue => e
      error_response("操作异常: #{e.message}")
    end
  end

  # Docker操作（启动/停止/重启容器）
  def docker_action
    login_required
    machine = find_machine_with_permission('write')
    validate_params([:action, :container_id])
    
    allowed_actions = ['start', 'stop', 'restart', 'remove']
    unless allowed_actions.include?(params[:action])
      return error_response('不支持的操作')
    end

    begin
      command = "docker #{params[:action]} #{params[:container_id]}"
      result = machine.execute_command(command)
      
      log_action('Docker容器操作', {
        machine_id: machine.id,
        action: params[:action],
        container_id: params[:container_id],
        success: result[:success]
      })

      if result[:success]
        success_response("容器#{params[:action]}操作成功")
      else
        error_response("操作失败: #{result[:error]}")
      end
    rescue => e
      error_response("操作异常: #{e.message}")
    end
  end

  # 获取容器日志
  def container_logs
    login_required
    machine = find_machine_with_permission
    validate_params([:container_id])
    
    lines = params[:lines] || 100
    follow = params[:follow] == 'true'
    
    begin
      command = "docker logs --tail #{lines} #{params[:container_id]}"
      command += " -f" if follow
      
      result = machine.execute_command(command)
      
      if result[:success]
        success_response('获取容器日志成功', { logs: result[:output] })
      else
        error_response("获取日志失败: #{result[:error]}")
      end
    rescue => e
      error_response("操作异常: #{e.message}")
    end
  end

  private

  def find_machine_with_permission(required_permission = 'read')
    machine = Resource[params[:id]] || Resource[params[:machine_id]]
    
    unless machine
      if request.accept.include?('application/json')
        halt 404, error_response('机器资源不存在', 404)
      else
        flash[:error] = '机器资源不存在'
        halt redirect('/assets/machines')
      end
    end

    check_permission('resource', machine.id, required_permission)
    machine
  end

  def parse_docker_containers(output)
    containers = []
    lines = output.split("\n")
    
    # 跳过表头
    lines[1..-1]&.each do |line|
      parts = line.split("\t")
      next if parts.length < 4
      
      containers << {
        id: parts[0],
        image: parts[1],
        name: parts[2],
        status: parts[3],
        ports: parts[4] || ''
      }
    end
    
    containers
  end
end