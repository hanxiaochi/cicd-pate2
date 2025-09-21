# 应用程序配置
require 'sinatra'
require 'sinatra/flash'
require 'haml'
require 'sequel'
require 'bcrypt'
require 'fileutils'
require 'json'
require 'net/ssh'
require 'websocket-eventmachine-server'

# 加载所有库文件
Dir[File.join(File.dirname(__FILE__), '../lib/**/*.rb')].each { |file| require file }

# 应用程序配置类
class ApplicationConfig
  def self.load_config
    config_path = File.join(File.dirname(__FILE__), '../config.json')
    if File.exist?(config_path)
      JSON.parse(File.read(config_path))
    else
      {
        "app_port" => 4567,
        "log_level" => "info",
        "temp_dir" => "./tmp",
        "ssh_default_port" => 22,
        "docker_support" => true,
        "websocket_port" => 8080
      }
    end
  end

  def self.initialize_database
    DB = Sequel.sqlite('cicd.db')
    
    # 初始化所有数据表
    DatabaseInitializer.create_tables
  end

  def self.configure_sinatra(app)
    app.configure do
      app.set :bind, '0.0.0.0'
      app.set :port, CONFIG['app_port']
      app.set :views, './views'
      app.set :public_folder, './public'
      app.enable :sessions
      app.set :session_secret, 'jpom_cicd_secret_key'
    end
  end
end

# 全局配置
CONFIG = ApplicationConfig.load_config