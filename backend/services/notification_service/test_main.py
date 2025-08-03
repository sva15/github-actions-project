"""
Unit tests for Notification Service
"""
import pytest
import json
import uuid
from unittest.mock import patch, MagicMock
from main import NotificationService, lambda_handler, gcp_handler, NotificationType, NotificationStatus

class TestNotificationService:
    
    def setup_method(self):
        """Setup test fixtures before each test method."""
        self.notification_service = NotificationService()
        self.test_notification_data = {
            'recipient': 'test@example.com',
            'type': 'email',
            'template': 'welcome',
            'variables': {
                'name': 'Test User'
            }
        }
    
    def test_send_notification_success(self):
        """Test successful notification sending"""
        with patch.object(self.notification_service, '_simulate_send', return_value=True):
            result = self.notification_service.send_notification(self.test_notification_data)
            
            assert result['statusCode'] == 200
            body = json.loads(result['body'])
            assert body['message'] == 'Notification processed'
            assert 'notification' in body
            assert body['notification']['recipient'] == 'test@example.com'
            assert body['notification']['type'] == 'email'
            assert body['notification']['status'] == 'sent'
            assert body['notification']['subject'] == 'Welcome to our platform!'
            assert 'Test User' in body['notification']['body']
    
    def test_send_notification_missing_recipient(self):
        """Test notification sending with missing recipient"""
        invalid_data = {
            'type': 'email',
            'template': 'welcome'
        }
        result = self.notification_service.send_notification(invalid_data)
        
        assert result['statusCode'] == 400
        body = json.loads(result['body'])
        assert 'error' in body
        assert 'Missing required field: recipient' in body['error']
    
    def test_send_notification_invalid_type(self):
        """Test notification sending with invalid type"""
        invalid_data = {
            'recipient': 'test@example.com',
            'type': 'invalid_type',
            'template': 'welcome'
        }
        result = self.notification_service.send_notification(invalid_data)
        
        assert result['statusCode'] == 400
        body = json.loads(result['body'])
        assert 'error' in body
        assert 'Invalid notification type' in body['error']
    
    def test_send_notification_invalid_template(self):
        """Test notification sending with invalid template"""
        invalid_data = {
            'recipient': 'test@example.com',
            'type': 'email',
            'template': 'invalid_template'
        }
        result = self.notification_service.send_notification(invalid_data)
        
        assert result['statusCode'] == 400
        body = json.loads(result['body'])
        assert 'error' in body
        assert 'Template not found' in body['error']
    
    def test_send_notification_failed(self):
        """Test notification sending failure"""
        with patch.object(self.notification_service, '_simulate_send', return_value=False):
            result = self.notification_service.send_notification(self.test_notification_data)
            
            assert result['statusCode'] == 200
            body = json.loads(result['body'])
            assert body['notification']['status'] == 'failed'
            assert body['notification']['error_message'] == 'Failed to send notification'
    
    def test_get_notification_status_success(self):
        """Test successful notification status retrieval"""
        # First send a notification
        with patch.object(self.notification_service, '_simulate_send', return_value=True):
            send_result = self.notification_service.send_notification(self.test_notification_data)
            notification_data = json.loads(send_result['body'])
            notification_id = notification_data['notification']['id']
            
            # Then get the status
            result = self.notification_service.get_notification_status(notification_id)
            
            assert result['statusCode'] == 200
            body = json.loads(result['body'])
            assert 'notification' in body
            assert body['notification']['id'] == notification_id
            assert body['notification']['status'] == 'sent'
    
    def test_get_notification_status_not_found(self):
        """Test notification status retrieval with non-existent ID"""
        fake_notification_id = str(uuid.uuid4())
        result = self.notification_service.get_notification_status(fake_notification_id)
        
        assert result['statusCode'] == 404
        body = json.loads(result['body'])
        assert 'error' in body
        assert body['error'] == 'Notification not found'
    
    def test_get_notifications_by_recipient(self):
        """Test getting notifications by recipient"""
        recipient = 'test@example.com'
        
        # Send multiple notifications
        with patch.object(self.notification_service, '_simulate_send', return_value=True):
            for i in range(3):
                test_data = self.test_notification_data.copy()
                test_data['template'] = ['welcome', 'password_reset', 'order_confirmation'][i]
                self.notification_service.send_notification(test_data)
            
            # Get notifications by recipient
            result = self.notification_service.get_notifications_by_recipient(recipient)
            
            assert result['statusCode'] == 200
            body = json.loads(result['body'])
            assert 'notifications' in body
            assert body['count'] == 3
            assert len(body['notifications']) == 3
            
            # Verify all notifications are for the correct recipient
            for notification in body['notifications']:
                assert notification['recipient'] == recipient
    
    def test_template_formatting(self):
        """Test template variable formatting"""
        test_data = {
            'recipient': 'john@example.com',
            'type': 'email',
            'template': 'password_reset',
            'variables': {
                'name': 'John Doe',
                'reset_link': 'https://example.com/reset/abc123'
            }
        }
        
        with patch.object(self.notification_service, '_simulate_send', return_value=True):
            result = self.notification_service.send_notification(test_data)
            
            assert result['statusCode'] == 200
            body = json.loads(result['body'])
            notification = body['notification']
            
            assert 'John Doe' in notification['body']
            assert 'https://example.com/reset/abc123' in notification['body']
            assert notification['subject'] == 'Password Reset Request'


class TestLambdaHandler:
    
    def setup_method(self):
        """Setup test fixtures before each test method."""
        self.test_notification_data = {
            'recipient': 'lambda@example.com',
            'type': 'email',
            'template': 'welcome',
            'variables': {'name': 'Lambda User'}
        }
    
    def test_lambda_send_notification(self):
        """Test Lambda handler for sending notification"""
        event = {
            'httpMethod': 'POST',
            'body': json.dumps(self.test_notification_data)
        }
        context = {}
        
        with patch('main.notification_service._simulate_send', return_value=True):
            result = lambda_handler(event, context)
            
            assert result['statusCode'] == 200
            body = json.loads(result['body'])
            assert body['message'] == 'Notification processed'
    
    def test_lambda_get_notification_status(self):
        """Test Lambda handler for getting notification status"""
        # First create a notification
        with patch('main.notification_service._simulate_send', return_value=True):
            create_event = {
                'httpMethod': 'POST',
                'body': json.dumps(self.test_notification_data)
            }
            create_result = lambda_handler(create_event, {})
            notification_data = json.loads(create_result['body'])
            notification_id = notification_data['notification']['id']
            
            # Then test retrieval
            get_event = {
                'httpMethod': 'GET',
                'pathParameters': {'notification_id': notification_id}
            }
            
            result = lambda_handler(get_event, {})
            
            assert result['statusCode'] == 200
            body = json.loads(result['body'])
            assert 'notification' in body
    
    def test_lambda_get_notifications_by_recipient(self):
        """Test Lambda handler for getting notifications by recipient"""
        event = {
            'httpMethod': 'GET',
            'queryStringParameters': {'recipient': 'test@example.com'}
        }
        context = {}
        
        result = lambda_handler(event, context)
        
        assert result['statusCode'] == 200
        body = json.loads(result['body'])
        assert 'notifications' in body
    
    def test_lambda_method_not_allowed(self):
        """Test Lambda handler with unsupported method"""
        event = {
            'httpMethod': 'DELETE'
        }
        context = {}
        
        result = lambda_handler(event, context)
        
        assert result['statusCode'] == 405
        body = json.loads(result['body'])
        assert 'error' in body
        assert body['error'] == 'Method not allowed'


class TestGCPHandler:
    
    def setup_method(self):
        """Setup test fixtures before each test method."""
        self.test_notification_data = {
            'recipient': 'gcp@example.com',
            'type': 'email',
            'template': 'welcome',
            'variables': {'name': 'GCP User'}
        }
    
    def test_gcp_send_notification(self):
        """Test GCP handler for sending notification"""
        mock_request = MagicMock()
        mock_request.method = 'POST'
        mock_request.get_json.return_value = self.test_notification_data
        
        with patch('main.notification_service._simulate_send', return_value=True):
            result, status_code = gcp_handler(mock_request)
            
            assert status_code == 200
            assert result['message'] == 'Notification processed'
    
    def test_gcp_get_notification_status(self):
        """Test GCP handler for getting notification status"""
        # First create a notification
        with patch('main.notification_service._simulate_send', return_value=True):
            create_request = MagicMock()
            create_request.method = 'POST'
            create_request.get_json.return_value = self.test_notification_data
            
            create_result, _ = gcp_handler(create_request)
            notification_id = create_result['notification']['id']
            
            # Then test retrieval
            get_request = MagicMock()
            get_request.method = 'GET'
            get_request.args.get.return_value = notification_id
            
            result, status_code = gcp_handler(get_request)
            
            assert status_code == 200
            assert 'notification' in result
    
    def test_gcp_method_not_allowed(self):
        """Test GCP handler with unsupported method"""
        mock_request = MagicMock()
        mock_request.method = 'DELETE'
        
        result, status_code = gcp_handler(mock_request)
        
        assert status_code == 405
        assert 'error' in result
        assert result['error'] == 'Method not allowed'
    
    def test_gcp_missing_notification_id(self):
        """Test GCP handler GET request without notification_id"""
        mock_request = MagicMock()
        mock_request.method = 'GET'
        mock_request.args.get.return_value = None
        
        result, status_code = gcp_handler(mock_request)
        
        assert status_code == 400
        assert 'error' in result


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
