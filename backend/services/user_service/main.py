"""
User Service - Handles user management operations
Deployable to GCP Cloud Functions and AWS Lambda
"""
import json
import logging
from typing import Dict, Any, Optional
from datetime import datetime
import uuid

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class UserService:
    def __init__(self):
        # In a real application, this would connect to a database
        self.users = {}
    
    def get_current_time(self) -> str:
        """Get current timestamp"""
        return datetime.utcnow().isoformat()
    
    def create_user(self, user_data: Dict[str, Any]) -> Dict[str, Any]:
        """Create a new user"""
        try:
            user_id = str(uuid.uuid4())
            user = {
                'id': user_id,
                'name': user_data.get('name'),
                'email': user_data.get('email'),
                'created_at': datetime.utcnow().isoformat(),
                'updated_at': datetime.utcnow().isoformat()
            }
            
            # Validate required fields
            if not user['name'] or not user['email']:
                raise ValueError("Name and email are required")
            
            self.users[user_id] = user
            logger.info(f"User created successfully: {user_id}")
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'User created successfully',
                    'user': user
                })
            }
        except Exception as e:
            logger.error(f"Error creating user: {str(e)}")
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'error': str(e)
                })
            }
    
    def get_user(self, user_id: str) -> Dict[str, Any]:
        """Get user by ID"""
        try:
            if user_id not in self.users:
                return {
                    'statusCode': 404,
                    'body': json.dumps({
                        'error': 'User not found'
                    })
                }
            
            user = self.users[user_id]
            logger.info(f"User retrieved successfully: {user_id}")
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'user': user
                })
            }
        except Exception as e:
            logger.error(f"Error retrieving user: {str(e)}")
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'error': str(e)
                })
            }
    
    def update_user(self, user_id: str, update_data: Dict[str, Any]) -> Dict[str, Any]:
        """Update user information"""
        try:
            if user_id not in self.users:
                return {
                    'statusCode': 404,
                    'body': json.dumps({
                        'error': 'User not found'
                    })
                }
            
            user = self.users[user_id]
            user.update({
                'name': update_data.get('name', user['name']),
                'email': update_data.get('email', user['email']),
                'updated_at': datetime.utcnow().isoformat()
            })
            
            self.users[user_id] = user
            logger.info(f"User updated successfully: {user_id}")
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'User updated successfully',
                    'user': user
                })
            }
        except Exception as e:
            logger.error(f"Error updating user: {str(e)}")
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'error': str(e)
                })
            }

# Initialize service
user_service = UserService()

# AWS Lambda handler
def lambda_handler(event, context):
    """AWS Lambda entry point"""
    try:
        http_method = event.get('httpMethod', 'GET')
        path_parameters = event.get('pathParameters') or {}
        body = event.get('body')
        
        if body:
            body = json.loads(body)
        
        user_id = path_parameters.get('user_id')
        
        if http_method == 'POST':
            return user_service.create_user(body or {})
        elif http_method == 'GET' and user_id:
            return user_service.get_user(user_id)
        elif http_method == 'PUT' and user_id:
            return user_service.update_user(user_id, body or {})
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
            result = user_service.create_user(data)
        elif request.method == 'GET':
            user_id = request.args.get('user_id')
            if not user_id:
                return {'error': 'user_id parameter required'}, 400
            result = user_service.get_user(user_id)
        elif request.method == 'PUT':
            user_id = request.args.get('user_id')
            data = request.get_json() or {}
            if not user_id:
                return {'error': 'user_id parameter required'}, 400
            result = user_service.update_user(user_id, data)
        else:
            return {'error': 'Method not allowed'}, 405
        
        return json.loads(result['body']), result['statusCode']
    except Exception as e:
        logger.error(f"GCP handler error: {str(e)}")
        return {'error': 'Internal server error'}, 500

if __name__ == "__main__":
    # For local testing
    test_user = {
        'name': 'John Doe',
        'email': 'john@example.com'
    }
    
    # Test create user
    result = user_service.create_user(test_user)
    print("Create User Result:", result)
    
    # Extract user ID from response
    if result['statusCode'] == 200:
        user_data = json.loads(result['body'])
        user_id = user_data['user']['id']
        
        # Test get user
        get_result = user_service.get_user(user_id)
        print("Get User Result:", get_result)
        
        # Test update user
        update_data = {'name': 'John Smith'}
        update_result = user_service.update_user(user_id, update_data)
        print("Update User Result:", update_result)
