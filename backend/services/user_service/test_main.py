"""
Unit tests for User Service
"""
import pytest
import json
import uuid
from unittest.mock import patch, MagicMock
from main import UserService, lambda_handler, gcp_handler

class TestUserService:
    
    def setup_method(self):
        """Setup test fixtures before each test method."""
        self.user_service = UserService()
        self.test_user_data = {
            'name': 'John Doe',
            'email': 'john@example.com'
        }
    
    def test_create_user_success(self):
        """Test successful user creation"""
        result = self.user_service.create_user(self.test_user_data)
        
        assert result['statusCode'] == 200
        body = json.loads(result['body'])
        assert body['message'] == 'User created successfully'
        assert 'user' in body
        assert body['user']['name'] == 'John Doe'
        assert body['user']['email'] == 'john@example.com'
        assert 'id' in body['user']
        assert 'created_at' in body['user']
        assert 'updated_at' in body['user']
    
    def test_create_user_missing_name(self):
        """Test user creation with missing name"""
        invalid_data = {'email': 'john@example.com'}
        result = self.user_service.create_user(invalid_data)
        
        assert result['statusCode'] == 400
        body = json.loads(result['body'])
        assert 'error' in body
        assert 'Name and email are required' in body['error']
    
    def test_create_user_missing_email(self):
        """Test user creation with missing email"""
        invalid_data = {'name': 'John Doe'}
        result = self.user_service.create_user(invalid_data)
        
        assert result['statusCode'] == 400
        body = json.loads(result['body'])
        assert 'error' in body
        assert 'Name and email are required' in body['error']
    
    def test_get_user_success(self):
        """Test successful user retrieval"""
        # First create a user
        create_result = self.user_service.create_user(self.test_user_data)
        user_data = json.loads(create_result['body'])
        user_id = user_data['user']['id']
        
        # Then retrieve the user
        result = self.user_service.get_user(user_id)
        
        assert result['statusCode'] == 200
        body = json.loads(result['body'])
        assert 'user' in body
        assert body['user']['id'] == user_id
        assert body['user']['name'] == 'John Doe'
        assert body['user']['email'] == 'john@example.com'
    
    def test_get_user_not_found(self):
        """Test user retrieval with non-existent user ID"""
        fake_user_id = str(uuid.uuid4())
        result = self.user_service.get_user(fake_user_id)
        
        assert result['statusCode'] == 404
        body = json.loads(result['body'])
        assert 'error' in body
        assert body['error'] == 'User not found'
    
    def test_update_user_success(self):
        """Test successful user update"""
        # First create a user
        create_result = self.user_service.create_user(self.test_user_data)
        user_data = json.loads(create_result['body'])
        user_id = user_data['user']['id']
        
        # Update the user
        update_data = {'name': 'John Smith', 'email': 'johnsmith@example.com'}
        result = self.user_service.update_user(user_id, update_data)
        
        assert result['statusCode'] == 200
        body = json.loads(result['body'])
        assert body['message'] == 'User updated successfully'
        assert body['user']['name'] == 'John Smith'
        assert body['user']['email'] == 'johnsmith@example.com'
        assert body['user']['id'] == user_id
    
    def test_update_user_not_found(self):
        """Test user update with non-existent user ID"""
        fake_user_id = str(uuid.uuid4())
        update_data = {'name': 'John Smith'}
        result = self.user_service.update_user(fake_user_id, update_data)
        
        assert result['statusCode'] == 404
        body = json.loads(result['body'])
        assert 'error' in body
        assert body['error'] == 'User not found'
    
    def test_update_user_partial(self):
        """Test partial user update (only name)"""
        # First create a user
        create_result = self.user_service.create_user(self.test_user_data)
        user_data = json.loads(create_result['body'])
        user_id = user_data['user']['id']
        original_email = user_data['user']['email']
        
        # Update only the name
        update_data = {'name': 'John Smith'}
        result = self.user_service.update_user(user_id, update_data)
        
        assert result['statusCode'] == 200
        body = json.loads(result['body'])
        assert body['user']['name'] == 'John Smith'
        assert body['user']['email'] == original_email  # Should remain unchanged


class TestLambdaHandler:
    
    def setup_method(self):
        """Setup test fixtures before each test method."""
        self.test_user_data = {
            'name': 'Jane Doe',
            'email': 'jane@example.com'
        }
    
    def test_lambda_create_user(self):
        """Test Lambda handler for user creation"""
        event = {
            'httpMethod': 'POST',
            'body': json.dumps(self.test_user_data)
        }
        context = {}
        
        result = lambda_handler(event, context)
        
        assert result['statusCode'] == 200
        body = json.loads(result['body'])
        assert body['message'] == 'User created successfully'
        assert 'user' in body
    
    def test_lambda_get_user(self):
        """Test Lambda handler for user retrieval"""
        # First create a user to get a valid ID
        create_event = {
            'httpMethod': 'POST',
            'body': json.dumps(self.test_user_data)
        }
        create_result = lambda_handler(create_event, {})
        user_data = json.loads(create_result['body'])
        user_id = user_data['user']['id']
        
        # Then test retrieval
        get_event = {
            'httpMethod': 'GET',
            'pathParameters': {'user_id': user_id}
        }
        
        result = lambda_handler(get_event, {})
        
        assert result['statusCode'] == 200
        body = json.loads(result['body'])
        assert 'user' in body
        assert body['user']['id'] == user_id
    
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
    
    @patch('main.logger')
    def test_lambda_handler_exception(self, mock_logger):
        """Test Lambda handler with malformed event"""
        event = {
            'httpMethod': 'POST',
            'body': 'invalid json'
        }
        context = {}
        
        result = lambda_handler(event, context)
        
        assert result['statusCode'] == 500
        body = json.loads(result['body'])
        assert 'error' in body
        mock_logger.error.assert_called()


class TestGCPHandler:
    
    def setup_method(self):
        """Setup test fixtures before each test method."""
        self.test_user_data = {
            'name': 'Bob Smith',
            'email': 'bob@example.com'
        }
    
    def test_gcp_create_user(self):
        """Test GCP handler for user creation"""
        mock_request = MagicMock()
        mock_request.method = 'POST'
        mock_request.get_json.return_value = self.test_user_data
        
        result, status_code = gcp_handler(mock_request)
        
        assert status_code == 200
        assert result['message'] == 'User created successfully'
        assert 'user' in result
    
    def test_gcp_get_user(self):
        """Test GCP handler for user retrieval"""
        # First create a user
        create_request = MagicMock()
        create_request.method = 'POST'
        create_request.get_json.return_value = self.test_user_data
        
        create_result, _ = gcp_handler(create_request)
        user_id = create_result['user']['id']
        
        # Then test retrieval
        get_request = MagicMock()
        get_request.method = 'GET'
        get_request.args.get.return_value = user_id
        
        result, status_code = gcp_handler(get_request)
        
        assert status_code == 200
        assert 'user' in result
        assert result['user']['id'] == user_id
    
    def test_gcp_method_not_allowed(self):
        """Test GCP handler with unsupported method"""
        mock_request = MagicMock()
        mock_request.method = 'DELETE'
        
        result, status_code = gcp_handler(mock_request)
        
        assert status_code == 405
        assert 'error' in result
        assert result['error'] == 'Method not allowed'
    
    def test_gcp_missing_user_id(self):
        """Test GCP handler GET request without user_id"""
        mock_request = MagicMock()
        mock_request.method = 'GET'
        mock_request.args.get.return_value = None
        
        result, status_code = gcp_handler(mock_request)
        
        assert status_code == 400
        assert 'error' in result
        assert 'user_id parameter required' in result['error']


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
