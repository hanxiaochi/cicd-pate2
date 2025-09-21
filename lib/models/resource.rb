# 资源模型
class Resource < BaseModel(:resources)
  one_to_many :services

  def validate
    super
    validates_presence [:name, :ip]
    validates_format /\A\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\z/, :ip, message: 'IP地址格式不正确'
    validates_includes ['linux', 'windows', 'macos'], :os_type
  end

  def online?
    status == 'online'
  end

  def check_connectivity
    begin
      require 'timeout'
      require 'socket'
      
      Timeout::timeout(5) do
        TCPSocket.new(ip, ssh_port || 22).close
      end
      
      update(status: 'online', last_check: Time.now)
      true
    rescue
      update(status: 'offline', last_check: Time.now)
      false
    end
  end

  def ssh_connect(&block)
    options = {
      port: ssh_port || 22,
      timeout: 10
    }

    if ssh_key_path && File.exist?(ssh_key_path)
      options[:keys] = [ssh_key_path]
    elsif password_hash
      options[:password] = BCrypt::Password.new(password_hash)
    end

    Net::SSH.start(ip, username, options) do |ssh|
      yield ssh if block_given?
    end
  end

  def execute_command(command)
    result = { success: false, output: '', error: '' }
    
    begin
      ssh_connect do |ssh|
        output = ssh.exec!(command)
        result[:success] = true
        result[:output] = output
      end
    rescue => e
      result[:error] = e.message
    end
    
    result
  end
end