# WebSocket 服务器
require 'websocket-eventmachine-server'
require 'eventmachine'
require 'json'

class WebSocketServer
  @@clients = {}
  @@rooms = {}

  def self.start(port = 8080)
    EM.run do
      puts "WebSocket服务器启动在端口 #{port}"
      
      EM.start_server('0.0.0.0', port, WebSocketHandler) do |ws|
        ws.onopen = method(:on_open)
        ws.onmessage = method(:on_message)
        ws.onclose = method(:on_close)
        ws.onerror = method(:on_error)
      end
    end
  end

  def self.on_open(handshake)
    puts "WebSocket连接建立: #{handshake.path}"
    
    # 解析连接参数
    query_params = parse_query_string(handshake.query_string)
    user_id = query_params['user_id']
    room = query_params['room'] || 'general'
    
    # 存储客户端信息
    client_info = {
      user_id: user_id,
      room: room,
      connected_at: Time.now
    }
    
    @@clients[handshake] = client_info
    
    # 加入房间
    @@rooms[room] ||= []
    @@rooms[room] << handshake
    
    # 发送欢迎消息
    send_to_client(handshake, {
      type: 'welcome',
      message: '连接成功',
      room: room,
      timestamp: Time.now.to_i
    })
    
    # 通知房间内其他用户
    broadcast_to_room(room, {
      type: 'user_joined',
      user_id: user_id,
      timestamp: Time.now.to_i
    }, exclude: handshake)
  end

  def self.on_message(handshake, message)
    begin
      data = JSON.parse(message)
      client_info = @@clients[handshake]
      
      case data['type']
      when 'ping'
        send_to_client(handshake, { type: 'pong', timestamp: Time.now.to_i })
      when 'join_room'
        join_room(handshake, data['room'])
      when 'leave_room'
        leave_room(handshake, data['room'])
      when 'subscribe_build'
        subscribe_build_log(handshake, data['project_id'])
      when 'subscribe_deploy'
        subscribe_deploy_log(handshake, data['project_id'])
      when 'chat'
        handle_chat_message(handshake, data)
      else
        puts "未知消息类型: #{data['type']}"
      end
    rescue JSON::ParserError => e
      puts "解析WebSocket消息失败: #{e.message}"
      send_to_client(handshake, {
        type: 'error',
        message: '消息格式错误',
        timestamp: Time.now.to_i
      })
    end
  end

  def self.on_close(handshake)
    client_info = @@clients[handshake]
    return unless client_info
    
    puts "WebSocket连接关闭: #{client_info[:user_id]}"
    
    # 从房间中移除
    room = client_info[:room]
    if @@rooms[room]
      @@rooms[room].delete(handshake)
      @@rooms.delete(room) if @@rooms[room].empty?
    end
    
    # 通知房间内其他用户
    broadcast_to_room(room, {
      type: 'user_left',
      user_id: client_info[:user_id],
      timestamp: Time.now.to_i
    })
    
    # 移除客户端信息
    @@clients.delete(handshake)
  end

  def self.on_error(handshake, error)
    puts "WebSocket错误: #{error.message}"
  end

  # 发送消息给特定客户端
  def self.send_to_client(handshake, data)
    handshake.send(data.to_json)
  end

  # 向房间广播消息
  def self.broadcast_to_room(room, data, exclude: nil)
    return unless @@rooms[room]
    
    @@rooms[room].each do |client|
      next if client == exclude
      send_to_client(client, data)
    end
  end

  # 向所有客户端广播
  def self.broadcast_to_all(data)
    @@clients.keys.each do |client|
      send_to_client(client, data)
    end
  end

  # 发送构建日志
  def self.send_build_log(project_id, log_data)
    broadcast_to_room("build_#{project_id}", {
      type: 'build_log',
      project_id: project_id,
      data: log_data,
      timestamp: Time.now.to_i
    })
  end

  # 发送部署日志
  def self.send_deploy_log(project_id, log_data)
    broadcast_to_room("deploy_#{project_id}", {
      type: 'deploy_log',
      project_id: project_id,
      data: log_data,
      timestamp: Time.now.to_i
    })
  end

  private

  def self.parse_query_string(query_string)
    return {} if query_string.nil? || query_string.empty?
    
    params = {}
    query_string.split('&').each do |param|
      key, value = param.split('=', 2)
      params[CGI.unescape(key)] = CGI.unescape(value || '')
    end
    params
  end

  def self.join_room(handshake, room)
    client_info = @@clients[handshake]
    old_room = client_info[:room]
    
    # 离开旧房间
    leave_room(handshake, old_room) if old_room != room
    
    # 加入新房间
    @@rooms[room] ||= []
    @@rooms[room] << handshake unless @@rooms[room].include?(handshake)
    
    client_info[:room] = room
    
    send_to_client(handshake, {
      type: 'room_joined',
      room: room,
      timestamp: Time.now.to_i
    })
  end

  def self.leave_room(handshake, room)
    return unless @@rooms[room]
    
    @@rooms[room].delete(handshake)
    @@rooms.delete(room) if @@rooms[room].empty?
    
    send_to_client(handshake, {
      type: 'room_left',
      room: room,
      timestamp: Time.now.to_i
    })
  end

  def self.subscribe_build_log(handshake, project_id)
    join_room(handshake, "build_#{project_id}")
  end

  def self.subscribe_deploy_log(handshake, project_id)
    join_room(handshake, "deploy_#{project_id}")
  end

  def self.handle_chat_message(handshake, data)
    client_info = @@clients[handshake]
    room = client_info[:room]
    
    message_data = {
      type: 'chat_message',
      user_id: client_info[:user_id],
      message: data['message'],
      room: room,
      timestamp: Time.now.to_i
    }
    
    broadcast_to_room(room, message_data)
  end
end

# WebSocket处理器
module WebSocketHandler
  def post_init
    @handshake = WebSocket::EventMachine::Server.new
  end

  def receive_data(data)
    @handshake << data

    if @handshake.handshake_complete?
      @onopen.call(@handshake) if @onopen
    end

    @handshake.each_frame do |frame|
      @onmessage.call(@handshake, frame.to_s) if @onmessage
    end
  end

  def unbind
    @onclose.call(@handshake) if @onclose
  end

  def onopen(&block)
    @onopen = block
  end

  def onmessage(&block)
    @onmessage = block
  end

  def onclose(&block)
    @onclose = block
  end

  def onerror(&block)
    @onerror = block
  end

  def send(data)
    send_data(@handshake.frame(data))
  end
end