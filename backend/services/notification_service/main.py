"""
Notification Service - Handles email and SMS notifications
Deployable to GCP Cloud Functions and AWS Lambda
"""
import json
import logging
from typing import Dict, Any, List
from datetime import datetime
import uuid
from enum import Enum

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class NotificationType(Enum):
    EMAIL = "email"
    SMS = "sms"
    PUSH = "push"

class NotificationStatus(Enum):
    PENDING = "pending"
    SENT = "sent"
    FAILED = "failed"

class NotificationService:
    def __init__(self):
        # In a real application, this would connect to a database
        self.notifications = {}
        self._initialize_templates()
        self._initialize_sample_data()
    
    def get_current_time(self) -> str:
        """Get current timestamp"""
        return datetime.utcnow().isoformat()
    
    def _initialize_templates(self):
        """Initialize notification templates"""
        self.templates = {
            'welcome': {
                'subject': 'Welcome to our platform!',
                'body': 'Hello {name}, welcome to our amazing platform!'
            },
            'password_reset': {
                'subject': 'Password Reset Request',
                'body': 'Hello {name}, click here to reset your password: {reset_link}'
            },
            'order_confirmation': {
                'subject': 'Order Confirmation',
                'body': 'Hello {name}, your order #{order_id} has been confirmed!'
            }
        }
    
    def _initialize_sample_data(self):
        """Initialize with sample notifications for demo"""
        sample_notifications = [
            {
                'id': '1',
                'recipient': 'john.doe@cloudsync.com',
                'type': 'email',
                'template': 'welcome',
                'subject': 'Welcome to CloudSync Platform!',
                'message': 'Hello John Doe, welcome to our amazing platform!',
                'status': 'sent',
                'created_at': '2024-02-01T10:00:00Z',
                'sent_at': '2024-02-01T10:01:00Z'
            },
            {
                'id': '2',
                'recipient': 'jane.smith@cloudsync.com',
                'type': 'email',
                'template': 'password_reset',
                'subject': 'Password Reset Request',
                'message': 'Hello Jane Smith, click here to reset your password: https://cloudsync.com/reset/abc123',
                'status': 'sent',
                'created_at': '2024-02-01T14:30:00Z',
                'sent_at': '2024-02-01T14:31:00Z'
            },
            {
                'id': '3',
                'recipient': 'mike.johnson@cloudsync.com',
                'type': 'email',
                'template': 'order_confirmation',
                'subject': 'Order Confirmation',
                'message': 'Hello Mike Johnson, your order #12345 has been confirmed!',
                'status': 'pending',
                'created_at': '2024-02-01T16:45:00Z'
            }
        ]
        
        for notification in sample_notifications:
            self.notifications[notification['id']] = notification
    
    def send_notification(self, notification_data: Dict[str, Any]) -> Dict[str, Any]:
        """Send a notification"""
        try:
            notification_id = str(uuid.uuid4())
            
            # Validate required fields
            required_fields = ['recipient', 'type', 'template']
            for field in required_fields:
                if field not in notification_data:
                    raise ValueError(f"Missing required field: {field}")
            
            # Validate notification type
            notification_type = notification_data['type']
            if notification_type not in [t.value for t in NotificationType]:
                raise ValueError(f"Invalid notification type: {notification_type}")
            
            # Get template
            template_name = notification_data['template']
            if template_name not in self.templates:
                raise ValueError(f"Template not found: {template_name}")
            
            template = self.templates[template_name]
            variables = notification_data.get('variables', {})
            
            # Format message
            subject = template['subject'].format(**variables)
            body = template['body'].format(**variables)
            
            notification = {
                'id': notification_id,
                'recipient': notification_data['recipient'],
                'type': notification_type,
                'template': template_name,
                'subject': subject,
                'body': body,
                'status': NotificationStatus.PENDING.value,
                'created_at': datetime.utcnow().isoformat(),
                'sent_at': None,
                'error_message': None
            }
            
            # Simulate sending (in real app, integrate with email/SMS providers)
            success = self._simulate_send(notification)
            
            if success:
                notification['status'] = NotificationStatus.SENT.value
                notification['sent_at'] = datetime.utcnow().isoformat()
                logger.info(f"Notification sent successfully: {notification_id}")
            else:
                notification['status'] = NotificationStatus.FAILED.value
                notification['error_message'] = "Failed to send notification"
                logger.error(f"Failed to send notification: {notification_id}")
            
            self.notifications[notification_id] = notification
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Notification processed',
                    'notification': notification
                })
            }
        except Exception as e:
            logger.error(f"Error sending notification: {str(e)}")
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'error': str(e)
                })
            }
    
    def get_notification_status(self, notification_id: str) -> Dict[str, Any]:
        """Get notification status"""
        try:
            if notification_id not in self.notifications:
                return {
                    'statusCode': 404,
                    'body': json.dumps({
                        'error': 'Notification not found'
                    })
                }
            
            notification = self.notifications[notification_id]
            logger.info(f"Notification status retrieved: {notification_id}")
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'notification': notification
                })
            }
        except Exception as e:
            logger.error(f"Error retrieving notification status: {str(e)}")
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'error': str(e)
                })
            }
    
    def get_notifications_by_recipient(self, recipient: str) -> Dict[str, Any]:
        """Get all notifications for a recipient"""
        try:
            recipient_notifications = [
                notification for notification in self.notifications.values()
                if notification['recipient'] == recipient
            ]
            
            logger.info(f"Retrieved {len(recipient_notifications)} notifications for recipient: {recipient}")
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'notifications': recipient_notifications,
                    'count': len(recipient_notifications)
                })
            }
        except Exception as e:
            logger.error(f"Error retrieving notifications for recipient: {str(e)}")
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'error': str(e)
                })
            }
    
    def _simulate_send(self, notification: Dict[str, Any]) -> bool:
        """Simulate sending notification (replace with real implementation)"""
        # In a real application, integrate with:
        # - Email: SendGrid, AWS SES, etc.
        # - SMS: Twilio, AWS SNS, etc.
        # - Push: Firebase, AWS SNS, etc.
        
        notification_type = notification['type']
        recipient = notification['recipient']
        
        logger.info(f"Simulating {notification_type} notification to {recipient}")
        logger.info(f"Subject: {notification['subject']}")
        logger.info(f"Body: {notification['body']}")
        
        # Simulate 90% success rate
        import random
        return random.random() > 0.1

# Initialize service
notification_service = NotificationService()

# AWS Lambda handler
def lambda_handler(event, context):
    """AWS Lambda entry point"""
    try:
        http_method = event.get('httpMethod', 'GET')
        path_parameters = event.get('pathParameters') or {}
        query_parameters = event.get('queryStringParameters') or {}
        body = event.get('body')
        
        if body:
            body = json.loads(body)
        
        notification_id = path_parameters.get('notification_id')
        recipient = query_parameters.get('recipient')
        
        if http_method == 'POST':
            return notification_service.send_notification(body or {})
        elif http_method == 'GET' and notification_id:
            return notification_service.get_notification_status(notification_id)
        elif http_method == 'GET' and recipient:
            return notification_service.get_notifications_by_recipient(recipient)
        else:
            return {
                'statusCode': 405,
                'body': json.dumps({
                    'error': 'Method not allowed'
                })
            }
    except Exception as e:
        logger.error(f"Lambda handler error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Internal server error'
            })
        }

# GCP Cloud Function handler
def gcp_handler(request):
    """GCP Cloud Function entry point"""
    try:
        if request.method == 'POST':
            data = request.get_json() or {}
            result = notification_service.send_notification(data)
        elif request.method == 'GET':
            notification_id = request.args.get('notification_id')
            recipient = request.args.get('recipient')
            
            if notification_id:
                result = notification_service.get_notification_status(notification_id)
            elif recipient:
                result = notification_service.get_notifications_by_recipient(recipient)
            else:
                return {'error': 'notification_id or recipient parameter required'}, 400
        else:
            return {'error': 'Method not allowed'}, 405
        
        return json.loads(result['body']), result['statusCode']
    except Exception as e:
        logger.error(f"GCP handler error: {str(e)}")
        return {'error': 'Internal server error'}, 500

if __name__ == "__main__":
    # For local testing
    test_notification = {
        'recipient': 'john@example.com',
        'type': 'email',
        'template': 'welcome',
        'variables': {
            'name': 'John Doe'
        }
    }
    
    # Test send notification
    result = notification_service.send_notification(test_notification)
    print("Send Notification Result:", result)
    
    # Extract notification ID from response
    if result['statusCode'] == 200:
        notification_data = json.loads(result['body'])
        notification_id = notification_data['notification']['id']
        
        # Test get notification status
        status_result = notification_service.get_notification_status(notification_id)
        print("Get Notification Status Result:", status_result)
        
        # Test get notifications by recipient
        recipient_result = notification_service.get_notifications_by_recipient('john@example.com')
        print("Get Notifications by Recipient Result:", recipient_result)
