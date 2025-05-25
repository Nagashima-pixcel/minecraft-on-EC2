import boto3
import json
import time
import os

def lambda_handler(event, context):
    """
    Player-Triggered Minecraft Server Startup
    プレイヤからの要求でMinecraftサーバを起動
    """
    
    # 環境変数から値を取得
    instance_id = os.environ['INSTANCE_ID']
    hosted_zone_id = os.environ['HOSTED_ZONE_ID']
    dns_name = os.environ['DNS_NAME']
    aws_region = os.environ['MINECRAFT_AWS_REGION']
    
    # CORS対応のヘッダー
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Content-Type': 'application/json'
    }
    
    try:
        # AWSクライアント初期化
        ec2 = boto3.client('ec2', region_name=aws_region)
        route53 = boto3.client('route53')
        
        print(f"Player requested server startup for instance: {instance_id}")
        
        # 1. EC2インスタンスの現在の状態を確認
        instance_response = ec2.describe_instances(InstanceIds=[instance_id])
        instance = instance_response['Reservations'][0]['Instances'][0]
        current_state = instance['State']['Name']
        
        print(f"Current instance state: {current_state}")
        
        # 2. インスタンスの状態に応じて処理
        if current_state == 'running':
            # 既に起動している場合
            public_ip = instance['PublicIpAddress']
            
            # Minecraftサーバの起動状況をチェック（簡易版）
            try:
                # SSMを使ってサーバ状況確認（オプション）
                ssm = boto3.client('ssm', region_name=aws_region)
                response = ssm.send_command(
                    InstanceIds=[instance_id],
                    DocumentName='AWS-RunShellScript',
                    Parameters={
                        'commands': [
                            'screen -list | grep minecraft || echo "Server not running"'
                        ]
                    }
                )
                
                server_status = "running"
            except Exception as e:
                print(f"Could not check Minecraft server status: {e}")
                server_status = "unknown"
            
            return {
                'statusCode': 200,
                'headers': headers,
                'body': json.dumps({
                    'status': 'already_running',
                    'message': 'Minecraft server is already running!',
                    'server_ip': public_ip,
                    'dns_name': dns_name,
                    'minecraft_status': server_status,
                    'estimated_ready_time': '0 minutes'
                }, ensure_ascii=False)
            }
            
        elif current_state in ['stopped', 'stopping']:
            # 停止中または停止済みの場合、起動処理を開始
            print("Starting EC2 instance...")
            
            start_response = ec2.start_instances(InstanceIds=[instance_id])
            print(f"Start command sent: {start_response}")
            
            # 起動完了まで待機（最大3分）
            print("Waiting for instance to start...")
            max_wait_time = 180  # 3分
            start_time = time.time()
            
            while time.time() - start_time < max_wait_time:
                instance_response = ec2.describe_instances(InstanceIds=[instance_id])
                state = instance_response['Reservations'][0]['Instances'][0]['State']['Name']
                
                if state == 'running':
                    public_ip = instance_response['Reservations'][0]['Instances'][0]['PublicIpAddress']
                    print(f"Instance started successfully with IP: {public_ip}")
                    break
                    
                time.sleep(10)
            else:
                # タイムアウトした場合
                return {
                    'statusCode': 202,
                    'headers': headers,
                    'body': json.dumps({
                        'status': 'starting',
                        'message': 'Server startup initiated but taking longer than expected',
                        'dns_name': dns_name,
                        'estimated_ready_time': '5-10 minutes'
                    }, ensure_ascii=False)
                }
            
            # 3. Route53 DNSレコードを更新
            print("Updating DNS record...")
            change_batch = {
                'Comment': f'Player-triggered update for {dns_name}',
                'Changes': [
                    {
                        'Action': 'UPSERT',
                        'ResourceRecordSet': {
                            'Name': dns_name,
                            'Type': 'A',
                            'TTL': 60,
                            'ResourceRecords': [
                                {
                                    'Value': public_ip
                                }
                            ]
                        }
                    }
                ]
            }
            
            route53_response = route53.change_resource_record_sets(
                HostedZoneId=hosted_zone_id,
                ChangeBatch=change_batch
            )
            
            print(f"DNS updated: {route53_response['ChangeInfo']['Id']}")
            
            return {
                'statusCode': 200,
                'headers': headers,
                'body': json.dumps({
                    'status': 'started',
                    'message': 'Minecraft server started successfully!',
                    'server_ip': public_ip,
                    'dns_name': dns_name,
                    'estimated_ready_time': '2-3 minutes',
                    'instructions': f'Connect to: {dns_name} (wait 2-3 minutes for Minecraft server to fully load)'
                }, ensure_ascii=False)
            }
            
        elif current_state in ['pending', 'starting']:
            # 起動中の場合
            return {
                'statusCode': 202,
                'headers': headers,
                'body': json.dumps({
                    'status': 'starting',
                    'message': 'Server is currently starting up...',
                    'dns_name': dns_name,
                    'estimated_ready_time': '3-5 minutes'
                }, ensure_ascii=False)
            }
            
        else:
            # その他の状態（terminated等）
            return {
                'statusCode': 400,
                'headers': headers,
                'body': json.dumps({
                    'status': 'error',
                    'message': f'Server is in {current_state} state and cannot be started',
                    'current_state': current_state
                }, ensure_ascii=False)
            }
            
    except Exception as e:
        print(f"Error in player trigger: {e}")
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({
                'status': 'error',
                'message': f'Failed to start server: {str(e)}',
                'instance_id': instance_id
            }, ensure_ascii=False)
        } 
