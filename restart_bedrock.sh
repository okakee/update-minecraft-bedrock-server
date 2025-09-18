#!/bin/bash
SESSION="minecraft"
SERVER_DIR="/opt/minecraft/server_bedrock"

# stop コマンドを送信
if screen -list | grep -q "$SESSION"; then
    echo "Stopping Minecraft server safely..."
    screen -S "$SESSION" -p 0 -X stuff "stop$(printf '\r')"
    sleep 30   # 保存完了を待つ
fi

# サーバを再起動
echo "Starting Minecraft server..."
cd "$SERVER_DIR"
/usr/bin/screen -dm -S "$SESSION" /bin/bash -c "$SERVER_DIR/bedrock_server"
