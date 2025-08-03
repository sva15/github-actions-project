"""
Unit tests for Analytics Service
"""
import pytest
import json
import uuid
from unittest.mock import patch, MagicMock
from datetime import datetime, timedelta
from main import AnalyticsService, lambda_handler, gcp_handler

class TestAnalyticsService:
    
    def setup_method(self):
        """Setup test fixtures before each test method."""
        self.analytics_service = AnalyticsService()
        self.test_event_data = {
            'event_name': 'test_event',
            'user_id': 'user123',
            'properties': {
                'page': '/test',
                'action': 'click'
            },
            'device_type': 'desktop',
            'platform': 'web'
        }
    
    def test_track_event_success(self):
        """Test successful event tracking"""
        result = self.analytics_service.track_event(self.test_event_data)
        
        assert result['statusCode'] == 200
        body = json.loads(result['body'])
        assert body['message'] == 'Event tracked successfully'
        assert 'event_id' in body
        
        # Verify event was stored
        assert len(self.analytics_service.events) == 1
        event = self.analytics_service.events[0]
        assert event['event_name'] == 'test_event'
        assert event['user_id'] == 'user123'
        assert event['device_type'] == 'desktop'
        assert event['platform'] == 'web'
    
    def test_track_event_missing_event_name(self):
        """Test event tracking with missing event_name"""
        invalid_data = {
            'user_id': 'user123'
        }
        result = self.analytics_service.track_event(invalid_data)
        
        assert result['statusCode'] == 400
        body = json.loads(result['body'])
        assert 'error' in body
        assert 'Missing required field: event_name' in body['error']
    
    def test_track_event_missing_user_id(self):
        """Test event tracking with missing user_id"""
        invalid_data = {
            'event_name': 'test_event'
        }
        result = self.analytics_service.track_event(invalid_data)
        
        assert result['statusCode'] == 400
        body = json.loads(result['body'])
        assert 'error' in body
        assert 'Missing required field: user_id' in body['error']
    
    def test_get_event_analytics_no_filters(self):
        """Test getting event analytics without filters"""
        # Add some test events
        for i in range(5):
            event_data = self.test_event_data.copy()
            event_data['event_name'] = f'event_{i}'
            self.analytics_service.track_event(event_data)
        
        result = self.analytics_service.get_event_analytics()
        
        assert result['statusCode'] == 200
        body = json.loads(result['body'])
        assert 'analytics' in body
        
        analytics = body['analytics']
        assert analytics['total_events'] == 5
        assert analytics['unique_users'] == 1
        assert len(analytics['event_counts']) == 5
    
    def test_get_event_analytics_with_filters(self):
        """Test getting event analytics with filters"""
        # Add events with different names
        for event_name in ['login', 'logout', 'page_view']:
            event_data = self.test_event_data.copy()
            event_data['event_name'] = event_name
            self.analytics_service.track_event(event_data)
        
        # Filter by event name
        filters = {'event_name': 'login'}
        result = self.analytics_service.get_event_analytics(filters)
        
        assert result['statusCode'] == 200
        body = json.loads(result['body'])
        analytics = body['analytics']
        assert analytics['total_events'] == 1
        assert 'login' in analytics['event_counts']
        assert analytics['event_counts']['login'] == 1
    
    def test_get_user_analytics_success(self):
        """Test getting user analytics"""
        user_id = 'test_user_123'
        
        # Add multiple events for the user
        for i in range(3):
            event_data = self.test_event_data.copy()
            event_data['user_id'] = user_id
            event_data['event_name'] = f'event_{i}'
            event_data['session_id'] = f'session_{i % 2}'  # 2 different sessions
            self.analytics_service.track_event(event_data)
        
        result = self.analytics_service.get_user_analytics(user_id)
        
        assert result['statusCode'] == 200
        body = json.loads(result['body'])
        assert 'user_analytics' in body
        
        user_analytics = body['user_analytics']
        assert user_analytics['user_id'] == user_id
        assert user_analytics['total_events'] == 3
        assert user_analytics['total_sessions'] == 2
        assert len(user_analytics['event_counts']) == 3
    
    def test_get_user_analytics_no_events(self):
        """Test getting user analytics for user with no events"""
        user_id = 'nonexistent_user'
        result = self.analytics_service.get_user_analytics(user_id)
        
        assert result['statusCode'] == 404
        body = json.loads(result['body'])
        assert 'error' in body
        assert body['error'] == 'No events found for user'
    
    def test_record_metric_success(self):
        """Test successful metric recording"""
        metric_data = {
            'metric_name': 'response_time',
            'value': 250.5,
            'unit': 'ms',
            'tags': {'endpoint': '/api/users'}
        }
        
        result = self.analytics_service.record_metric(metric_data)
        
        assert result['statusCode'] == 200
        body = json.loads(result['body'])
        assert body['message'] == 'Metric recorded successfully'
        assert 'metric' in body
        
        metric = body['metric']
        assert metric['metric_name'] == 'response_time'
        assert metric['value'] == 250.5
        assert metric['unit'] == 'ms'
        assert metric['tags']['endpoint'] == '/api/users'
    
    def test_record_metric_missing_name(self):
        """Test metric recording with missing metric_name"""
        invalid_data = {
            'value': 100
        }
        result = self.analytics_service.record_metric(invalid_data)
        
        assert result['statusCode'] == 400
        body = json.loads(result['body'])
        assert 'error' in body
        assert 'Missing required field: metric_name' in body['error']
    
    def test_record_metric_missing_value(self):
        """Test metric recording with missing value"""
        invalid_data = {
            'metric_name': 'test_metric'
        }
        result = self.analytics_service.record_metric(invalid_data)
        
        assert result['statusCode'] == 400
        body = json.loads(result['body'])
        assert 'error' in body
        assert 'Missing required field: value' in body['error']
    
    def test_get_metric_stats_success(self):
        """Test getting metric statistics"""
        metric_name = 'response_time'
        
        # Record multiple metric values
        values = [100, 200, 300, 400, 500]
        for value in values:
            metric_data = {
                'metric_name': metric_name,
                'value': value
            }
            self.analytics_service.record_metric(metric_data)
        
        result = self.analytics_service.get_metric_stats(metric_name)
        
        assert result['statusCode'] == 200
        body = json.loads(result['body'])
        assert 'metric_stats' in body
        
        stats = body['metric_stats']
        assert stats['metric_name'] == metric_name
        assert stats['count'] == 5
        assert stats['min'] == 100
        assert stats['max'] == 500
        assert stats['mean'] == 300
        assert stats['median'] == 300
        assert stats['sum'] == 1500
        assert 'std_dev' in stats
    
    def test_get_metric_stats_not_found(self):
        """Test getting statistics for non-existent metric"""
        result = self.analytics_service.get_metric_stats('nonexistent_metric')
        
        assert result['statusCode'] == 404
        body = json.loads(result['body'])
        assert 'error' in body
        assert body['error'] == 'Metric not found'


class TestLambdaHandler:
    
    def setup_method(self):
        """Setup test fixtures before each test method."""
        self.test_event_data = {
            'event_name': 'lambda_test',
            'user_id': 'lambda_user',
            'properties': {'source': 'lambda'}
        }
    
    def test_lambda_track_event(self):
        """Test Lambda handler for event tracking"""
        event = {
            'httpMethod': 'POST',
            'pathParameters': {'resource': 'events'},
            'body': json.dumps(self.test_event_data)
        }
        context = {}
        
        result = lambda_handler(event, context)
        
        assert result['statusCode'] == 200
        body = json.loads(result['body'])
        assert body['message'] == 'Event tracked successfully'
    
    def test_lambda_get_analytics(self):
        """Test Lambda handler for getting analytics"""
        event = {
            'httpMethod': 'GET',
            'pathParameters': {'resource': 'analytics'},
            'queryStringParameters': {}
        }
        context = {}
        
        result = lambda_handler(event, context)
        
        assert result['statusCode'] == 200
        body = json.loads(result['body'])
        assert 'analytics' in body
    
    def test_lambda_record_metric(self):
        """Test Lambda handler for recording metric"""
        metric_data = {
            'metric_name': 'lambda_metric',
            'value': 123.45
        }
        
        event = {
            'httpMethod': 'POST',
            'pathParameters': {'resource': 'metrics'},
            'body': json.dumps(metric_data)
        }
        context = {}
        
        result = lambda_handler(event, context)
        
        assert result['statusCode'] == 200
        body = json.loads(result['body'])
        assert body['message'] == 'Metric recorded successfully'
    
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
        self.test_event_data = {
            'event_name': 'gcp_test',
            'user_id': 'gcp_user',
            'properties': {'source': 'gcp'}
        }
    
    def test_gcp_track_event(self):
        """Test GCP handler for event tracking"""
        mock_request = MagicMock()
        mock_request.method = 'POST'
        mock_request.path = '/events'
        mock_request.get_json.return_value = self.test_event_data
        
        result, status_code = gcp_handler(mock_request)
        
        assert status_code == 200
        assert result['message'] == 'Event tracked successfully'
    
    def test_gcp_get_analytics(self):
        """Test GCP handler for getting analytics"""
        mock_request = MagicMock()
        mock_request.method = 'GET'
        mock_request.path = '/analytics'
        mock_request.args = {}
        
        result, status_code = gcp_handler(mock_request)
        
        assert status_code == 200
        assert 'analytics' in result
    
    def test_gcp_record_metric(self):
        """Test GCP handler for recording metric"""
        metric_data = {
            'metric_name': 'gcp_metric',
            'value': 456.78
        }
        
        mock_request = MagicMock()
        mock_request.method = 'POST'
        mock_request.path = '/metrics'
        mock_request.get_json.return_value = metric_data
        
        result, status_code = gcp_handler(mock_request)
        
        assert status_code == 200
        assert result['message'] == 'Metric recorded successfully'
    
    def test_gcp_method_not_allowed(self):
        """Test GCP handler with unsupported method"""
        mock_request = MagicMock()
        mock_request.method = 'DELETE'
        mock_request.path = '/events'
        
        result, status_code = gcp_handler(mock_request)
        
        assert status_code == 405
        assert 'error' in result
        assert result['error'] == 'Method not allowed'


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
