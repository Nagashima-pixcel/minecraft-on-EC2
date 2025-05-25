import boto3
import time
import os
import json

def lambda_handler(event, context):
    """
    Minecraft Server Auto Management Lambda Function
    - EC2インスタンス自動起動
    - Route53 DNS自動更新
    - 起動後の監視設定
    """
    
    # 環境変数から値を取得
    instance_id = os.environ['INSTANCE_ID']
    hosted_zone_id = os.environ['HOSTED_ZONE_ID']
    dns_name = os.environ['DNS_NAME']
    aws_region = os.environ['MINECRAFT_AWS_REGION']
    
    print(f"Starting Minecraft server management for instance: {instance_id}")
    
    # AWSクライアント初期化
    ec2 = boto3.client('ec2', region_name=aws_region)
    route53 = boto3.client('route53')
    ssm = boto3.client('ssm', region_name=aws_region)
    
    try:
        # 1. EC2インスタンスの状態確認
        instance_response = ec2.describe_instances(InstanceIds=[instance_id])
        instance_state = instance_response['Reservations'][0]['Instances'][0]['State']['Name']
        
        print(f"Current instance state: {instance_state}")
        
        if instance_state == 'running':
            print("Instance is already running, updating DNS only")
            public_ip = instance_response['Reservations'][0]['Instances'][0]['PublicIpAddress']
        else:
            # 2. EC2インスタンスを起動
            print("Starting EC2 instance...")
            start_response = ec2.start_instances(InstanceIds=[instance_id])
            print(f"Start instances response: {start_response}")
            
            # 3. インスタンスが起動するまで待機
            print("Waiting for instance to be running...")
            instance_running = False
            max_wait_time = 300  # 5分でタイムアウト
            start_time = time.time()
            
            while not instance_running:
                if time.time() - start_time > max_wait_time:
                    raise Exception("Timeout waiting for instance to start")
                    
                instance_response = ec2.describe_instances(InstanceIds=[instance_id])
                state = instance_response['Reservations'][0]['Instances'][0]['State']['Name']
                print(f"Instance state: {state}")
                
                if state == 'running':
                    instance_running = True
                    public_ip = instance_response['Reservations'][0]['Instances'][0]['PublicIpAddress']
                    print(f"Instance is now running with IP: {public_ip}")
                else:
                    time.sleep(10)
        
        # 4. Route53でAレコードを更新
        print("Updating Route53 DNS record...")
        change_batch = {
            'Comment': f'Auto-update {dns_name} to point to Minecraft server',
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
        change_id = route53_response['ChangeInfo']['Id']
        print(f"Route53 change submitted: {change_id}")
        
        # 5. 自動停止監視の有効化確認
        print("Verifying auto-stop monitoring is enabled...")
        try:
            # CloudWatch Eventsルールの状態確認
            events = boto3.client('events', region_name=aws_region)
            rule_response = events.describe_rule(Name='minecraft-player-check-rule')
            if rule_response['State'] == 'ENABLED':
                print("Auto-stop monitoring is active")
            else:
                print("Warning: Auto-stop monitoring is disabled")
        except Exception as e:
            print(f"Could not verify auto-stop monitoring: {e}")
        
        # 6. 成功レスポンス
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Successfully started Minecraft server',
                'instance_id': instance_id,
                'public_ip': public_ip,
                'dns_name': dns_name,
                'route53_change_id': change_id,
                'auto_stop_enabled': True
            })
        }
        
    except Exception as e:
        print(f"Error in auto management: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'instance_id': instance_id
            })
        } 
