import boto3
import time
import os

def lambda_handler(event, context):
    # 環境変数から値を取得
    instance_id = os.environ['INSTANCE_ID']
    hosted_zone_id = os.environ['HOSTED_ZONE_ID']
    dns_name = os.environ['DNS_NAME']
    
    print(f"Starting instance: {instance_id}")
    
    # EC2クライアント
    ec2 = boto3.client('ec2')
    
    # EC2インスタンスを起動
    try:
        response = ec2.start_instances(InstanceIds=[instance_id])
        print(f"Start instances response: {response}")
    except Exception as e:
        print(f"Error starting instance: {e}")
        return {
            'statusCode': 500,
            'body': f'Failed to start instance: {e}'
        }
    
    # EC2インスタンスが起動するのを待つ
    print("Waiting for instance to be running...")
    instance_running = False
    max_wait_time = 300  # 5分でタイムアウト
    start_time = time.time()
    
    while not instance_running:
        if time.time() - start_time > max_wait_time:
            print("Timeout waiting for instance to start")
            return {
                'statusCode': 500,
                'body': 'Timeout waiting for instance to start'
            }
            
        try:
            instance = ec2.describe_instances(InstanceIds=[instance_id])
            state = instance['Reservations'][0]['Instances'][0]['State']['Name']
            print(f"Instance state: {state}")
            
            if state == 'running':
                instance_running = True
            else:
                time.sleep(10)  # 10秒待機
        except Exception as e:
            print(f"Error checking instance state: {e}")
            time.sleep(10)
    
    # EC2インスタンスのパブリックIPアドレスを取得
    try:
        instance = ec2.describe_instances(InstanceIds=[instance_id])
        public_ip = instance['Reservations'][0]['Instances'][0]['PublicIpAddress']
        print(f"Instance public IP: {public_ip}")
    except Exception as e:
        print(f"Error getting public IP: {e}")
        return {
            'statusCode': 500,
            'body': f'Failed to get public IP: {e}'
        }
    
    # Route53でAレコードを更新
    route53 = boto3.client('route53')
    
    change_batch = {
        'Comment': f'Update {dns_name} to point to new EC2 instance IP',
        'Changes': [
            {
                'Action': 'UPSERT',
                'ResourceRecordSet': {
                    'Name': dns_name,
                    'Type': 'A',
                    'TTL': 60,  # 短いTTLで設定
                    'ResourceRecords': [
                        {
                            'Value': public_ip
                        }
                    ]
                }
            }
        ]
    }
    
    try:
        response = route53.change_resource_record_sets(
            HostedZoneId=hosted_zone_id,
            ChangeBatch=change_batch
        )
        change_id = response['ChangeInfo']['Id']
        print(f"Route53 change submitted: {change_id}")
        print(f"Updated {dns_name} to point to {public_ip}")
        
        return {
            'statusCode': 200,
            'body': f'Successfully updated {dns_name} to {public_ip}. Change ID: {change_id}'
        }
    except Exception as e:
        print(f"Error updating Route53 record: {e}")
        return {
            'statusCode': 500,
            'body': f'Failed to update Route53 record: {e}'
        } 
