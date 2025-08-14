# PostgreSQL Encryption Implementation Guide

## Overview
This guide provides step-by-step instructions for encrypting an existing PostgreSQL database running in a Docker container on AWS EC2. We'll cover multiple encryption strategies to secure your data both in transit and at rest.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Backup Strategy](#backup-strategy)
3. [SSL/TLS Encryption (In Transit)](#ssltls-encryption-in-transit)
4. [Encryption at Rest](#encryption-at-rest)
5. [Application-Level Encryption](#application-level-encryption)
6. [Migration Steps](#migration-steps)
7. [Testing & Validation](#testing--validation)
8. [Monitoring & Maintenance](#monitoring--maintenance)
9. [Troubleshooting](#troubleshooting)

## Prerequisites

### System Requirements
- Existing PostgreSQL Docker container
- AWS EC2 instance with appropriate permissions
- Root/sudo access to the EC2 instance
- Backup of existing database

### Tools Needed
```bash
# Install required tools
sudo yum update -y
sudo yum install -y openssl postgresql-client
```

## Backup Strategy

### 1. Create Full Database Backup
```bash
# Create backup directory
sudo mkdir -p /backup/postgres
sudo chmod 755 /backup/postgres

# Get container name/ID
docker ps | grep postgres

# Create full backup
docker exec -t your-postgres-container pg_dumpall -c -U postgres > /backup/postgres/full_backup_$(date +%Y%m%d_%H%M%S).sql

# Verify backup
ls -la /backup/postgres/
```

### 2. Create Data Volume Backup
```bash
# Stop the container temporarily
docker stop your-postgres-container

# Create volume backup
docker run --rm -v postgres_data:/data -v /backup:/backup alpine tar czf /backup/postgres_data_backup_$(date +%Y%m%d_%H%M%S).tar.gz -C /data .

# Restart container
docker start your-postgres-container
```

## SSL/TLS Encryption (In Transit)

### 1. Generate SSL Certificates

#### Option A: Self-Signed Certificates (Development/Internal)
```bash
# Create certificate directory
mkdir -p /opt/postgres-ssl
cd /opt/postgres-ssl

# Generate private key
openssl genrsa -out server.key 2048

# Generate certificate signing request
openssl req -new -key server.key -out server.csr -subj "/C=US/ST=State/L=City/O=Organization/OU=IT/CN=postgres.internal.company.com"

# Generate self-signed certificate
openssl x509 -req -in server.csr -signkey server.key -out server.crt -days 365

# Set proper permissions
chmod 600 server.key
chmod 644 server.crt
chown 999:999 server.key server.crt  # PostgreSQL user in container
```

#### Option B: AWS Certificate Manager Private CA
```bash
# Request certificate from private CA
aws acm request-certificate \
    --domain-name postgres.internal.company.com \
    --certificate-authority-arn arn:aws:acm-pca:region:account:certificate-authority/your-ca-id \
    --domain-validation-options DomainName=postgres.internal.company.com,ValidationDomain=internal.company.com

# Export certificate and key (after validation)
aws acm export-certificate \
    --certificate-arn arn:aws:acm:region:account:certificate/certificate-id \
    --passphrase mypassphrase > certificate.json
```

### 2. Configure PostgreSQL for SSL

#### Update Docker Container Configuration
```bash
# Stop existing container
docker stop your-postgres-container

# Create new container with SSL configuration
docker run -d \
    --name postgres-ssl \
    --restart unless-stopped \
    -e POSTGRES_DB=your_database \
    -e POSTGRES_USER=your_user \
    -e POSTGRES_PASSWORD=your_password \
    -v postgres_data:/var/lib/postgresql/data \
    -v /opt/postgres-ssl:/var/lib/postgresql/ssl:ro \
    -p 5432:5432 \
    postgres:15 \
    -c ssl=on \
    -c ssl_cert_file=/var/lib/postgresql/ssl/server.crt \
    -c ssl_key_file=/var/lib/postgresql/ssl/server.key \
    -c ssl_ciphers='HIGH:MEDIUM:+3DES:!aNULL' \
    -c ssl_prefer_server_ciphers=on \
    -c ssl_protocols='TLSv1.2,TLSv1.3'
```

#### Alternative: Update Existing Container
```bash
# Copy certificates to running container
docker cp /opt/postgres-ssl/server.crt your-postgres-container:/var/lib/postgresql/data/
docker cp /opt/postgres-ssl/server.key your-postgres-container:/var/lib/postgresql/data/

# Connect to container and update postgresql.conf
docker exec -it your-postgres-container bash

# Edit postgresql.conf
echo "ssl = on" >> /var/lib/postgresql/data/postgresql.conf
echo "ssl_cert_file = 'server.crt'" >> /var/lib/postgresql/data/postgresql.conf
echo "ssl_key_file = 'server.key'" >> /var/lib/postgresql/data/postgresql.conf
echo "ssl_ciphers = 'HIGH:MEDIUM:+3DES:!aNULL'" >> /var/lib/postgresql/data/postgresql.conf
echo "ssl_prefer_server_ciphers = on" >> /var/lib/postgresql/data/postgresql.conf

# Restart PostgreSQL
docker restart your-postgres-container
```

### 3. Configure Client Authentication
```bash
# Update pg_hba.conf to require SSL
docker exec -it your-postgres-container bash

# Edit pg_hba.conf
cat >> /var/lib/postgresql/data/pg_hba.conf << EOF
# SSL connections only
hostssl all all 0.0.0.0/0 md5
host all all 127.0.0.1/32 md5  # Local connections
EOF

# Restart container
docker restart your-postgres-container
```

## Encryption at Rest

### 1. AWS EBS Encryption

#### For New Setup
```bash
# Create encrypted EBS volume
aws ec2 create-volume \
    --size 100 \
    --volume-type gp3 \
    --encrypted \
    --kms-key-id arn:aws:kms:region:account:key/your-kms-key-id \
    --availability-zone $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)

# Attach volume to instance
aws ec2 attach-volume \
    --volume-id vol-xxxxxxxxx \
    --instance-id $(curl -s http://169.254.169.254/latest/meta-data/instance-id) \
    --device /dev/sdf
```

#### For Existing Data Migration
```bash
# 1. Stop PostgreSQL container
docker stop your-postgres-container

# 2. Create encrypted volume (as above)

# 3. Format and mount new encrypted volume
sudo mkfs.ext4 /dev/xvdf
sudo mkdir /encrypted-data
sudo mount /dev/xvdf /encrypted-data

# 4. Copy existing data
sudo cp -a /var/lib/docker/volumes/postgres_data/_data/* /encrypted-data/

# 5. Update volume mount
docker run -d \
    --name postgres-encrypted \
    --restart unless-stopped \
    -e POSTGRES_DB=your_database \
    -e POSTGRES_USER=your_user \
    -e POSTGRES_PASSWORD=your_password \
    -v /encrypted-data:/var/lib/postgresql/data \
    -v /opt/postgres-ssl:/var/lib/postgresql/ssl:ro \
    -p 5432:5432 \
    postgres:15 \
    -c ssl=on \
    -c ssl_cert_file=/var/lib/postgresql/ssl/server.crt \
    -c ssl_key_file=/var/lib/postgresql/ssl/server.key
```

### 2. File System Level Encryption (LUKS)

```bash
# Install cryptsetup
sudo yum install -y cryptsetup

# Create encrypted partition
sudo cryptsetup luksFormat /dev/xvdf

# Open encrypted partition
sudo cryptsetup luksOpen /dev/xvdf postgres_encrypted

# Format and mount
sudo mkfs.ext4 /dev/mapper/postgres_encrypted
sudo mkdir /encrypted-postgres
sudo mount /dev/mapper/postgres_encrypted /encrypted-postgres

# Add to /etc/fstab for persistence
echo "/dev/mapper/postgres_encrypted /encrypted-postgres ext4 defaults 0 2" | sudo tee -a /etc/fstab

# Create key file for auto-mounting
sudo dd if=/dev/urandom of=/root/postgres.key bs=1024 count=4
sudo chmod 400 /root/postgres.key
sudo cryptsetup luksAddKey /dev/xvdf /root/postgres.key

# Add to /etc/crypttab
echo "postgres_encrypted /dev/xvdf /root/postgres.key luks" | sudo tee -a /etc/crypttab
```

## Application-Level Encryption

### 1. Install pgcrypto Extension
```sql
-- Connect to your database
docker exec -it your-postgres-container psql -U postgres -d your_database

-- Install pgcrypto extension
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Verify installation
\dx pgcrypto
```

### 2. Column-Level Encryption Implementation

#### For New Columns
```sql
-- Example: Encrypting sensitive user data
CREATE TABLE users_encrypted (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL,
    encrypted_ssn BYTEA,  -- Encrypted field
    encrypted_credit_card BYTEA,  -- Encrypted field
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert encrypted data
INSERT INTO users_encrypted (username, email, encrypted_ssn, encrypted_credit_card)
VALUES (
    'john_doe',
    'john@example.com',
    pgp_sym_encrypt('123-45-6789', 'your_encryption_key'),
    pgp_sym_encrypt('4111-1111-1111-1111', 'your_encryption_key')
);

-- Query encrypted data
SELECT 
    username,
    email,
    pgp_sym_decrypt(encrypted_ssn, 'your_encryption_key') AS ssn,
    pgp_sym_decrypt(encrypted_credit_card, 'your_encryption_key') AS credit_card
FROM users_encrypted
WHERE username = 'john_doe';
```

#### For Existing Columns (Migration)
```sql
-- Step 1: Add new encrypted columns
ALTER TABLE existing_users ADD COLUMN encrypted_ssn BYTEA;
ALTER TABLE existing_users ADD COLUMN encrypted_phone BYTEA;

-- Step 2: Migrate existing data
UPDATE existing_users 
SET encrypted_ssn = pgp_sym_encrypt(ssn, 'your_encryption_key')
WHERE ssn IS NOT NULL;

UPDATE existing_users 
SET encrypted_phone = pgp_sym_encrypt(phone, 'your_encryption_key')
WHERE phone IS NOT NULL;

-- Step 3: Verify migration
SELECT 
    id,
    ssn,
    pgp_sym_decrypt(encrypted_ssn, 'your_encryption_key') AS decrypted_ssn
FROM existing_users 
LIMIT 5;

-- Step 4: Drop old columns (after verification)
-- ALTER TABLE existing_users DROP COLUMN ssn;
-- ALTER TABLE existing_users DROP COLUMN phone;
```

### 3. Key Management Best Practices

#### Environment Variables Approach
```bash
# Create environment file
cat > /opt/postgres-keys/.env << EOF
DB_ENCRYPTION_KEY=your_very_secure_encryption_key_here
DB_MASTER_KEY=another_secure_master_key
EOF

# Secure the file
chmod 600 /opt/postgres-keys/.env
chown root:root /opt/postgres-keys/.env

# Update Docker container to use environment file
docker run -d \
    --name postgres-encrypted \
    --env-file /opt/postgres-keys/.env \
    # ... other parameters
```

#### AWS KMS Integration
```sql
-- Create function to use AWS KMS
CREATE OR REPLACE FUNCTION encrypt_with_kms(plaintext TEXT, key_id TEXT)
RETURNS BYTEA AS $$
DECLARE
    encrypted_data BYTEA;
BEGIN
    -- This would require a custom extension or external service call
    -- For now, use pgcrypto with KMS-derived keys
    RETURN pgp_sym_encrypt(plaintext, key_id);
END;
$$ LANGUAGE plpgsql;
```

## Migration Steps

### 1. Pre-Migration Checklist
- [ ] Full database backup completed
- [ ] SSL certificates generated and tested
- [ ] Encrypted storage prepared
- [ ] Application connection strings updated
- [ ] Maintenance window scheduled

### 2. Migration Process

#### Step 1: Enable SSL (Zero Downtime)
```bash
# 1. Copy certificates to container
docker cp /opt/postgres-ssl/server.crt your-postgres-container:/var/lib/postgresql/data/
docker cp /opt/postgres-ssl/server.key your-postgres-container:/var/lib/postgresql/data/

# 2. Enable SSL without requiring it
docker exec -it your-postgres-container psql -U postgres -c "ALTER SYSTEM SET ssl = 'on';"
docker exec -it your-postgres-container psql -U postgres -c "ALTER SYSTEM SET ssl_cert_file = 'server.crt';"
docker exec -it your-postgres-container psql -U postgres -c "ALTER SYSTEM SET ssl_key_file = 'server.key';"
docker exec -it your-postgres-container psql -U postgres -c "SELECT pg_reload_conf();"

# 3. Test SSL connection
psql "host=localhost port=5432 dbname=your_database user=your_user sslmode=require"
```

#### Step 2: Migrate to Encrypted Storage
```bash
# 1. Create maintenance page for application
# 2. Stop application connections
# 3. Perform final backup
# 4. Stop PostgreSQL container
# 5. Copy data to encrypted volume
# 6. Start container with new volume
# 7. Verify data integrity
# 8. Resume application
```

#### Step 3: Implement Column Encryption (Gradual)
```sql
-- Implement column by column during low-traffic periods
-- Use transactions for data consistency
BEGIN;
ALTER TABLE sensitive_table ADD COLUMN encrypted_field BYTEA;
UPDATE sensitive_table SET encrypted_field = pgp_sym_encrypt(plain_field, 'key');
-- Test and verify before committing
COMMIT;
```

## Testing & Validation

### 1. SSL Connection Testing
```bash
# Test SSL connection
psql "host=your-host port=5432 dbname=your_db user=your_user sslmode=require" -c "SELECT version();"

# Verify SSL is active
psql "host=your-host port=5432 dbname=your_db user=your_user sslmode=require" -c "SELECT ssl_is_used();"

# Check SSL cipher
psql "host=your-host port=5432 dbname=your_db user=your_user sslmode=require" -c "SELECT ssl_cipher();"
```

### 2. Encryption Validation
```sql
-- Test column encryption/decryption
SELECT 
    original_value,
    encrypted_value,
    pgp_sym_decrypt(encrypted_value, 'your_key') AS decrypted_value
FROM test_table
LIMIT 5;

-- Verify data integrity
SELECT COUNT(*) FROM table_name WHERE encrypted_field IS NOT NULL;
```

### 3. Performance Testing
```sql
-- Test query performance with encryption
EXPLAIN ANALYZE SELECT * FROM encrypted_table 
WHERE pgp_sym_decrypt(encrypted_field, 'key') = 'search_value';

-- Create indexes on encrypted data (if needed)
CREATE INDEX idx_encrypted_field_hash ON table_name USING hash(encrypted_field);
```

## Monitoring & Maintenance

### 1. SSL Certificate Monitoring
```bash
# Check certificate expiration
openssl x509 -in /opt/postgres-ssl/server.crt -text -noout | grep "Not After"

# Create monitoring script
cat > /opt/scripts/check_ssl_cert.sh << 'EOF'
#!/bin/bash
CERT_FILE="/opt/postgres-ssl/server.crt"
DAYS_WARNING=30

EXPIRY_DATE=$(openssl x509 -in $CERT_FILE -text -noout | grep "Not After" | cut -d: -f2-)
EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s)
CURRENT_EPOCH=$(date +%s)
DAYS_LEFT=$(( ($EXPIRY_EPOCH - $CURRENT_EPOCH) / 86400 ))

if [ $DAYS_LEFT -lt $DAYS_WARNING ]; then
    echo "WARNING: SSL certificate expires in $DAYS_LEFT days"
    # Send alert (email, SNS, etc.)
fi
EOF

chmod +x /opt/scripts/check_ssl_cert.sh

# Add to crontab
echo "0 6 * * * /opt/scripts/check_ssl_cert.sh" | crontab -
```

### 2. Backup Encrypted Data
```bash
# Automated backup script
cat > /opt/scripts/backup_encrypted_db.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/backup/postgres"
DATE=$(date +%Y%m%d_%H%M%S)
CONTAINER_NAME="your-postgres-container"

# Create encrypted backup
docker exec -t $CONTAINER_NAME pg_dumpall -c -U postgres | \
    gpg --symmetric --cipher-algo AES256 --output $BACKUP_DIR/backup_$DATE.sql.gpg

# Verify backup
if [ $? -eq 0 ]; then
    echo "Backup completed successfully: backup_$DATE.sql.gpg"
    # Clean old backups (keep last 7 days)
    find $BACKUP_DIR -name "backup_*.sql.gpg" -mtime +7 -delete
else
    echo "Backup failed!"
    exit 1
fi
EOF

chmod +x /opt/scripts/backup_encrypted_db.sh

# Schedule daily backups
echo "0 2 * * * /opt/scripts/backup_encrypted_db.sh" | crontab -
```

### 3. Performance Monitoring
```sql
-- Create monitoring views
CREATE VIEW encryption_performance AS
SELECT 
    schemaname,
    tablename,
    attname as column_name,
    n_distinct,
    correlation
FROM pg_stats 
WHERE tablename IN (SELECT tablename FROM pg_tables WHERE tablename LIKE '%encrypted%');

-- Monitor query performance
CREATE VIEW slow_encrypted_queries AS
SELECT 
    query,
    mean_time,
    calls,
    total_time
FROM pg_stat_statements 
WHERE query LIKE '%pgp_sym_%'
ORDER BY mean_time DESC;
```

## Troubleshooting

### Common SSL Issues

#### Issue: SSL Connection Refused
```bash
# Check if SSL is enabled
docker exec -it your-postgres-container psql -U postgres -c "SHOW ssl;"

# Check certificate permissions
docker exec -it your-postgres-container ls -la /var/lib/postgresql/data/server.*

# Check PostgreSQL logs
docker logs your-postgres-container | grep -i ssl
```

#### Issue: Certificate Verification Failed
```bash
# Test with different SSL modes
psql "host=localhost sslmode=disable" -c "SELECT 1;"  # Should work
psql "host=localhost sslmode=require" -c "SELECT 1;"  # Test SSL
psql "host=localhost sslmode=verify-ca" -c "SELECT 1;"  # Test CA verification

# Check certificate details
openssl x509 -in /opt/postgres-ssl/server.crt -text -noout
```

### Common Encryption Issues

#### Issue: Decryption Fails
```sql
-- Check if pgcrypto is installed
SELECT * FROM pg_extension WHERE extname = 'pgcrypto';

-- Test encryption/decryption
SELECT pgp_sym_decrypt(pgp_sym_encrypt('test', 'key'), 'key');

-- Check for encoding issues
SELECT encode(encrypted_field, 'hex') FROM your_table LIMIT 1;
```

#### Issue: Performance Degradation
```sql
-- Analyze query plans
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM table_name 
WHERE pgp_sym_decrypt(encrypted_field, 'key') = 'value';

-- Consider functional indexes
CREATE INDEX idx_functional ON table_name (pgp_sym_decrypt(encrypted_field, 'key'));
```

### Recovery Procedures

#### SSL Certificate Recovery
```bash
# If certificates are lost, regenerate
cd /opt/postgres-ssl
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr
openssl x509 -req -in server.csr -signkey server.key -out server.crt -days 365

# Update container
docker cp server.crt your-postgres-container:/var/lib/postgresql/data/
docker cp server.key your-postgres-container:/var/lib/postgresql/data/
docker restart your-postgres-container
```

#### Data Recovery from Encrypted Backup
```bash
# Decrypt and restore backup
gpg --decrypt /backup/postgres/backup_20231201_020000.sql.gpg > /tmp/restore.sql
docker exec -i your-postgres-container psql -U postgres < /tmp/restore.sql
rm /tmp/restore.sql  # Clean up
```

## Security Best Practices

### 1. Key Management
- Use different keys for different data types
- Rotate encryption keys regularly
- Store keys securely (AWS KMS, HashiCorp Vault)
- Never hardcode keys in application code

### 2. Access Control
- Limit database user privileges
- Use connection pooling with SSL
- Implement application-level access controls
- Regular security audits

### 3. Monitoring
- Monitor failed SSL connections
- Track encryption/decryption operations
- Set up alerts for certificate expiration
- Regular backup testing

## Conclusion

This guide provides comprehensive encryption implementation for your existing PostgreSQL database. Start with SSL/TLS encryption for immediate security benefits, then gradually implement encryption at rest and application-level encryption based on your specific requirements.

Remember to:
- Always test in a non-production environment first
- Maintain regular backups
- Monitor performance impacts
- Keep certificates and keys secure
- Document your encryption strategy for your team

For additional support or questions, refer to the PostgreSQL documentation or consult with your security team.
