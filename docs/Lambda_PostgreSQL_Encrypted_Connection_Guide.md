# AWS Lambda with Encrypted PostgreSQL Connection Guide

## Overview
This guide explains how to configure AWS Lambda functions to connect to your encrypted PostgreSQL database. We'll cover SSL connections, secrets management, VPC configuration, and code examples for different encryption scenarios.

## Table of Contents
1. [Connection Methods Overview](#connection-methods-overview)
2. [SSL/TLS Connections](#ssltls-connections)
3. [AWS Secrets Manager Integration](#aws-secrets-manager-integration)
4. [VPC Configuration](#vpc-configuration)
5. [Lambda Function Code Examples](#lambda-function-code-examples)
6. [Environment Variables vs Secrets](#environment-variables-vs-secrets)
7. [Connection Pooling](#connection-pooling)
8. [Error Handling](#error-handling)
9. [Performance Optimization](#performance-optimization)
10. [Security Best Practices](#security-best-practices)

## Connection Methods Overview

### Current Setup (Unencrypted)
```python
import psycopg2

# Current connection method
conn = psycopg2.connect(
    host="your-postgres-host",
    database="your_database",
    user="your_username",
    password="your_password",
    port=5432
)
```

### Encrypted Setup Options
1. **SSL/TLS Connection** - Encrypt data in transit
2. **Secrets Manager** - Secure credential storage
3. **VPC Endpoints** - Secure network access
4. **Application-level decryption** - For column-level encryption

## SSL/TLS Connections

### 1. Basic SSL Connection
```python
import psycopg2
import os

def lambda_handler(event, context):
    try:
        # SSL connection with certificate verification
        conn = psycopg2.connect(
            host=os.environ['DB_HOST'],
            database=os.environ['DB_NAME'],
            user=os.environ['DB_USER'],
            password=os.environ['DB_PASSWORD'],
            port=5432,
            sslmode='require',  # Require SSL connection
            sslcert='/opt/client-cert.pem',  # Client certificate (optional)
            sslkey='/opt/client-key.pem',   # Client key (optional)
            sslrootcert='/opt/ca-cert.pem'  # CA certificate
        )
        
        # Your database operations here
        cursor = conn.cursor()
        cursor.execute("SELECT version();")
        result = cursor.fetchone()
        
        return {
            'statusCode': 200,
            'body': f'Connected successfully: {result[0]}'
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'body': f'Connection failed: {str(e)}'
        }
    finally:
        if 'conn' in locals():
            conn.close()
```

### 2. SSL Connection with Certificate Bundle
```python
import psycopg2
import ssl
import os

def create_ssl_context():
    """Create SSL context for PostgreSQL connection"""
    context = ssl.create_default_context()
    context.check_hostname = False
    context.verify_mode = ssl.CERT_REQUIRED
    
    # Load CA certificate
    context.load_verify_locations('/opt/ca-certificate.pem')
    
    return context

def lambda_handler(event, context):
    try:
        # Create SSL context
        ssl_context = create_ssl_context()
        
        conn = psycopg2.connect(
            host=os.environ['DB_HOST'],
            database=os.environ['DB_NAME'],
            user=os.environ['DB_USER'],
            password=os.environ['DB_PASSWORD'],
            port=5432,
            sslmode='require',
            sslcontext=ssl_context
        )
        
        # Database operations
        with conn.cursor() as cursor:
            cursor.execute("SELECT ssl_is_used();")
            ssl_status = cursor.fetchone()[0]
            
        return {
            'statusCode': 200,
            'body': f'SSL Connection Status: {ssl_status}'
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'body': f'Error: {str(e)}'
        }
    finally:
        if 'conn' in locals():
            conn.close()
```

## AWS Secrets Manager Integration

### 1. Store Database Credentials in Secrets Manager
```bash
# Create secret for database credentials
aws secretsmanager create-secret \
    --name "postgres-credentials" \
    --description "PostgreSQL database credentials" \
    --secret-string '{
        "username": "your_username",
        "password": "your_password",
        "engine": "postgres",
        "host": "your-postgres-host",
        "port": 5432,
        "dbname": "your_database",
        "sslmode": "require"
    }'
```

### 2. Lambda Function with Secrets Manager
```python
import json
import boto3
import psycopg2
from botocore.exceptions import ClientError

def get_secret(secret_name, region_name="us-east-1"):
    """Retrieve secret from AWS Secrets Manager"""
    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=region_name
    )
    
    try:
        get_secret_value_response = client.get_secret_value(SecretId=secret_name)
        secret = get_secret_value_response['SecretString']
        return json.loads(secret)
    except ClientError as e:
        raise e

def lambda_handler(event, context):
    try:
        # Get database credentials from Secrets Manager
        secret_name = "postgres-credentials"
        credentials = get_secret(secret_name)
        
        # Connect to PostgreSQL with SSL
        conn = psycopg2.connect(
            host=credentials['host'],
            database=credentials['dbname'],
            user=credentials['username'],
            password=credentials['password'],
            port=credentials['port'],
            sslmode=credentials.get('sslmode', 'require'),
            connect_timeout=10
        )
        
        # Your database operations
        with conn.cursor() as cursor:
            cursor.execute("SELECT current_user, inet_server_addr(), inet_server_port();")
            result = cursor.fetchone()
            
        return {
            'statusCode': 200,
            'body': json.dumps({
                'user': result[0],
                'server_ip': str(result[1]),
                'server_port': result[2],
                'ssl_enabled': True
            })
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
    finally:
        if 'conn' in locals():
            conn.close()
```

### 3. Enhanced Secrets Manager with Rotation
```python
import json
import boto3
import psycopg2
from datetime import datetime, timedelta

class DatabaseConnection:
    def __init__(self, secret_name, region='us-east-1'):
        self.secret_name = secret_name
        self.region = region
        self.secrets_client = boto3.client('secretsmanager', region_name=region)
        self._credentials = None
        self._credentials_expiry = None
        
    def _get_credentials(self):
        """Get credentials with caching"""
        now = datetime.now()
        
        # Refresh credentials if expired or not cached
        if (self._credentials is None or 
            self._credentials_expiry is None or 
            now > self._credentials_expiry):
            
            try:
                response = self.secrets_client.get_secret_value(SecretId=self.secret_name)
                self._credentials = json.loads(response['SecretString'])
                # Cache for 5 minutes
                self._credentials_expiry = now + timedelta(minutes=5)
            except Exception as e:
                print(f"Failed to retrieve credentials: {e}")
                raise
                
        return self._credentials
    
    def get_connection(self):
        """Get PostgreSQL connection with SSL"""
        credentials = self._get_credentials()
        
        return psycopg2.connect(
            host=credentials['host'],
            database=credentials['dbname'],
            user=credentials['username'],
            password=credentials['password'],
            port=credentials.get('port', 5432),
            sslmode=credentials.get('sslmode', 'require'),
            connect_timeout=10,
            application_name='lambda-function'
        )

# Global connection manager
db_manager = DatabaseConnection('postgres-credentials')

def lambda_handler(event, context):
    try:
        conn = db_manager.get_connection()
        
        with conn.cursor() as cursor:
            # Example: Query with encrypted data
            cursor.execute("""
                SELECT 
                    id,
                    username,
                    pgp_sym_decrypt(encrypted_email, %s) as email
                FROM users 
                WHERE id = %s
            """, (os.environ['ENCRYPTION_KEY'], event.get('user_id')))
            
            result = cursor.fetchone()
            
        return {
            'statusCode': 200,
            'body': json.dumps({
                'user_id': result[0],
                'username': result[1],
                'email': result[2]
            })
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
    finally:
        if 'conn' in locals():
            conn.close()
```

## VPC Configuration

### 1. Lambda VPC Configuration
```bash
# Configure Lambda to run in VPC
aws lambda update-function-configuration \
    --function-name your-lambda-function \
    --vpc-config SubnetIds=subnet-12345,subnet-67890,SecurityGroupIds=sg-abcdef

# Create security group for Lambda
aws ec2 create-security-group \
    --group-name lambda-postgres-sg \
    --description "Security group for Lambda to access PostgreSQL" \
    --vpc-id vpc-xxxxxxxxx

# Allow Lambda to connect to PostgreSQL
aws ec2 authorize-security-group-egress \
    --group-id sg-lambda-id \
    --protocol tcp \
    --port 5432 \
    --source-group sg-postgres-id
```

### 2. VPC Endpoints for Secrets Manager
```bash
# Create VPC endpoint for Secrets Manager
aws ec2 create-vpc-endpoint \
    --vpc-id vpc-xxxxxxxxx \
    --service-name com.amazonaws.us-east-1.secretsmanager \
    --vpc-endpoint-type Interface \
    --subnet-ids subnet-12345 subnet-67890 \
    --security-group-ids sg-secrets-manager \
    --policy-document file://secrets-manager-policy.json
```

## Lambda Function Code Examples

### 1. Python-Only Implementation Focus
Since you use Python exclusively, all examples below are optimized Python implementations for your Lambda functions.

### 1. Python with Connection Pooling
```python
import json
import psycopg2
from psycopg2 import pool
import boto3
import os

class DatabasePool:
    _instance = None
    _pool = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(DatabasePool, cls).__new__(cls)
        return cls._instance
    
    def __init__(self):
        if self._pool is None:
            self._initialize_pool()
    
    def _get_credentials(self):
        secrets_client = boto3.client('secretsmanager')
        response = secrets_client.get_secret_value(SecretId='postgres-credentials')
        return json.loads(response['SecretString'])
    
    def _initialize_pool(self):
        credentials = self._get_credentials()
        
        self._pool = psycopg2.pool.ThreadedConnectionPool(
            minconn=1,
            maxconn=5,
            host=credentials['host'],
            database=credentials['dbname'],
            user=credentials['username'],
            password=credentials['password'],
            port=credentials.get('port', 5432),
            sslmode='require'
        )
    
    def get_connection(self):
        return self._pool.getconn()
    
    def put_connection(self, conn):
        self._pool.putconn(conn)

# Global pool instance
db_pool = DatabasePool()

def lambda_handler(event, context):
    conn = None
    try:
        # Get connection from pool
        conn = db_pool.get_connection()
        
        with conn.cursor() as cursor:
            # Handle encrypted data
            if event.get('operation') == 'get_user':
                cursor.execute("""
                    SELECT 
                        id,
                        username,
                        pgp_sym_decrypt(encrypted_email, %s) as email,
                        created_at
                    FROM users 
                    WHERE id = %s
                """, (os.environ['ENCRYPTION_KEY'], event['user_id']))
                
                result = cursor.fetchone()
                
                return {
                    'statusCode': 200,
                    'body': json.dumps({
                        'id': result[0],
                        'username': result[1],
                        'email': result[2],
                        'created_at': result[3].isoformat()
                    }, default=str)
                }
            
            elif event.get('operation') == 'create_user':
                cursor.execute("""
                    INSERT INTO users (username, encrypted_email, encrypted_phone)
                    VALUES (%s, pgp_sym_encrypt(%s, %s), pgp_sym_encrypt(%s, %s))
                    RETURNING id
                """, (
                    event['username'],
                    event['email'],
                    os.environ['ENCRYPTION_KEY'],
                    event['phone'],
                    os.environ['ENCRYPTION_KEY']
                ))
                
                user_id = cursor.fetchone()[0]
                conn.commit()
                
                return {
                    'statusCode': 201,
                    'body': json.dumps({'user_id': user_id})
                }
        
    except Exception as e:
        if conn:
            conn.rollback()
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
    finally:
        if conn:
            db_pool.put_connection(conn)
```

## Environment Variables vs Secrets

### 1. Environment Variables (Less Secure)
```python
# Lambda environment variables
DB_HOST = os.environ['DB_HOST']
DB_NAME = os.environ['DB_NAME']
DB_USER = os.environ['DB_USER']
DB_PASSWORD = os.environ['DB_PASSWORD']  # Not recommended for production
ENCRYPTION_KEY = os.environ['ENCRYPTION_KEY']  # Not recommended
```

### 2. AWS Systems Manager Parameter Store
```python
import boto3

def get_parameter(parameter_name, decrypt=True):
    ssm = boto3.client('ssm')
    response = ssm.get_parameter(
        Name=parameter_name,
        WithDecryption=decrypt
    )
    return response['Parameter']['Value']

def lambda_handler(event, context):
    try:
        # Get parameters from Parameter Store
        db_host = get_parameter('/myapp/database/host', decrypt=False)
        db_password = get_parameter('/myapp/database/password', decrypt=True)
        encryption_key = get_parameter('/myapp/encryption/key', decrypt=True)
        
        # Use parameters for connection
        conn = psycopg2.connect(
            host=db_host,
            database=os.environ['DB_NAME'],
            user=os.environ['DB_USER'],
            password=db_password,
            sslmode='require'
        )
        
        # Your database operations with encryption key
        
    except Exception as e:
        return {'statusCode': 500, 'body': str(e)}
```

## Connection Pooling

### 1. Lambda Layer for Database Dependencies
```bash
# Create layer for psycopg2 and other dependencies
mkdir -p lambda-layer/python
pip install psycopg2-binary boto3 -t lambda-layer/python/
cd lambda-layer
zip -r ../database-layer.zip .

# Create Lambda layer
aws lambda publish-layer-version \
    --layer-name database-connections \
    --zip-file fileb://database-layer.zip \
    --compatible-runtimes python3.9 python3.8
```

### 2. RDS Proxy Integration
```python
import psycopg2
import boto3

def lambda_handler(event, context):
    try:
        # Connect through RDS Proxy for connection pooling
        conn = psycopg2.connect(
            host='your-rds-proxy-endpoint.proxy-xxxxxxxxx.us-east-1.rds.amazonaws.com',
            database=os.environ['DB_NAME'],
            user=os.environ['DB_USER'],
            password=os.environ['DB_PASSWORD'],
            port=5432,
            sslmode='require'
        )
        
        # Database operations
        with conn.cursor() as cursor:
            cursor.execute("SELECT 1")
            result = cursor.fetchone()
        
        return {
            'statusCode': 200,
            'body': 'Connection successful via RDS Proxy'
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'body': f'Error: {str(e)}'
        }
    finally:
        if 'conn' in locals():
            conn.close()
```

## Error Handling

### 1. Comprehensive Error Handling
```python
import psycopg2
from psycopg2 import OperationalError, DatabaseError
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    conn = None
    try:
        # Database connection code here
        conn = get_database_connection()
        
        with conn.cursor() as cursor:
            cursor.execute("SELECT 1")
            
    except OperationalError as e:
        logger.error(f"Database connection error: {e}")
        return {
            'statusCode': 503,
            'body': json.dumps({'error': 'Database connection failed'})
        }
    except DatabaseError as e:
        logger.error(f"Database error: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Database operation failed'})
        }
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal server error'})
        }
    finally:
        if conn:
            conn.close()
```

## Performance Optimization

### 1. Connection Reuse
```python
import psycopg2
from psycopg2.extras import RealDictCursor

# Global connection variable
connection = None

def get_connection():
    global connection
    
    if connection is None or connection.closed:
        connection = psycopg2.connect(
            host=os.environ['DB_HOST'],
            database=os.environ['DB_NAME'],
            user=os.environ['DB_USER'],
            password=os.environ['DB_PASSWORD'],
            sslmode='require',
            cursor_factory=RealDictCursor
        )
    
    return connection

def lambda_handler(event, context):
    try:
        conn = get_connection()
        
        with conn.cursor() as cursor:
            cursor.execute("SELECT version()")
            result = cursor.fetchone()
        
        return {
            'statusCode': 200,
            'body': json.dumps(dict(result))
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
```

## Security Best Practices

### 1. IAM Roles and Policies
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue"
            ],
            "Resource": "arn:aws:secretsmanager:region:account:secret:postgres-credentials-*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssm:GetParameter",
                "ssm:GetParameters"
            ],
            "Resource": "arn:aws:ssm:region:account:parameter/myapp/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "kms:Decrypt"
            ],
            "Resource": "arn:aws:kms:region:account:key/your-kms-key-id"
        }
    ]
}
```

### 2. Encryption Key Management
```python
import boto3
from botocore.exceptions import ClientError

def get_encryption_key():
    """Get encryption key from KMS"""
    kms = boto3.client('kms')
    
    try:
        response = kms.decrypt(
            CiphertextBlob=base64.b64decode(os.environ['ENCRYPTED_KEY'])
        )
        return response['Plaintext'].decode('utf-8')
    except ClientError as e:
        logger.error(f"Failed to decrypt key: {e}")
        raise

def lambda_handler(event, context):
    try:
        encryption_key = get_encryption_key()
        
        # Use encryption key for database operations
        conn = get_database_connection()
        
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT pgp_sym_decrypt(encrypted_data, %s) 
                FROM sensitive_table 
                WHERE id = %s
            """, (encryption_key, event['id']))
            
            result = cursor.fetchone()
        
        return {
            'statusCode': 200,
            'body': json.dumps({'data': result[0]})
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
```

## Implementation Checklist

### Pre-Implementation
- [ ] Update Lambda execution role with required permissions
- [ ] Store database credentials in Secrets Manager
- [ ] Configure Lambda VPC settings
- [ ] Install SSL certificates in Lambda layer or container

### SSL Configuration
- [ ] Update connection strings to use `sslmode='require'`
- [ ] Include CA certificates in Lambda deployment package
- [ ] Test SSL connection from Lambda environment
- [ ] Verify certificate validation

### Secrets Management
- [ ] Migrate hardcoded credentials to Secrets Manager
- [ ] Update Lambda code to retrieve secrets
- [ ] Test secret rotation compatibility
- [ ] Set up monitoring for secret access

### Testing
- [ ] Test database connectivity from Lambda
- [ ] Verify encrypted data operations
- [ ] Test error handling scenarios
- [ ] Performance testing with encryption

This guide ensures your Lambda functions can securely connect to encrypted PostgreSQL while maintaining the same functionality with enhanced security.
