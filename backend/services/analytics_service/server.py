"""
Flask server for Analytics Service
Provides REST API endpoints for Docker container deployment
"""
from flask import Flask, request, jsonify
from flask_cors import CORS
import logging
import json
from main import AnalyticsService

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Create Flask app
app = Flask(__name__)
CORS(app)  # Enable CORS for frontend access

# Initialize analytics service
analytics_service = AnalyticsService()

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'analytics',
        'timestamp': analytics_service.get_current_time()
    }), 200

@app.route('/events', methods=['POST'])
def track_event():
    """Track an analytics event"""
    try:
        data = request.get_json() or {}
        result = analytics_service.track_event(data)
        
        if result['statusCode'] == 200:
            body = json.loads(result['body']) if isinstance(result['body'], str) else result['body']
            return jsonify(body), 200
        else:
            body = json.loads(result['body']) if isinstance(result['body'], str) else result['body']
            return jsonify(body), result['statusCode']
    except Exception as e:
        logger.error(f"Error tracking event: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/analytics', methods=['GET'])
def get_analytics():
    """Get event analytics"""
    try:
        filters = dict(request.args)
        result = analytics_service.get_event_analytics(filters)
        
        if result['statusCode'] == 200:
            body = json.loads(result['body']) if isinstance(result['body'], str) else result['body']
            return jsonify(body), 200
        else:
            body = json.loads(result['body']) if isinstance(result['body'], str) else result['body']
            return jsonify(body), result['statusCode']
    except Exception as e:
        logger.error(f"Error getting analytics: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/users/<user_id>/analytics', methods=['GET'])
def get_user_analytics(user_id):
    """Get analytics for a specific user"""
    try:
        result = analytics_service.get_user_analytics(user_id)
        
        if result['statusCode'] == 200:
            body = json.loads(result['body']) if isinstance(result['body'], str) else result['body']
            return jsonify(body), 200
        else:
            body = json.loads(result['body']) if isinstance(result['body'], str) else result['body']
            return jsonify(body), result['statusCode']
    except Exception as e:
        logger.error(f"Error getting user analytics: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/metrics', methods=['POST'])
def record_metric():
    """Record a custom metric"""
    try:
        data = request.get_json() or {}
        result = analytics_service.record_metric(data)
        
        if result['statusCode'] == 200:
            body = json.loads(result['body']) if isinstance(result['body'], str) else result['body']
            return jsonify(body), 200
        else:
            body = json.loads(result['body']) if isinstance(result['body'], str) else result['body']
            return jsonify(body), result['statusCode']
    except Exception as e:
        logger.error(f"Error recording metric: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/metrics/<metric_name>/stats', methods=['GET'])
def get_metric_stats(metric_name):
    """Get statistics for a specific metric"""
    try:
        result = analytics_service.get_metric_stats(metric_name)
        
        if result['statusCode'] == 200:
            body = json.loads(result['body']) if isinstance(result['body'], str) else result['body']
            return jsonify(body), 200
        else:
            body = json.loads(result['body']) if isinstance(result['body'], str) else result['body']
            return jsonify(body), result['statusCode']
    except Exception as e:
        logger.error(f"Error getting metric stats: {str(e)}")
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
