"""
Flask server for User Service
Provides REST API endpoints for Docker container deployment
"""
from flask import Flask, request, jsonify
from flask_cors import CORS
import logging
import json
from main import UserService

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Create Flask app
app = Flask(__name__)
CORS(app)  # Enable CORS for frontend access

# Initialize user service
user_service = UserService()

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'user',
        'timestamp': user_service.get_current_time()
    }), 200

@app.route('/users', methods=['GET'])
def get_users():
    """Get all users"""
    try:
        result = user_service.get_users()
        
        if result['statusCode'] == 200:
            body = json.loads(result['body']) if isinstance(result['body'], str) else result['body']
            return jsonify(body), 200
        else:
            body = json.loads(result['body']) if isinstance(result['body'], str) else result['body']
            return jsonify(body), result['statusCode']
    except Exception as e:
        logger.error(f"Error getting users: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/users', methods=['POST'])
def create_user():
    """Create a new user"""
    try:
        data = request.get_json() or {}
        result = user_service.create_user(data)
        
        if result['statusCode'] == 201:
            return jsonify(result['body'] if isinstance(result['body'], dict) else eval(result['body'])), 201
        else:
            return jsonify(result['body'] if isinstance(result['body'], dict) else eval(result['body'])), result['statusCode']
    except Exception as e:
        logger.error(f"Error creating user: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/users/<user_id>', methods=['GET'])
def get_user(user_id):
    """Get a specific user"""
    try:
        result = user_service.get_user(user_id)
        
        if result['statusCode'] == 200:
            body = json.loads(result['body']) if isinstance(result['body'], str) else result['body']
            return jsonify(body), 200
        else:
            body = json.loads(result['body']) if isinstance(result['body'], str) else result['body']
            return jsonify(body), result['statusCode']
    except Exception as e:
        logger.error(f"Error getting user: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/users/<user_id>', methods=['PUT'])
def update_user(user_id):
    """Update a user"""
    try:
        data = request.get_json() or {}
        result = user_service.update_user(user_id, data)
        
        if result['statusCode'] == 200:
            body = json.loads(result['body']) if isinstance(result['body'], str) else result['body']
            return jsonify(body), 200
        else:
            body = json.loads(result['body']) if isinstance(result['body'], str) else result['body']
            return jsonify(body), result['statusCode']
    except Exception as e:
        logger.error(f"Error updating user: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/users/<user_id>', methods=['DELETE'])
def delete_user(user_id):
    """Delete a user"""
    try:
        result = user_service.delete_user(user_id)
        
        if result['statusCode'] == 200:
            body = json.loads(result['body']) if isinstance(result['body'], str) else result['body']
            return jsonify(body), 200
        else:
            body = json.loads(result['body']) if isinstance(result['body'], str) else result['body']
            return jsonify(body), result['statusCode']
    except Exception as e:
        logger.error(f"Error deleting user: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Endpoint not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Internal server error'}), 500

if __name__ == '__main__':
    # Run the Flask development server
    app.run(host='0.0.0.0', port=8080, debug=False)
