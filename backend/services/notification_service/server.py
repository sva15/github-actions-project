"""
Flask server for Notification Service
Provides REST API endpoints for Docker container deployment
"""
from flask import Flask, request, jsonify
from flask_cors import CORS
import logging
from main import NotificationService

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Create Flask app
app = Flask(__name__)
CORS(app)  # Enable CORS for frontend access

# Initialize notification service
notification_service = NotificationService()

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'notification',
        'timestamp': notification_service.get_current_time()
    }), 200

@app.route('/notifications', methods=['POST'])
def send_notification():
    """Send a notification"""
    try:
        data = request.get_json() or {}
        result = notification_service.send_notification(data)
        
        if result['statusCode'] == 200:
            return jsonify(result['body'] if isinstance(result['body'], dict) else eval(result['body'])), 200
        else:
            return jsonify(result['body'] if isinstance(result['body'], dict) else eval(result['body'])), result['statusCode']
    except Exception as e:
        logger.error(f"Error sending notification: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/notifications', methods=['GET'])
def get_notifications():
    """Get notifications with optional filtering"""
    try:
        filters = dict(request.args)
        result = notification_service.get_notifications(filters)
        
        if result['statusCode'] == 200:
            return jsonify(result['body'] if isinstance(result['body'], dict) else eval(result['body'])), 200
        else:
            return jsonify(result['body'] if isinstance(result['body'], dict) else eval(result['body'])), result['statusCode']
    except Exception as e:
        logger.error(f"Error getting notifications: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/notifications/<notification_id>', methods=['GET'])
def get_notification(notification_id):
    """Get a specific notification"""
    try:
        result = notification_service.get_notification(notification_id)
        
        if result['statusCode'] == 200:
            return jsonify(result['body'] if isinstance(result['body'], dict) else eval(result['body'])), 200
        else:
            return jsonify(result['body'] if isinstance(result['body'], dict) else eval(result['body'])), result['statusCode']
    except Exception as e:
        logger.error(f"Error getting notification: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/notifications/<notification_id>/status', methods=['PUT'])
def update_notification_status(notification_id):
    """Update notification status"""
    try:
        data = request.get_json() or {}
        result = notification_service.update_notification_status(notification_id, data.get('status'))
        
        if result['statusCode'] == 200:
            return jsonify(result['body'] if isinstance(result['body'], dict) else eval(result['body'])), 200
        else:
            return jsonify(result['body'] if isinstance(result['body'], dict) else eval(result['body'])), result['statusCode']
    except Exception as e:
        logger.error(f"Error updating notification status: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/templates', methods=['GET'])
def get_templates():
    """Get available notification templates"""
    try:
        result = notification_service.get_templates()
        
        if result['statusCode'] == 200:
            return jsonify(result['body'] if isinstance(result['body'], dict) else eval(result['body'])), 200
        else:
            return jsonify(result['body'] if isinstance(result['body'], dict) else eval(result['body'])), result['statusCode']
    except Exception as e:
        logger.error(f"Error getting templates: {str(e)}")
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
