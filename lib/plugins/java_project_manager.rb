# Java项目管理插件
class JavaProjectManager
  def self.detect_project_type(project_path)
    return 'maven' if File.exist?(File.join(project_path, 'pom.xml'))
    return 'gradle' if File.exist?(File.join(project_path, 'build.gradle'))
    return 'ant' if File.exist?(File.join(project_path, 'build.xml'))
    return 'jar' if Dir.glob(File.join(project_path, '*.jar')).any?
    'unknown'
  end

  def self.get_build_command(project)
    case project.project_type
    when 'maven'
      get_maven_build_command(project)
    when 'gradle'
      get_gradle_build_command(project)
    when 'ant'
      get_ant_build_command(project)
    else
      project.build_script || 'echo "未配置构建脚本"'
    end
  end

  def self.get_maven_build_command(project)
    profile = project.get_environment_variables['maven_profile']
    skip_tests = project.get_environment_variables['skip_tests'] || false
    
    command = 'mvn clean package'
    command += " -P #{profile}" if profile
    command += ' -DskipTests=true' if skip_tests
    
    command
  end

  def self.get_gradle_build_command(project)
    task = project.get_environment_variables['gradle_task'] || 'build'
    skip_tests = project.get_environment_variables['skip_tests'] || false
    
    command = "./gradlew #{task}"
    command += ' -x test' if skip_tests
    
    command
  end

  def self.get_ant_build_command(project)
    target = project.get_environment_variables['ant_target'] || 'build'
    "ant #{target}"
  end

  def self.parse_build_output(output, project_type)
    case project_type
    when 'maven'
      parse_maven_output(output)
    when 'gradle'
      parse_gradle_output(output)
    when 'ant'
      parse_ant_output(output)
    else
      { success: false, errors: ['未知项目类型'] }
    end
  end

  def self.parse_maven_output(output)
    success = output.include?('BUILD SUCCESS')
    errors = []
    warnings = []
    
    output.split("\n").each do |line|
      if line.include?('[ERROR]')
        errors << line.gsub('[ERROR]', '').strip
      elsif line.include?('[WARNING]')
        warnings << line.gsub('[WARNING]', '').strip
      end
    end

    {
      success: success,
      errors: errors,
      warnings: warnings,
      artifact_info: extract_maven_artifact_info(output)
    }
  end

  def self.parse_gradle_output(output)
    success = output.include?('BUILD SUCCESSFUL')
    errors = []
    warnings = []
    
    output.split("\n").each do |line|
      if line.include?('FAILED')
        errors << line.strip
      elsif line.include?('warning:')
        warnings << line.strip
      end
    end

    {
      success: success,
      errors: errors,
      warnings: warnings
    }
  end

  def self.parse_ant_output(output)
    success = output.include?('BUILD SUCCESSFUL')
    errors = []
    
    output.split("\n").each do |line|
      if line.include?('[javac]') && line.include?('error:')
        errors << line.strip
      end
    end

    {
      success: success,
      errors: errors,
      warnings: []
    }
  end

  def self.extract_maven_artifact_info(output)
    artifact_info = {}
    
    # 尝试提取构建的JAR文件信息
    output.scan(/Building jar: (.+\.jar)/) do |match|
      artifact_info[:jar_file] = match[0]
    end
    
    # 提取项目信息
    output.scan(/Building (.+) (.+)/) do |name, version|
      artifact_info[:name] = name
      artifact_info[:version] = version
    end

    artifact_info
  end

  def self.get_run_command(project)
    case project.project_type
    when 'jar'
      get_jar_run_command(project)
    when 'maven', 'gradle'
      get_spring_boot_run_command(project)
    else
      project.start_script || 'echo "未配置启动脚本"'
    end
  end

  def self.get_jar_run_command(project)
    jar_file = project.artifact_path || find_jar_file(project)
    jvm_options = project.jvm_options || ''
    
    "java #{jvm_options} -jar #{jar_file}"
  end

  def self.get_spring_boot_run_command(project)
    if project.project_type == 'maven'
      'mvn spring-boot:run'
    else
      './gradlew bootRun'
    end
  end

  def self.find_jar_file(project)
    # 在target或build目录中查找JAR文件
    patterns = [
      File.join(project.deploy_path, 'target', '*.jar'),
      File.join(project.deploy_path, 'build', 'libs', '*.jar'),
      File.join(project.deploy_path, '*.jar')
    ]

    patterns.each do |pattern|
      files = Dir.glob(pattern)
      return files.first if files.any?
    end

    'app.jar'
  end

  def self.get_stop_command(project)
    case project.stop_mode
    when 'pid_file'
      get_pid_file_stop_command(project)
    when 'port'
      get_port_stop_command(project)
    when 'pattern'
      get_pattern_stop_command(project)
    else
      'echo "未配置停止脚本"'
    end
  end

  def self.get_pid_file_stop_command(project)
    pid_file = project.get_environment_variables['pid_file'] || 'app.pid'
    
    <<~SCRIPT
      if [ -f #{pid_file} ]; then
        PID=$(cat #{pid_file})
        if ps -p $PID > /dev/null; then
          kill $PID
          rm -f #{pid_file}
          echo "进程已停止"
        else
          echo "进程不存在，删除PID文件"
          rm -f #{pid_file}
        fi
      else
        echo "PID文件不存在"
      fi
    SCRIPT
  end

  def self.get_port_stop_command(project)
    port = project.get_environment_variables['app_port'] || '8080'
    
    <<~SCRIPT
      PID=$(lsof -ti:#{port})
      if [ ! -z "$PID" ]; then
        kill $PID
        echo "端口 #{port} 上的进程已停止"
      else
        echo "端口 #{port} 上没有运行的进程"
      fi
    SCRIPT
  end

  def self.get_pattern_stop_command(project)
    pattern = project.get_environment_variables['process_pattern'] || project.name
    
    <<~SCRIPT
      PID=$(ps aux | grep '#{pattern}' | grep -v grep | awk '{print $2}')
      if [ ! -z "$PID" ]; then
        kill $PID
        echo "匹配模式 '#{pattern}' 的进程已停止"
      else
        echo "没有找到匹配模式 '#{pattern}' 的进程"
      fi
    SCRIPT
  end

  def self.validate_java_environment(resource)
    result = resource.execute_command('java -version')
    
    if result[:success]
      java_version = extract_java_version(result[:output])
      {
        java_installed: true,
        java_version: java_version,
        java_home: get_java_home(resource)
      }
    else
      {
        java_installed: false,
        error: result[:error]
      }
    end
  end

  def self.extract_java_version(output)
    # 从java -version输出中提取版本号
    if output.match(/version "([^"]+)"/)
      $1
    elsif output.match(/openjdk version "([^"]+)"/)
      $1
    else
      'unknown'
    end
  end

  def self.get_java_home(resource)
    result = resource.execute_command('echo $JAVA_HOME')
    
    if result[:success] && !result[:output].strip.empty?
      result[:output].strip
    else
      # 尝试从which java推导
      which_result = resource.execute_command('which java')
      if which_result[:success]
        java_path = which_result[:output].strip
        # 假设JAVA_HOME是java可执行文件的上两级目录
        File.dirname(File.dirname(java_path))
      else
        nil
      end
    end
  end

  def self.check_maven_installation(resource)
    result = resource.execute_command('mvn -version')
    
    if result[:success]
      maven_version = extract_maven_version(result[:output])
      {
        maven_installed: true,
        maven_version: maven_version
      }
    else
      {
        maven_installed: false,
        error: result[:error]
      }
    end
  end

  def self.extract_maven_version(output)
    if output.match(/Apache Maven ([^\s]+)/)
      $1
    else
      'unknown'
    end
  end

  def self.check_gradle_installation(resource)
    result = resource.execute_command('gradle -version')
    
    if result[:success]
      gradle_version = extract_gradle_version(result[:output])
      {
        gradle_installed: true,
        gradle_version: gradle_version
      }
    else
      {
        gradle_installed: false,
        error: result[:error]
      }
    end
  end

  def self.extract_gradle_version(output)
    if output.match(/Gradle ([^\s]+)/)
      $1
    else
      'unknown'
    end
  end

  def self.generate_dockerfile(project)
    case project.project_type
    when 'maven'
      generate_maven_dockerfile(project)
    when 'gradle'
      generate_gradle_dockerfile(project)
    when 'jar'
      generate_jar_dockerfile(project)
    else
      generate_basic_dockerfile(project)
    end
  end

  def self.generate_maven_dockerfile(project)
    <<~DOCKERFILE
      FROM maven:3.8.6-openjdk-11 AS build
      WORKDIR /app
      COPY pom.xml .
      RUN mvn dependency:go-offline -B
      COPY src src
      RUN mvn clean package -DskipTests

      FROM openjdk:11-jre-slim
      WORKDIR /app
      COPY --from=build /app/target/*.jar app.jar
      EXPOSE 8080
      ENTRYPOINT ["java", "-jar", "app.jar"]
    DOCKERFILE
  end

  def self.generate_gradle_dockerfile(project)
    <<~DOCKERFILE
      FROM gradle:7.6-jdk11 AS build
      WORKDIR /app
      COPY build.gradle settings.gradle ./
      COPY gradle gradle
      RUN gradle dependencies --no-daemon
      COPY src src
      RUN gradle build --no-daemon -x test

      FROM openjdk:11-jre-slim
      WORKDIR /app
      COPY --from=build /app/build/libs/*.jar app.jar
      EXPOSE 8080
      ENTRYPOINT ["java", "-jar", "app.jar"]
    DOCKERFILE
  end

  def self.generate_jar_dockerfile(project)
    jar_file = File.basename(project.artifact_path || 'app.jar')
    
    <<~DOCKERFILE
      FROM openjdk:11-jre-slim
      WORKDIR /app
      COPY #{jar_file} app.jar
      EXPOSE 8080
      ENTRYPOINT ["java", "-jar", "app.jar"]
    DOCKERFILE
  end

  def self.generate_basic_dockerfile(project)
    <<~DOCKERFILE
      FROM openjdk:11-jre-slim
      WORKDIR /app
      COPY . .
      EXPOSE 8080
      CMD ["echo", "请配置启动命令"]
    DOCKERFILE
  end
end