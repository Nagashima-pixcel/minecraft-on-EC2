# 🎮 minecraft server on ec2 - インスタンス自動起動システム

## 📋 **システム概要**

プレイヤがMinecraftサーバに接続したい時に、簡単にサーバを起動できるシステムです。

### **🚀 実装された機能**

1. **プレイヤ起動トリガー**: Lambda Function URLでサーバ起動
2. **サーバ状態確認**: リアルタイムでサーバ状況をチェック
3. **自動停止**: 30分間プレイヤがいない場合の自動停止
4. **DNS自動更新**: 起動時にRoute53レコードを自動更新

## 🔗 **Lambda Function URLs**

### **サーバ起動用URL**

```url
https://2qrdcsu6zpbmx673sdnhfznf640qukib.lambda-url.ap-northeast-1.on.aws/
```

### **サーバ状態確認用URL**

```url
https://67l7pr7d2vg6j4kp4gnv3r7lgi0tqrju.lambda-url.ap-northeast-1.on.aws/
```

## 📱 **使用方法**

### **方法1: ブラウザから直接アクセス**

1. **サーバ起動**:
   - 上記の「サーバ起動用URL」をブラウザで開く
   - POSTリクエストが必要な場合は、以下のcurlコマンドを使用

```bash
curl -X POST https://2qrdcsu6zpbmx673sdnhfznf640qukib.lambda-url.ap-northeast-1.on.aws/
```

1. **サーバ状態確認**:
   - 「サーバ状態確認用URL」をブラウザで開く

### **方法2: コマンドラインから**

```bash
# サーバ起動
curl -X POST https://2qrdcsu6zpbmx673sdnhfznf640qukib.lambda-url.ap-northeast-1.on.aws/

# 状態確認
curl https://67l7pr7d2vg6j4kp4gnv3r7lgi0tqrju.lambda-url.ap-northeast-1.on.aws/
```

## 🎯 **Minecraft接続手順**

1. **サーバ起動**: 上記URLでサーバを起動
2. **待機**: サーバの完全起動を待つ。10〜15分程度かかる場合があります。
3. **アドレス入力**: `moyomoto-world.click` へ接続

## 📊 **レスポンス例**

### **起動成功時**

```json
{
  "status": "started",
  "message": "Minecraft server started successfully!",
  "server_ip": "57.183.6.137",
  "dns_name": "moyomoto-world.click",
  "estimated_ready_time": "2-3 minutes",
  "instructions": "Connect to: moyomoto-world.click (wait 2-3 minutes for Minecraft server to fully load)"
}
```

### **既に起動中の場合**

```json
{
  "status": "already_running",
  "message": "Minecraft server is already running!",
  "server_ip": "57.183.6.137",
  "dns_name": "moyomoto-world.click",
  "minecraft_status": "running",
  "estimated_ready_time": "0 minutes"
}
```

### **状態確認レスポンス**

```json
{
  "instance_status": "running",
  "minecraft_status": "online",
  "server_ip": "57.183.6.137",
  "dns_name": "moyomoto-world.click",
  "uptime_minutes": 15.3,
  "ready_to_connect": true,
  "message": "サーバは稼働中です。接続可能です！"
}
```

## ⚙️ **自動停止機能**

- **監視間隔**: 10分ごと
- **停止条件**: 30分間プレイヤが0人
- **停止プロセス**:
  1. 30秒前に警告メッセージ
  2. Minecraftサーバ停止
  3. EC2インスタンス停止

## 💰 **コスト最適化**

- **Lambda**: 月100万リクエスト無料（実際は月数十回）
- **EventBridge**: 月100万イベント無料
- **Systems Manager**: 無料
- **Route53**: ホストゾーン月$0.50のみ
- **EC2**: 使用時間のみ課金（自動停止で最適化）

## 🔧 **トラブルシューティング**

### **サーバが起動しない場合**

1. Lambda関数のログを確認
2. EC2インスタンスの状態確認
3. IAM権限の確認

## 📞 **サポート情報**

- **サーバアドレス**: `moyomoto-world.click`
- **Minecraftバージョン**: 1.18.0
