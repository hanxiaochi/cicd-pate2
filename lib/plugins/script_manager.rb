# 脚本管理器
class ScriptManager
  SCRIPT_TYPES = %w[shell python nodejs go php docker].freeze
  
  def self.create_script(name, content, script_type, description = nil)
    script_dir = get_script_directory(script_type)
    FileUtils.mkdir_p(script_dir)
    
    script_file = File.join(script_dir, "#{name}.#{get_script_extension(script_type)}")
    
    # 检查脚本是否已存在
    if File.exist?(script_file)
      raise "脚本 #{name} 已存在"
    end

    # 写入脚本内容
    File.write(script_file, content)
    
    # 设置执行权限
    File.chmod(0755, script_file) if script_type == 'shell'
    
    # 记录脚本信息到数据库
    script_record = Script.create(
      name: name,
      script_type: script_type,
      file_path: script_file,
      description: description,
      content_hash: Digest::SHA256.hexdigest(content)
    )

    script_record
  end

  def self.update_script(script_id, content)
    script = Script[script_id]
    raise "脚本不存在" unless script
    
    # 备份原脚本
    backup_script(script)
    
    # 更新脚本内容
    File.write(script.file_path, content)
    
    # 更新数据库记录
    script.update(
      content_hash: Digest::SHA256.hexdigest(content),
      updated_at: Time.now
    )

    script
  end

  def self.delete_script(script_id)
    script = Script[script_id]
    raise "脚本不存在" unless script
    
    # 备份脚本
    backup_script(script)
    
    # 删除文件
    File.delete(script.file_path) if File.exist?(script.file_path)
    
    # 删除数据库记录
    script.destroy
  end

  def self.execute_script(script_id, params = {}, resource = nil)
    script = Script[script_id]
    raise "脚本不存在" unless script
    
    unless File.exist?(script.file_path)
      raise "脚本文件不存在: #{script.file_path}"
    end

    case script.script_type
    when 'shell'
      execute_shell_script(script, params, resource)
    when 'python'
      execute_python_script(script, params, resource)
    when 'nodejs'
      execute_nodejs_script(script, params, resource)
    when 'docker'
      execute_docker_script(script, params, resource)
    else
      raise "不支持的脚本类型: #{script.script_type}"
    end
  end

  def self.validate_script(content, script_type)
    case script_type
    when 'shell'
      validate_shell_script(content)
    when 'python'
      validate_python_script(content)
    when 'nodejs'
      validate_nodejs_script(content)
    else
      { valid: true, errors: [] }
    end
  end

  def self.get_script_template(script_type, template_name = 'basic')
    templates = load_script_templates
    templates.dig(script_type, template_name) || generate_basic_template(script_type)
  end

  def self.list_scripts(script_type = nil, search = nil)
    dataset = Script.order(:name)
    dataset = dataset.where(script_type: script_type) if script_type
    
    if search
      search_term = "%#{search}%"
      dataset = dataset.where(
        Sequel.|(
          { name: search_term },
          { description: search_term }
        )
      )
    end

    dataset.all.map do |script|
      script.to_hash.merge(
        file_exists: File.exist?(script.file_path),
        file_size: File.exist?(script.file_path) ? File.size(script.file_path) : 0,
        last_executed: get_last_execution_time(script.id)
      )
    end
  end

  def self.get_script_content(script_id)
    script = Script[script_id]
    raise "脚本不存在" unless script
    
    unless File.exist?(script.file_path)
      raise "脚本文件不存在: #{script.file_path}"
    end

    {
      script: script.to_hash,
      content: File.read(script.file_path),
      file_stat: File.stat(script.file_path)
    }
  end

  def self.get_script_history(script_id)
    script = Script[script_id]
    raise "脚本不存在" unless script
    
    # 获取脚本执行历史
    ScriptExecution.where(script_id: script_id)
                   .order(Sequel.desc(:created_at))
                   .limit(50)
                   .all
                   .map(&:to_hash)
  end

  def self.clone_script(script_id, new_name)
    script = Script[script_id]
    raise "脚本不存在" unless script
    
    content = File.read(script.file_path)
    
    create_script(
      new_name,
      content,
      script.script_type,
      "克隆自: #{script.name}"
    )
  end

  private

  def self.get_script_directory(script_type)
    base_dir = File.join(CONFIG['temp_dir'], 'scripts')
    File.join(base_dir, script_type)
  end

  def self.get_script_extension(script_type)
    case script_type
    when 'shell' then 'sh'
    when 'python' then 'py'
    when 'nodejs' then 'js'
    when 'go' then 'go'
    when 'php' then 'php'
    when 'docker' then 'dockerfile'
    else 'txt'
    end
  end

  def self.backup_script(script)
    backup_dir = File.join(CONFIG['temp_dir'], 'script_backups')
    FileUtils.mkdir_p(backup_dir)
    
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    backup_file = File.join(backup_dir, "#{script.name}_#{timestamp}.bak")
    
    FileUtils.cp(script.file_path, backup_file) if File.exist?(script.file_path)
  end

  def self.execute_shell_script(script, params, resource)
    command = build_shell_command(script.file_path, params)
    
    if resource
      result = resource.execute_command(command)
    else
      result = execute_local_command(command)
    end

    record_execution(script.id, command, result, resource&.id)
    result
  end

  def self.execute_python_script(script, params, resource)
    python_cmd = params[:python_interpreter] || 'python3'
    args = params[:args] || ''
    command = "#{python_cmd} #{script.file_path} #{args}"
    
    if resource
      result = resource.execute_command(command)
    else
      result = execute_local_command(command)
    end

    record_execution(script.id, command, result, resource&.id)
    result
  end

  def self.execute_nodejs_script(script, params, resource)
    node_cmd = params[:node_interpreter] || 'node'
    args = params[:args] || ''
    command = "#{node_cmd} #{script.file_path} #{args}"
    
    if resource
      result = resource.execute_command(command)
    else
      result = execute_local_command(command)
    end

    record_execution(script.id, command, result, resource&.id)
    result
  end

  def self.execute_docker_script(script, params, resource)
    # Docker脚本通常是Dockerfile，需要构建镜像
    image_name = params[:image_name] || "script_#{script.id}"
    build_command = "docker build -f #{script.file_path} -t #{image_name} ."
    
    if resource
      result = resource.execute_command(build_command)
    else
      result = execute_local_command(build_command)
    end

    record_execution(script.id, build_command, result, resource&.id)
    result
  end

  def self.build_shell_command(script_path, params)
    command = "bash #{script_path}"
    
    # 添加环境变量
    if params[:env_vars]
      env_str = params[:env_vars].map { |k, v| "#{k}=#{v}" }.join(' ')
      command = "#{env_str} #{command}"
    end
    
    # 添加参数
    command += " #{params[:args]}" if params[:args]
    
    command
  end

  def self.execute_local_command(command)
    begin
      output = `#{command} 2>&1`
      exit_code = $?.exitstatus
      
      {
        success: exit_code == 0,
        output: output,
        exit_code: exit_code,
        error: exit_code != 0 ? output : nil
      }
    rescue => e
      {
        success: false,
        output: '',
        error: e.message,
        exit_code: -1
      }
    end
  end

  def self.record_execution(script_id, command, result, resource_id = nil)
    ScriptExecution.create(
      script_id: script_id,
      command: command,
      success: result[:success],
      output: result[:output],
      error: result[:error],
      exit_code: result[:exit_code],
      resource_id: resource_id,
      execution_time: Time.now
    )
  end

  def self.get_last_execution_time(script_id)
    execution = ScriptExecution.where(script_id: script_id)
                              .order(Sequel.desc(:execution_time))
                              .first
    execution&.execution_time
  end

  def self.validate_shell_script(content)
    # 基本的shell脚本验证
    errors = []
    
    # 检查是否有危险命令
    dangerous_commands = %w[rm -rf dd format fdisk mkfs halt reboot shutdown]
    dangerous_commands.each do |cmd|
      errors << "包含危险命令: #{cmd}" if content.include?(cmd)
    end
    
    # 检查语法（简单检查）
    if content.count('"').odd?
      errors << "双引号不匹配"
    end
    
    if content.count("'").odd?
      errors << "单引号不匹配"
    end

    {
      valid: errors.empty?,
      errors: errors
    }
  end

  def self.validate_python_script(content)
    # Python脚本验证
    errors = []
    
    # 检查是否有危险导入
    dangerous_imports = %w[os.system subprocess.call exec eval]
    dangerous_imports.each do |imp|
      errors << "包含危险操作: #{imp}" if content.include?(imp)
    end

    {
      valid: errors.empty?,
      errors: errors
    }
  end

  def self.validate_nodejs_script(content)
    # Node.js脚本验证
    errors = []
    
    # 检查是否有危险操作
    dangerous_operations = %w[child_process.exec eval require('fs').unlink]
    dangerous_operations.each do |op|
      errors << "包含危险操作: #{op}" if content.include?(op)
    end

    {
      valid: errors.empty?,
      errors: errors
    }
  end

  def self.load_script_templates
    {
      'shell' => {
        'basic' => generate_shell_template,
        'deploy' => generate_deploy_template,
        'backup' => generate_backup_template
      },
      'python' => {
        'basic' => generate_python_template,
        'data_process' => generate_python_data_template
      },
      'nodejs' => {
        'basic' => generate_nodejs_template,
        'api_test' => generate_nodejs_api_template
      },
      'docker' => {
        'basic' => generate_dockerfile_template,
        'java' => generate_java_dockerfile_template
      }
    }
  end

  def self.generate_basic_template(script_type)
    case script_type
    when 'shell' then generate_shell_template
    when 'python' then generate_python_template
    when 'nodejs' then generate_nodejs_template
    when 'docker' then generate_dockerfile_template
    else "# #{script_type} script template\necho 'Hello World'"
    end
  end

  def self.generate_shell_template
    <<~SHELL
      #!/bin/bash
      
      # 脚本说明
      # 作者: 
      # 创建时间: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}
      
      set -e  # 遇到错误立即退出
      
      echo "开始执行脚本..."
      
      # 在这里添加你的代码
      
      echo "脚本执行完成"
    SHELL
  end

  def self.generate_deploy_template
    <<~SHELL
      #!/bin/bash
      
      # 部署脚本模板
      
      PROJECT_NAME="your_project"
      DEPLOY_DIR="/opt/$PROJECT_NAME"
      BACKUP_DIR="/opt/backups"
      
      echo "开始部署 $PROJECT_NAME..."
      
      # 创建备份
      if [ -d "$DEPLOY_DIR" ]; then
          echo "创建备份..."
          tar -czf "$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S).tar.gz" -C "$DEPLOY_DIR" .
      fi
      
      # 停止服务
      echo "停止服务..."
      # systemctl stop $PROJECT_NAME
      
      # 部署新版本
      echo "部署新版本..."
      # cp new_version/* $DEPLOY_DIR/
      
      # 启动服务
      echo "启动服务..."
      # systemctl start $PROJECT_NAME
      
      echo "部署完成"
    SHELL
  end

  def self.generate_backup_template
    <<~SHELL
      #!/bin/bash
      
      # 备份脚本模板
      
      SOURCE_DIR="/opt/your_app"
      BACKUP_DIR="/opt/backups"
      TIMESTAMP=$(date +%Y%m%d_%H%M%S)
      
      echo "开始备份..."
      
      # 创建备份目录
      mkdir -p "$BACKUP_DIR"
      
      # 创建备份
      tar -czf "$BACKUP_DIR/backup_$TIMESTAMP.tar.gz" -C "$SOURCE_DIR" .
      
      # 清理旧备份（保留7天）
      find "$BACKUP_DIR" -name "backup_*.tar.gz" -mtime +7 -delete
      
      echo "备份完成: backup_$TIMESTAMP.tar.gz"
    SHELL
  end

  def self.generate_python_template
    <<~PYTHON
      #!/usr/bin/env python3
      # -*- coding: utf-8 -*-
      
      """
      Python脚本模板
      作者: 
      创建时间: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}
      """
      
      import sys
      import os
      
      def main():
          print("开始执行Python脚本...")
          
          # 在这里添加你的代码
          
          print("脚本执行完成")
      
      if __name__ == "__main__":
          main()
    PYTHON
  end

  def self.generate_python_data_template
    <<~PYTHON
      #!/usr/bin/env python3
      # -*- coding: utf-8 -*-
      
      """
      数据处理脚本模板
      """
      
      import pandas as pd
      import json
      from datetime import datetime
      
      def process_data(input_file, output_file):
          """处理数据"""
          print(f"处理文件: {input_file}")
          
          # 读取数据
          data = pd.read_csv(input_file)
          
          # 数据处理逻辑
          processed_data = data.copy()
          
          # 保存结果
          processed_data.to_csv(output_file, index=False)
          print(f"结果保存到: {output_file}")
      
      def main():
          if len(sys.argv) < 3:
              print("用法: python script.py input_file output_file")
              sys.exit(1)
          
          input_file = sys.argv[1]
          output_file = sys.argv[2]
          
          process_data(input_file, output_file)
      
      if __name__ == "__main__":
          main()
    PYTHON
  end

  def self.generate_nodejs_template
    <<~JAVASCRIPT
      #!/usr/bin/env node
      
      /**
       * Node.js脚本模板
       * 作者: 
       * 创建时间: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}
       */
      
      console.log('开始执行Node.js脚本...');
      
      // 在这里添加你的代码
      
      console.log('脚本执行完成');
    JAVASCRIPT
  end

  def self.generate_nodejs_api_template
    <<~JAVASCRIPT
      #!/usr/bin/env node
      
      /**
       * API测试脚本模板
       */
      
      const https = require('https');
      const http = require('http');
      
      function makeRequest(url, method = 'GET', data = null) {
          return new Promise((resolve, reject) => {
              const client = url.startsWith('https:') ? https : http;
              const options = {
                  method: method,
                  headers: {
                      'Content-Type': 'application/json'
                  }
              };
              
              const req = client.request(url, options, (res) => {
                  let responseData = '';
                  res.on('data', chunk => responseData += chunk);
                  res.on('end', () => {
                      resolve({
                          statusCode: res.statusCode,
                          data: responseData
                      });
                  });
              });
              
              req.on('error', reject);
              
              if (data) {
                  req.write(JSON.stringify(data));
              }
              
              req.end();
          });
      }
      
      async function main() {
          try {
              const response = await makeRequest('https://api.example.com/test');
              console.log('响应:', response);
          } catch (error) {
              console.error('错误:', error.message);
          }
      }
      
      main();
    JAVASCRIPT
  end

  def self.generate_dockerfile_template
    <<~DOCKERFILE
      # Dockerfile模板
      # 创建时间: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}
      
      FROM alpine:latest
      
      # 安装依赖
      RUN apk add --no-cache bash curl
      
      # 设置工作目录
      WORKDIR /app
      
      # 复制文件
      COPY . .
      
      # 暴露端口
      EXPOSE 8080
      
      # 启动命令
      CMD ["echo", "Hello Docker"]
    DOCKERFILE
  end

  def self.generate_java_dockerfile_template
    <<~DOCKERFILE
      # Java应用Dockerfile模板
      
      FROM openjdk:11-jre-slim
      
      # 设置工作目录
      WORKDIR /app
      
      # 复制JAR文件
      COPY target/*.jar app.jar
      
      # 暴露端口
      EXPOSE 8080
      
      # JVM参数
      ENV JAVA_OPTS="-Xmx512m -Xms256m"
      
      # 启动应用
      ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
    DOCKERFILE
  end
end