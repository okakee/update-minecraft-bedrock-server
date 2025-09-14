#!/usr/bin/env bash
set -euo pipefail

#############################################
# 設定（環境に合わせて変更）
#############################################

# Bedrockサーバーのインストールディレクトリ
SERVER_DIR="/opt/minecraft/server_bedrock"

# バックアップ保存先
BACKUP_DIR="/opt/minecraft/backup"

# 実行ユーザー
RUN_USER="minecraft"

# screen セッション名
SCREEN_NAME="mcbe"

# 実行バイナリ名
BINARY_NAME="bedrock_server"

# 引き継ぐ設定/データ
PRESERVE_ITEMS=(
  "allowlist.json"
  "permissions.json"
  "server.properties"
  "valid_known_packs.json"
  # "whitelist.json"  # 旧称互換
  "worlds"
  "behavior_packs"
  "resource_packs"
  "run.sh"  # screen実行用スクリプト
)

#############################################
# 内部処理
#############################################

if [[ $# -lt 1 ]]; then
  echo "使い方: $0 <ダウンロードURL>"
  echo "例: $0 https://minecraft.azureedge.net/bin-linux/bedrock-server-1.21.50.03.zip"
  exit 1
fi
DOWNLOAD_URL="$1"

timestamp() { date +"%Y%m%d-%H%M%S"; }
TS="$(timestamp)"
WORK_DIR="$(mktemp -d /tmp/bedrock-update.XXXXXXXX)"
ZIP_PATH="$WORK_DIR/bedrock_latest.zip"
NEW_DIR="$WORK_DIR/bedrock-server-new"
SWAP_OLD="$SERVER_DIR-$TS-old"

cleanup() {
  rm -rf "$WORK_DIR" 2>/dev/null || true
}
trap cleanup EXIT

echo "==> 前提チェック"
for cmd in curl unzip rsync screen; do
  command -v $cmd >/dev/null || { echo "$cmd が必要です"; exit 1; }
done

mkdir -p "$BACKUP_DIR"

# echo "==> サーバー停止 (screen)"
# if screen -list | grep -q "\.${SCREEN_NAME}"; then
#   screen -S "${SCREEN_NAME}" -p 0 -X stuff "save hold^M"
#   sleep 3
#   screen -S "${SCREEN_NAME}" -p 0 -X stuff "stop^M"
#   for i in $(seq 1 60); do
#     if ! screen -list | grep -q "\.${SCREEN_NAME}"; then break; fi
#     sleep 1
#   done
# else
#   echo "警告: screen セッション ${SCREEN_NAME} が見つかりません。"
# fi

echo "==> バックアップ: $BACKUP_DIR/bedrock-server-backup-$TS.tar.gz"
if [[ -d "$SERVER_DIR" ]]; then
  tar -C "$(dirname "$SERVER_DIR")" -czf "$BACKUP_DIR/bedrock-server-backup-$TS.tar.gz" "$(basename "$SERVER_DIR")"
fi

# NOTE: 自動取得が難しそうなので一旦引数で直接DOWNLOAD_URLを指定する
# echo "==> 最新版のダウンロードURL取得"
# DOWNLOAD_URL="$(curl -fsSL https://www.minecraft.net/en-us/download/server/bedrock \
#   | grep -oE 'https://[^\"]*bedrock-server-[^"]*linux[^"]*\.zip' \
#   | head -n1 || true)"

# if [[ -z "$DOWNLOAD_URL" ]]; then
#   DOWNLOAD_URL="$(curl -fsSL https://www.minecraft.net/en-us/download/server/bedrock \
#     | grep -oE 'https://[^\"]*bedrock-server-[^"]*\.zip' \
#     | head -n1 || true)"
# fi

# [[ -n "$DOWNLOAD_URL" ]] || { echo "最新版URL取得失敗"; exit 1; }

echo "ダウンロードURL: $DOWNLOAD_URL"
wget "$DOWNLOAD_URL" -O "$ZIP_PATH"
# curl -fSL "$DOWNLOAD_URL" -o "$ZIP_PATH"

echo "==> 展開"
mkdir -p "$NEW_DIR"
unzip -q "$ZIP_PATH" -d "$NEW_DIR"
chmod +x "$NEW_DIR/$BINARY_NAME" || true

echo "==> 設定/ワールド引き継ぎ"
for item in "${PRESERVE_ITEMS[@]}"; do
  if [[ -e "$SERVER_DIR/$item" ]]; then
    rsync -a "$SERVER_DIR/$item" "$NEW_DIR/" || true
  fi
done

# sudo chown -R "$RUN_USER":"$RUN_USER" "$NEW_DIR"

echo "==> ディレクトリ切替"
if [[ -d "$SERVER_DIR" ]]; then
  mv "$SERVER_DIR" "$SWAP_OLD"
fi
mv "$NEW_DIR" "$SERVER_DIR"

echo "旧ディレクトリ: $SWAP_OLD"

# echo "==> サーバー起動 (screen)"
# # 既存セッション削除
# screen -S "${SCREEN_NAME}" -X quit || true
# sudo -u "$RUN_USER" screen -dmS "${SCREEN_NAME}" bash -lc "cd \"$SERVER_DIR\" && ./$BINARY_NAME"

echo "==> 完了！"
echo "バックアップ: $BACKUP_DIR/bedrock-server-backup-$TS.tar.gz"
