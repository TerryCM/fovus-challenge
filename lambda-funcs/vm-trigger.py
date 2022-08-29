# Author: Terry Cruz-Melo
# Date: 2020-05-01
# Description: This script is executed on the ec2 instance created by the lambda function

import json
import os
import time
import boto3

AMI = os.environ['AMI']
INSTANCE_TYPE = os.environ['INSTANCE_TYPE']
KEY_NAME = os.environ['KEY_NAME']
SUBNET_ID = os.environ['SUBNET_ID']
GROUP_ID = os.environ['GROUP_ID']
ACCESS_KEY = os.environ['ACCESS_KEY']
SECRET_KEY = os.environ['SECRET_KEY']
REGION = os.environ['REGION']
S3_BUCKET = os.environ['S3_BUCKET']
API_LINK = os.environ['API_LINK']


def create_vm(id_key):
    print('Creating boto3 client for ec2')
    ec2 = boto3.client('ec2', region_name=REGION)
    # download script file from S3
    print('Downloading script file from S3')
    s3 = boto3.client('s3')
    s3.download_file(S3_BUCKET, 'script.sh', '/tmp/script.sh')
    # download upload-img.pem from S3

    # creates the user data script to run on the ec2 instance
    user_data = """#!/bin/bash
    sudo apt update -y
    sudo apt install jq -y
    export AWS_ACCESS_KEY_ID=access_key
    export AWS_SECRET_ACCESS_KEY=secret_key
    export REGION=region
    export KEY_ID=id
    export API_LINK='api_link'"""
    # we will need to add the content of the script.sh file to the user_data script
    # open the script.sh file and read the content
    user_data = user_data.replace('access_key', ACCESS_KEY)
    user_data = user_data.replace('secret_key', SECRET_KEY)
    user_data = user_data.replace('region', REGION)
    user_data = user_data.replace('id', id_key)
    user_data = user_data.replace('api_link', API_LINK)

    with open('/tmp/script.sh', 'r') as f:
        content = f.read()
    # add the content to the user_data script
    user_data += content

    # show new user data

    print("New user data:")
    print(user_data)

    # create the instance
    print('Creating instance')
    response = ec2.run_instances(
        KeyName=KEY_NAME,
        ImageId=AMI,
        InstanceType=INSTANCE_TYPE,
        NetworkInterfaces=[
            {
                'SubnetId': SUBNET_ID,
                'Groups': [
                    GROUP_ID,
                ],
                'DeviceIndex': 0,
                'AssociatePublicIpAddress': True,
                'DeleteOnTermination': True
            }
        ],
        MinCount=1,
        MaxCount=1,
        UserData=user_data,

    )

    instance_id = response['Instances'][0]['InstanceId']
    print('Instance created: ' + instance_id)
    waiter = ec2.get_waiter('instance_running')
    waiter.wait(InstanceIds=[instance_id])
    # wait an extra 60 seconds to make sure the instance is ready, 'instance_status_ok' does not guarantee that
    print('Waiting 60 seconds for instance to be ready')
    time.sleep(60)
    print('Instance ready')

    ec2.terminate_instances(InstanceIds=[instance_id])
    print('Instance terminated')
    return "Done"


def lambda_handler(event, context):
    event_type = event['Records'][0]['eventName']
    id_key = event['Records'][0]['dynamodb']['NewImage']['id']['S']
    print('Event...')
    print(event)
    if event_type == 'INSERT':
        print('Starting instance with id: ' + id_key)
        create_vm(id_key)
    else:
        print('Event not supported')

    return {
        'statusCode': 200,
        'body': json.dumps('Done')
    }
