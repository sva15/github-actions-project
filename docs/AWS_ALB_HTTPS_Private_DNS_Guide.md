# AWS Internal ALB HTTPS with Private DNS Implementation Guide

## Overview
This guide provides step-by-step instructions for enabling HTTPS on your internal AWS Application Load Balancer (ALB) using private DNS and SSL certificates. This setup ensures encrypted traffic for your Angular application while maintaining private network access within your VPC.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Architecture Overview](#architecture-overview)
3. [Private Certificate Authority Setup](#private-certificate-authority-setup)
4. [Route 53 Private Hosted Zone](#route-53-private-hosted-zone)
5. [SSL Certificate Management](#ssl-certificate-management)
6. [ALB HTTPS Configuration](#alb-https-configuration)
7. [Security Groups Configuration](#security-groups-configuration)
8. [Client Configuration](#client-configuration)
9. [Testing & Validation](#testing--validation)
10. [Monitoring & Maintenance](#monitoring--maintenance)
11. [Troubleshooting](#troubleshooting)

## Prerequisites

### AWS Resources Required
- Existing internal ALB with HTTP listener
- VPC with private subnets
- EC2 instances running Angular application
- AWS CLI configured with appropriate permissions
- Route 53 access for private hosted zones

### Required AWS Permissions
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "acm:*",
                "acm-pca:*",
                "route53:*",
                "elasticloadbalancing:*",
                "ec2:*"
            ],
            "Resource": "*"
        }
    ]
}
```

## Architecture Overview

### Current Architecture
```
Internet Gateway (Private VPC)
    ↓
Internal ALB (HTTP:80)
    ↓
Target Group
    ↓
EC2 Instances (Angular App)
```

### Target Architecture
```
Internet Gateway (Private VPC)
    ↓
Internal ALB (HTTPS:443 + HTTP:80→HTTPS redirect)
    ↓ (SSL Termination)
Target Group
    ↓
EC2 Instances (Angular App)
```

## Private Certificate Authority Setup

### 1. Create Private Certificate Authority

#### AWS Certificate Manager Private CA
```bash
# Create CA configuration file
cat > ca-config.json << 'EOF'
{
    "KeyAlgorithm": "RSA_2048",
    "SigningAlgorithm": "SHA256WITHRSA",
    "Subject": {
        "Country": "US",
        "Organization": "Your Company",
        "OrganizationalUnit": "IT Department",
        "State": "Your State",
        "CommonName": "Your Company Private CA",
        "Locality": "Your City"
    }
}
EOF

# Create the Private CA
aws acm-pca create-certificate-authority \
    --certificate-authority-configuration file://ca-config.json \
    --certificate-authority-type "ROOT" \
    --tags Key=Name,Value=CompanyPrivateCA \
    --region us-east-1

# Get the CA ARN
CA_ARN=$(aws acm-pca list-certificate-authorities --query 'CertificateAuthorities[0].Arn' --output text)
echo "CA ARN: $CA_ARN"
```

### 2. Install CA Certificate
```bash
# Get CA certificate
aws acm-pca get-certificate-authority-certificate \
    --certificate-authority-arn $CA_ARN \
    --output text \
    --query Certificate > ca-certificate.pem

# Get CA CSR for self-signing
aws acm-pca get-certificate-authority-csr \
    --certificate-authority-arn $CA_ARN \
    --output text > ca.csr

# Issue CA certificate (self-signed)
aws acm-pca issue-certificate \
    --certificate-authority-arn $CA_ARN \
    --csr fileb://ca.csr \
    --signing-algorithm "SHA256WITHRSA" \
    --template-arn arn:aws:acm-pca:::template/RootCACertificate/V1 \
    --validity Value=10,Type=YEARS

# Import the CA certificate
CERT_ARN=$(aws acm-pca list-certificates --certificate-authority-arn $CA_ARN --query 'Certificates[0].CertificateArn' --output text)
aws acm-pca get-certificate \
    --certificate-authority-arn $CA_ARN \
    --certificate-arn $CERT_ARN \
    --output text \
    --query Certificate > ca-cert.pem

aws acm-pca import-certificate-authority-certificate \
    --certificate-authority-arn $CA_ARN \
    --certificate fileb://ca-cert.pem
```

## Route 53 Private Hosted Zone

### 1. Create Private Hosted Zone
```bash
# Create private hosted zone
aws route53 create-hosted-zone \
    --name internal.company.com \
    --vpc VPCRegion=us-east-1,VPCId=vpc-xxxxxxxxx \
    --caller-reference $(date +%s) \
    --hosted-zone-config Comment="Private zone for internal applications",PrivateZone=true

# Get hosted zone ID
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name internal.company.com --query 'HostedZones[0].Id' --output text | cut -d'/' -f3)
echo "Hosted Zone ID: $HOSTED_ZONE_ID"
```

### 2. Create DNS Records
```bash
# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers --names your-internal-alb --query 'LoadBalancers[0].DNSName' --output text)
ALB_ZONE_ID=$(aws elbv2 describe-load-balancers --names your-internal-alb --query 'LoadBalancers[0].CanonicalHostedZoneId' --output text)

# Create change batch file
cat > dns-record-change.json << EOF
{
    "Changes": [
        {
            "Action": "CREATE",
            "ResourceRecordSet": {
                "Name": "app.internal.company.com",
                "Type": "A",
                "AliasTarget": {
                    "DNSName": "$ALB_DNS",
                    "EvaluateTargetHealth": false,
                    "HostedZoneId": "$ALB_ZONE_ID"
                }
            }
        }
    ]
}
EOF

# Create DNS record
aws route53 change-resource-record-sets \
    --hosted-zone-id $HOSTED_ZONE_ID \
    --change-batch file://dns-record-change.json
```

## SSL Certificate Management

### 1. Request Certificate from Private CA
```bash
# Request certificate for your domain
aws acm request-certificate \
    --domain-name app.internal.company.com \
    --certificate-authority-arn $CA_ARN \
    --domain-validation-options DomainName=app.internal.company.com,ValidationDomain=internal.company.com \
    --subject-alternative-names "*.internal.company.com" \
    --key-algorithm RSA_2048

# Get certificate ARN
SSL_CERT_ARN=$(aws acm list-certificates --query 'CertificateSummaryList[?DomainName==`app.internal.company.com`].CertificateArn' --output text)
echo "SSL Certificate ARN: $SSL_CERT_ARN"

# Check certificate status
aws acm describe-certificate --certificate-arn $SSL_CERT_ARN --query 'Certificate.Status' --output text
```

## ALB HTTPS Configuration

### 1. Get Current ALB Configuration
```bash
# Get ALB ARN
ALB_ARN=$(aws elbv2 describe-load-balancers --names your-internal-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text)

# Get target group ARN
TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups --names your-target-group --query 'TargetGroups[0].TargetGroupArn' --output text)
```

### 2. Create HTTPS Listener
```bash
# Create HTTPS listener (port 443)
aws elbv2 create-listener \
    --load-balancer-arn $ALB_ARN \
    --protocol HTTPS \
    --port 443 \
    --certificates CertificateArn=$SSL_CERT_ARN \
    --ssl-policy ELBSecurityPolicy-TLS-1-2-2019-07 \
    --default-actions Type=forward,TargetGroupArn=$TARGET_GROUP_ARN

# Get HTTPS listener ARN
HTTPS_LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn $ALB_ARN --query 'Listeners[?Port==`443`].ListenerArn' --output text)
```

### 3. Configure HTTP to HTTPS Redirect
```bash
# Get HTTP listener ARN
HTTP_LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn $ALB_ARN --query 'Listeners[?Port==`80`].ListenerArn' --output text)

# Modify HTTP listener to redirect to HTTPS
aws elbv2 modify-listener \
    --listener-arn $HTTP_LISTENER_ARN \
    --default-actions Type=redirect,RedirectConfig='{Protocol=HTTPS,Port=443,StatusCode=HTTP_301}'
```

## Security Groups Configuration

### 1. Update ALB Security Group
```bash
# Get ALB security group ID
ALB_SG_ID=$(aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN --query 'LoadBalancers[0].SecurityGroups[0]' --output text)

# Add HTTPS inbound rule for VPC CIDR
aws ec2 authorize-security-group-ingress \
    --group-id $ALB_SG_ID \
    --protocol tcp \
    --port 443 \
    --cidr 10.0.0.0/16
```

### 2. Update EC2 Security Group
```bash
# Get EC2 security group ID
EC2_SG_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=your-angular-app" --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' --output text)

# Ensure ALB can reach EC2 instances on HTTP port
aws ec2 authorize-security-group-ingress \
    --group-id $EC2_SG_ID \
    --protocol tcp \
    --port 80 \
    --source-group $ALB_SG_ID
```

## Client Configuration

### 1. Distribute CA Certificate
```bash
# Create distribution package
mkdir -p /tmp/ca-distribution
cp ca-certificate.pem /tmp/ca-distribution/

# Create Linux installation script
cat > /tmp/ca-distribution/install-ca.sh << 'EOF'
#!/bin/bash
sudo cp ca-certificate.pem /usr/local/share/ca-certificates/company-ca.crt
sudo update-ca-certificates
echo "CA certificate installed successfully"
EOF

chmod +x /tmp/ca-distribution/install-ca.sh

# Create Windows installation script
cat > /tmp/ca-distribution/install-ca.bat << 'EOF'
@echo off
certutil -addstore -f "Root" ca-certificate.pem
echo CA certificate installed successfully
pause
EOF
```

### 2. Update Application Configuration
```bash
# Update Angular environment files
cat > environment.prod.ts << 'EOF'
export const environment = {
  production: true,
  apiUrl: 'https://app.internal.company.com/api',
};
EOF

# Update hardcoded HTTP URLs
find ./src -name "*.ts" -exec sed -i 's/http:\/\/app\.internal\.company\.com/https:\/\/app\.internal\.company\.com/g' {} \;
```

## Testing & Validation

### 1. DNS Resolution Testing
```bash
# Test DNS resolution from within VPC
nslookup app.internal.company.com
dig app.internal.company.com
```

### 2. SSL Certificate Testing
```bash
# Test SSL connection
openssl s_client -connect app.internal.company.com:443 -servername app.internal.company.com

# Check certificate details
openssl s_client -connect app.internal.company.com:443 -servername app.internal.company.com 2>/dev/null | openssl x509 -noout -text

# Test with curl
curl -v https://app.internal.company.com
```

### 3. Load Balancer Testing
```bash
# Check ALB target health
aws elbv2 describe-target-health --target-group-arn $TARGET_GROUP_ARN

# Test endpoints
curl -I https://app.internal.company.com
curl -I http://app.internal.company.com  # Should redirect to HTTPS
```

## Monitoring & Maintenance

### 1. Certificate Expiration Monitoring
```bash
# Create monitoring script
cat > check-cert-expiry.sh << 'EOF'
#!/bin/bash
CERT_EXPIRY=$(echo | openssl s_client -servername app.internal.company.com -connect app.internal.company.com:443 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2)
EXPIRY_EPOCH=$(date -d "$CERT_EXPIRY" +%s)
CURRENT_EPOCH=$(date +%s)
DAYS_LEFT=$(( (EXPIRY_EPOCH - CURRENT_EPOCH) / 86400 ))

if [ $DAYS_LEFT -lt 30 ]; then
    echo "WARNING: Certificate expires in $DAYS_LEFT days"
    # Send alert
fi
EOF

chmod +x check-cert-expiry.sh
echo "0 6 * * * /path/to/check-cert-expiry.sh" | crontab -
```

### 2. Health Check Monitoring
```bash
# Create health check script
cat > health-check.sh << 'EOF'
#!/bin/bash
ENDPOINT="https://app.internal.company.com/health"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" $ENDPOINT)

if [ "$RESPONSE" = "200" ]; then
    echo "$(date) - SUCCESS: $RESPONSE"
else
    echo "$(date) - FAILURE: $RESPONSE"
    # Send alert
fi
EOF

chmod +x health-check.sh
echo "*/5 * * * * /path/to/health-check.sh" | crontab -
```

## Troubleshooting

### Common Issues

#### 1. Certificate Not Trusted
```bash
# Verify certificate chain
openssl s_client -connect app.internal.company.com:443 -showcerts

# Re-install CA certificate on client
sudo cp ca-certificate.pem /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

#### 2. DNS Resolution Fails
```bash
# Check Route 53 configuration
aws route53 list-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID

# Verify VPC association
aws route53 get-hosted-zone --id $HOSTED_ZONE_ID
```

#### 3. ALB Health Check Failures
```bash
# Check target health
aws elbv2 describe-target-health --target-group-arn $TARGET_GROUP_ARN

# Verify security groups
aws ec2 describe-security-groups --group-ids $ALB_SG_ID $EC2_SG_ID

# Test direct connection
curl -v http://target-ip:80/health
```

#### 4. SSL Handshake Failures
```bash
# Test SSL configuration
openssl s_client -connect app.internal.company.com:443 -tls1_2

# Check SSL policy
aws elbv2 describe-listeners --listener-arns $HTTPS_LISTENER_ARN --query 'Listeners[0].SslPolicy'

# Update SSL policy if needed
aws elbv2 modify-listener \
    --listener-arn $HTTPS_LISTENER_ARN \
    --ssl-policy ELBSecurityPolicy-TLS-1-2-2019-07
```

## Implementation Checklist

### Pre-Implementation
- [ ] Backup current ALB configuration
- [ ] Document current application URLs
- [ ] Plan maintenance window
- [ ] Prepare rollback procedures

### Implementation Steps
- [ ] Create Private CA
- [ ] Set up Route 53 private hosted zone
- [ ] Request SSL certificate
- [ ] Configure ALB HTTPS listener
- [ ] Update security groups
- [ ] Configure HTTP to HTTPS redirect
- [ ] Distribute CA certificates to clients
- [ ] Update application configuration

### Post-Implementation
- [ ] Test DNS resolution
- [ ] Verify SSL certificate
- [ ] Test application functionality
- [ ] Set up monitoring
- [ ] Document new configuration
- [ ] Train team on new setup

## Security Best Practices

1. **Certificate Management**
   - Use strong key lengths (2048-bit minimum)
   - Rotate certificates regularly
   - Monitor certificate expiration

2. **Network Security**
   - Use least privilege security groups
   - Enable VPC Flow Logs
   - Regular security audits

3. **Access Control**
   - Limit CA certificate distribution
   - Use IAM roles for AWS resources
   - Regular access reviews

This guide provides a complete implementation path for securing your internal ALB with HTTPS and private DNS. Follow the steps sequentially and test thoroughly at each stage.
