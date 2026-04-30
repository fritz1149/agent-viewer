#!/bin/bash

# ============================================
# Agent Viewer 后台启动脚本
# 用法: ./start.sh {start|stop|restart|status}
# ============================================

# 项目目录（脚本所在目录）
APP_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="agent-viewer"
APP_ENTRY="server.js"
LOG_FILE="$APP_DIR/app.log"
PID_FILE="$APP_DIR/app.pid"

# 默认端口，可通过环境变量覆盖
PORT="${PORT:-4200}"
HOST="${HOST:-0.0.0.0}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # 无颜色

# 获取运行中的 PID
get_pid() {
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "$pid"
            return 0
        else
            # PID 文件存在但进程已不在，清理
            rm -f "$PID_FILE"
        fi
    fi
    return 1
}

# 启动服务
start() {
    local pid
    if pid=$(get_pid); then
        echo -e "${YELLOW}[警告] $APP_NAME 已在运行中 (PID: $pid)${NC}"
        return 1
    fi

    echo -e "${GREEN}[启动] 正在启动 $APP_NAME ...${NC}"

    # 检查 node_modules 是否存在
    if [ ! -d "$APP_DIR/node_modules" ]; then
        echo -e "${YELLOW}[提示] 未检测到 node_modules，正在安装依赖...${NC}"
        cd "$APP_DIR" && npm install
    fi

    # 使用 nohup 后台启动
    cd "$APP_DIR"
    PORT=$PORT HOST=$HOST nohup node "$APP_ENTRY" >> "$LOG_FILE" 2>&1 &
    local new_pid=$!
    echo "$new_pid" > "$PID_FILE"

    # 等待一小段时间确认进程是否正常启动
    sleep 1
    if kill -0 "$new_pid" 2>/dev/null; then
        echo -e "${GREEN}[成功] $APP_NAME 已启动${NC}"
        echo -e "  PID:  $new_pid"
        echo -e "  地址: http://$HOST:$PORT"
        echo -e "  日志: $LOG_FILE"
    else
        echo -e "${RED}[失败] $APP_NAME 启动失败，请查看日志: $LOG_FILE${NC}"
        rm -f "$PID_FILE"
        tail -20 "$LOG_FILE"
        return 1
    fi
}

# 停止服务
stop() {
    local pid
    if pid=$(get_pid); then
        echo -e "${YELLOW}[停止] 正在停止 $APP_NAME (PID: $pid) ...${NC}"
        kill "$pid"

        # 等待进程退出，最多等 10 秒
        local count=0
        while kill -0 "$pid" 2>/dev/null && [ $count -lt 10 ]; do
            sleep 1
            count=$((count + 1))
        done

        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${RED}[警告] 进程未正常退出，强制终止...${NC}"
            kill -9 "$pid"
        fi

        rm -f "$PID_FILE"
        echo -e "${GREEN}[成功] $APP_NAME 已停止${NC}"
    else
        echo -e "${YELLOW}[提示] $APP_NAME 未在运行${NC}"
    fi
}

# 重启服务
restart() {
    echo -e "${GREEN}[重启] 正在重启 $APP_NAME ...${NC}"
    stop
    sleep 1
    start
}

# 查看状态
status() {
    local pid
    if pid=$(get_pid); then
        echo -e "${GREEN}[运行中] $APP_NAME (PID: $pid)${NC}"
        echo -e "  地址: http://$HOST:$PORT"
        echo -e "  日志: $LOG_FILE"
    else
        echo -e "${RED}[已停止] $APP_NAME 未在运行${NC}"
    fi
}

# 查看日志（实时）
logs() {
    if [ -f "$LOG_FILE" ]; then
        echo -e "${GREEN}[日志] 实时查看 $LOG_FILE (Ctrl+C 退出)${NC}"
        tail -f "$LOG_FILE"
    else
        echo -e "${YELLOW}[提示] 日志文件不存在: $LOG_FILE${NC}"
    fi
}

# 主入口
case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        restart
        ;;
    status)
        status
        ;;
    logs)
        logs
        ;;
    *)
        echo "用法: $0 {start|stop|restart|status|logs}"
        echo ""
        echo "命令说明:"
        echo "  start   - 后台启动服务"
        echo "  stop    - 停止服务"
        echo "  restart - 重启服务"
        echo "  status  - 查看运行状态"
        echo "  logs    - 实时查看日志"
        echo ""
        echo "环境变量:"
        echo "  PORT    - 监听端口 (默认: 4200)"
        echo "  HOST    - 监听地址 (默认: 0.0.0.0)"
        echo ""
        echo "示例:"
        echo "  ./start.sh start"
        echo "  PORT=8080 ./start.sh start"
        exit 1
        ;;
esac
