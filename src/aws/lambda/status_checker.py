import boto3
import json
import os
import socket

def lambda_handler(event, context):
    """
    Minecraft Server Status Checker
    サーバの状態とMinecraftサーバの稼働状況を確認
    """
    
    # 環境変数から値を取得
    instance_id = os.environ['INSTANCE_ID']
    dns_name = os.environ['DNS_NAME']
    aws_region = os.environ['MINECRAFT_AWS_REGION']
    
    # CORS対応のヘッダー
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Content-Type': 'application/json'
    }
    
    try:
        # AWSクライアント初期化
        ec2 = boto3.client('ec2', region_name=aws_region)
        
        print(f"Checking status for instance: {instance_id}")
        
        # 1. EC2インスタンスの状態確認
        instance_response = ec2.describe_instances(InstanceIds=[instance_id])
        instance = instance_response['Reservations'][0]['Instances'][0]
        instance_state = instance['State']['Name']
        
        print(f"Instance state: {instance_state}")
        
        # 2. インスタンスが起動している場合の詳細チェック
        if instance_state == 'running':
            public_ip = instance['PublicIpAddress']
            
            # Minecraftポート（25565）の接続テスト
            minecraft_status = check_minecraft_port(public_ip, 25565)
            
            # インスタンスの起動時間を計算
            launch_time = instance['LaunchTime']
            import datetime
            uptime_minutes = (datetime.datetime.now(datetime.timezone.utc) - launch_time).total_seconds() / 60
            
            return {
                'statusCode': 200,
                'headers': headers,
                'body': json.dumps({
                    'instance_status': instance_state,
                    'minecraft_status': minecraft_status,
                    'server_ip': public_ip,
                    'dns_name': dns_name,
                    'uptime_minutes': round(uptime_minutes, 1),
                    'ready_to_connect': minecraft_status == 'online',
                    'message': get_status_message(instance_state, minecraft_status, uptime_minutes)
                }, ensure_ascii=False)
            }
            
        else:
            # インスタンスが停止中または起動中の場合
            return {
                'statusCode': 200,
                'headers': headers,
                'body': json.dumps({
                    'instance_status': instance_state,
                    'minecraft_status': 'offline',
                    'server_ip': None,
                    'dns_name': dns_name,
                    'uptime_minutes': 0,
                    'ready_to_connect': False,
                    'message': get_status_message(instance_state, 'offline', 0)
                }, ensure_ascii=False)
            }
            
    except Exception as e:
        print(f"Error checking server status: {e}")
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({
                'instance_status': 'error',
                'minecraft_status': 'error',
                'message': f'Failed to check server status: {str(e)}',
                'ready_to_connect': False
            }, ensure_ascii=False)
        }

def check_minecraft_port(ip_address, port, timeout=5):
    """
    Minecraftサーバのポートが開いているかチェック
    """
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        result = sock.connect_ex((ip_address, port))
        sock.close()
        
        if result == 0:
            return 'online'
        else:
            return 'starting'
    except Exception as e:
        print(f"Port check failed: {e}")
        return 'offline'

def get_status_message(instance_state, minecraft_status, uptime_minutes):
    """
    状態に応じたメッセージを生成
    """
    if instance_state == 'stopped':
        return 'サーバは停止中です。起動ボタンを押してください。'
    elif instance_state == 'stopping':
        return 'サーバは停止処理中です。しばらくお待ちください。'
    elif instance_state in ['pending', 'starting']:
        return 'サーバは起動中です。2-3分お待ちください。'
    elif instance_state == 'running':
        if minecraft_status == 'online':
            return 'サーバは稼働中です。接続可能です！'
        elif minecraft_status == 'starting' and uptime_minutes < 5:
            return f'サーバは起動中です（{round(uptime_minutes, 1)}分経過）。Minecraftサーバの起動をお待ちください。'
        else:
            return 'EC2は起動していますが、Minecraftサーバが応答しません。'
    else:
        return f'サーバは{instance_state}状態です。' 
