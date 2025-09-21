# Docker资源模型
class DockerResource < BaseModel(:docker_resources)
  many_to_one :resource

  def validate
    super
    validates_presence [:name, :resource_id]
    validates_includes ['running', 'stopped', 'error'], :status
  end

  def get_containers
    return [] unless resource&.online?
    
    begin
      result = resource.execute_command('docker ps -a --format "{{.ID}}\t{{.Image}}\t{{.Names}}\t{{.Status}}"')
      
      if result[:success]
        parse_containers(result[:output])
      else
        []
      end
    rescue
      []
    end
  end

  def get_images
    return [] unless resource&.online?
    
    begin
      result = resource.execute_command('docker images --format "{{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}"')
      
      if result[:success]
        parse_images(result[:output])
      else
        []
      end
    rescue
      []
    end
  end

  def docker_info
    return {} unless resource&.online?
    
    begin
      result = resource.execute_command('docker info --format "{{json .}}"')
      
      if result[:success]
        JSON.parse(result[:output])
      else
        {}
      end
    rescue
      {}
    end
  end

  def docker_version
    return {} unless resource&.online?
    
    begin
      result = resource.execute_command('docker version --format "{{json .}}"')
      
      if result[:success]
        JSON.parse(result[:output])
      else
        {}
      end
    rescue
      {}
    end
  end

  def execute_docker_command(command)
    return { success: false, error: '资源不在线' } unless resource&.online?
    
    # 安全检查，只允许特定的docker命令
    allowed_commands = %w[ps images info version pull run stop start restart rm rmi]
    command_parts = command.split(' ')
    
    unless command_parts.first == 'docker' && allowed_commands.include?(command_parts[1])
      return { success: false, error: '不允许的Docker命令' }
    end
    
    resource.execute_command(command)
  end

  def start_container(container_id)
    execute_docker_command("docker start #{container_id}")
  end

  def stop_container(container_id)
    execute_docker_command("docker stop #{container_id}")
  end

  def restart_container(container_id)
    execute_docker_command("docker restart #{container_id}")
  end

  def remove_container(container_id, force: false)
    command = "docker rm #{container_id}"
    command += " -f" if force
    execute_docker_command(command)
  end

  def get_container_logs(container_id, lines: 100, follow: false)
    command = "docker logs --tail #{lines} #{container_id}"
    command += " -f" if follow
    execute_docker_command(command)
  end

  def to_hash
    super.merge(
      resource_name: resource&.name,
      resource_ip: resource&.ip,
      container_count: get_containers.length,
      image_count: get_images.length
    )
  end

  private

  def parse_containers(output)
    containers = []
    output.split("\n").each do |line|
      parts = line.split("\t")
      next if parts.length < 4
      
      containers << {
        id: parts[0],
        image: parts[1],
        name: parts[2],
        status: parts[3]
      }
    end
    containers
  end

  def parse_images(output)
    images = []
    output.split("\n").each do |line|
      parts = line.split("\t")
      next if parts.length < 4
      
      images << {
        repository: parts[0],
        tag: parts[1],
        id: parts[2],
        size: parts[3]
      }
    end
    images
  end
end