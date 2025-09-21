#!/bin/bash

# Jpom CICD系统启动脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查Ruby环境
check_ruby() {
    log_info "检查Ruby环境..."
    
    if ! command -v ruby &> /dev/null; then
        log_error "Ruby未安装，请先安装Ruby 3.0+。"
        exit 1
    fi
    
    ruby_version=$(ruby -v | cut -d' ' -f2)
    log_info "Ruby版本: $ruby_version"
    
    if ! command -v bundler &> /dev/null; then
        log_warn "Bundler未安装，正在安装..."
        gem install bundler
    fi
}

# 安装依赖
install_dependencies() {
    log_info "安装依赖包..."
    
    if [ -f Gemfile ]; then
        bundle install
    else
        log_error "Gemfile不存在"
        exit 1
    fi
}

# 初始化数据库
init_database() {
    log_info "初始化数据库..."
    
    if [ ! -f cicd.db ]; then
        log_info "创建数据库..."
        # 数据库将在应用启动时自动创建
    else
        log_info "数据库已存在"
    fi
}

# 创建必要目录
create_directories() {
    log_info "创建必要目录..."
    
    directories=("tmp" "logs" "backups" "uploads" "scripts" "ssh_keys")
    
    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            log_info "创建目录: $dir"
        fi
    done
    
    # 设置适当的权限
    chmod 700 tmp
    chmod 700 ssh_keys
    chmod 755 logs
    chmod 755 backups
}

# 检查端口是否可用
check_ports() {
    log_info "检查端口可用性..."
    
    app_port=${APP_PORT:-4567}
    ws_port=${WEBSOCKET_PORT:-8080}
    
    if netstat -tuln | grep -q ":$app_port "; then
        log_error "端口 $app_port 已被占用"
        exit 1
    fi
    
    if netstat -tuln | grep -q ":$ws_port "; then
        log_warn "WebSocket端口 $ws_port 已被占用"
    fi
    
    log_info "端口检查完成"
}

# 启动应用
start_app() {
    log_info "启动Jpom CICD系统..."
    
    if [ "$1" = "development" ]; then
        log_info "开发模式启动"
        bundle exec ruby app_refactored.rb
    elif [ "$1" = "production" ]; then
        log_info "生产模式启动"
        bundle exec puma -C puma.rb app_refactored.rb
    else
        log_info "默认模式启动"
        bundle exec ruby app_refactored.rb
    fi
}

# 停止应用
stop_app() {
    log_info "停止Jpom CICD系统..."
    
    if [ -f tmp/puma.pid ]; then
        pid=$(cat tmp/puma.pid)
        if ps -p $pid > /dev/null; then
            kill $pid
            log_info "应用已停止 (PID: $pid)"
        else
            log_warn "PID文件存在但进程不存在"
            rm -f tmp/puma.pid
        fi
    else
        # 尝试查找进程
        pids=$(pgrep -f "app_refactored.rb" || true)
        if [ -n "$pids" ]; then
            kill $pids
            log_info "应用已停止"
        else
            log_warn "没有找到运行中的应用进程"
        fi
    fi
}

# 重启应用
restart_app() {
    log_info "重启Jpom CICD系统..."
    stop_app
    sleep 2
    start_app $1
}

# 显示状态
show_status() {
    log_info "检查应用状态..."
    
    if [ -f tmp/puma.pid ]; then
        pid=$(cat tmp/puma.pid)
        if ps -p $pid > /dev/null; then
            log_info "应用正在运行 (PID: $pid)"
            return 0
        else
            log_warn "PID文件存在但进程不存在"
            rm -f tmp/puma.pid
        fi
    fi
    
    pids=$(pgrep -f "app_refactored.rb" || true)
    if [ -n "$pids" ]; then
        log_info "应用正在运行 (PID: $pids)"
        return 0
    else
        log_info "应用未运行"
        return 1
    fi
}

# 显示帮助
show_help() {
    echo "Jpom CICD系统启动脚本"
    echo ""
    echo "用法: $0 {start|stop|restart|status|install|help} [mode]"
    echo ""
    echo "命令:"
    echo "  start [mode]    启动应用 (mode: development|production)"
    echo "  stop            停止应用"
    echo "  restart [mode]  重启应用"
    echo "  status          显示应用状态"
    echo "  install         安装依赖和初始化"
    echo "  help            显示帮助信息"
    echo ""
    echo "环境变量:"
    echo "  APP_PORT        应用端口 (默认: 4567)"
    echo "  WEBSOCKET_PORT  WebSocket端口 (默认: 8080)"
    echo "  RACK_ENV        运行环境 (development|production)"
    echo ""
    echo "示例:"
    echo "  $0 install              # 安装依赖"
    echo "  $0 start development    # 开发模式启动"
    echo "  $0 start production     # 生产模式启动"
    echo "  $0 restart production  # 重启到生产模式"
}

# 安装和初始化
install_system() {
    log_info "开始安装Jpom CICD系统..."
    
    check_ruby
    install_dependencies
    create_directories
    init_database
    
    log_info "安装完成！"
    log_info "使用 '$0 start' 启动系统"
}

# 主函数
main() {
    case "$1" in
        start)
            check_ruby
            check_ports
            start_app $2
            ;;
        stop)
            stop_app
            ;;
        restart)
            restart_app $2
            ;;
        status)
            show_status
            ;;
        install)
            install_system
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo "未知命令: $1"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"