"""
Analytics Service - Handles data analytics and reporting
Deployable to GCP Cloud Functions and AWS Lambda
"""
import json
import logging
from typing import Dict, Any, List
from datetime import datetime, timedelta
import uuid
from collections import defaultdict, Counter
import statistics

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class AnalyticsService:
    def __init__(self):
        # In a real application, this would connect to a database
        self.events = []
        self.metrics = defaultdict(list)
    
    def get_current_time(self) -> str:
        """Get current timestamp"""
        return datetime.utcnow().isoformat()
    
    def track_event(self, event_data: Dict[str, Any]) -> Dict[str, Any]:
        """Track an analytics event"""
        try:
            event_id = str(uuid.uuid4())
            
            # Validate required fields
            required_fields = ['event_name', 'user_id']
            for field in required_fields:
                if field not in event_data:
                    raise ValueError(f"Missing required field: {field}")
            
            event = {
                'id': event_id,
                'event_name': event_data['event_name'],
                'user_id': event_data['user_id'],
                'properties': event_data.get('properties', {}),
                'timestamp': datetime.utcnow().isoformat(),
                'session_id': event_data.get('session_id'),
                'device_type': event_data.get('device_type', 'unknown'),
                'platform': event_data.get('platform', 'unknown')
            }
            
            self.events.append(event)
            logger.info(f"Event tracked successfully: {event_id} - {event['event_name']}")
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Event tracked successfully',
                    'event_id': event_id
                })
            }
        except Exception as e:
            logger.error(f"Error tracking event: {str(e)}")
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'error': str(e)
                })
            }
    
    def get_event_analytics(self, filters: Dict[str, Any] = None) -> Dict[str, Any]:
        """Get analytics for events with optional filters"""
        try:
            filtered_events = self.events
            
            if filters:
                # Apply filters
                if 'event_name' in filters:
                    filtered_events = [e for e in filtered_events if e['event_name'] == filters['event_name']]
                
                if 'user_id' in filters:
                    filtered_events = [e for e in filtered_events if e['user_id'] == filters['user_id']]
                
                if 'date_from' in filters:
                    date_from = datetime.fromisoformat(filters['date_from'])
                    filtered_events = [e for e in filtered_events 
                                     if datetime.fromisoformat(e['timestamp']) >= date_from]
                
                if 'date_to' in filters:
                    date_to = datetime.fromisoformat(filters['date_to'])
                    filtered_events = [e for e in filtered_events 
                                     if datetime.fromisoformat(e['timestamp']) <= date_to]
            
            # Calculate analytics
            total_events = len(filtered_events)
            unique_users = len(set(e['user_id'] for e in filtered_events))
            
            # Event counts by name
            event_counts = Counter(e['event_name'] for e in filtered_events)
            
            # Device type distribution
            device_distribution = Counter(e['device_type'] for e in filtered_events)
            
            # Platform distribution
            platform_distribution = Counter(e['platform'] for e in filtered_events)
            
            # Events by hour (last 24 hours)
            now = datetime.utcnow()
            hourly_events = defaultdict(int)
            for event in filtered_events:
                event_time = datetime.fromisoformat(event['timestamp'])
                if now - event_time <= timedelta(hours=24):
                    hour_key = event_time.strftime('%Y-%m-%d %H:00')
                    hourly_events[hour_key] += 1
            
            analytics = {
                'total_events': total_events,
                'unique_users': unique_users,
                'event_counts': dict(event_counts),
                'device_distribution': dict(device_distribution),
                'platform_distribution': dict(platform_distribution),
                'hourly_events_24h': dict(hourly_events),
                'filters_applied': filters or {},
                'generated_at': datetime.utcnow().isoformat()
            }
            
            logger.info(f"Analytics generated for {total_events} events")
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'analytics': analytics
                })
            }
        except Exception as e:
            logger.error(f"Error generating analytics: {str(e)}")
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'error': str(e)
                })
            }
    
    def get_user_analytics(self, user_id: str) -> Dict[str, Any]:
        """Get analytics for a specific user"""
        try:
            user_events = [e for e in self.events if e['user_id'] == user_id]
            
            if not user_events:
                return {
                    'statusCode': 404,
                    'body': json.dumps({
                        'error': 'No events found for user'
                    })
                }
            
            # Calculate user-specific analytics
            total_events = len(user_events)
            event_counts = Counter(e['event_name'] for e in user_events)
            
            # First and last activity
            timestamps = [datetime.fromisoformat(e['timestamp']) for e in user_events]
            first_activity = min(timestamps).isoformat()
            last_activity = max(timestamps).isoformat()
            
            # Session analysis
            sessions = set(e['session_id'] for e in user_events if e['session_id'])
            total_sessions = len(sessions)
            
            # Device and platform usage
            devices_used = list(set(e['device_type'] for e in user_events))
            platforms_used = list(set(e['platform'] for e in user_events))
            
            # Activity by day of week
            day_activity = defaultdict(int)
            for event in user_events:
                day = datetime.fromisoformat(event['timestamp']).strftime('%A')
                day_activity[day] += 1
            
            user_analytics = {
                'user_id': user_id,
                'total_events': total_events,
                'total_sessions': total_sessions,
                'event_counts': dict(event_counts),
                'first_activity': first_activity,
                'last_activity': last_activity,
                'devices_used': devices_used,
                'platforms_used': platforms_used,
                'activity_by_day': dict(day_activity),
                'generated_at': datetime.utcnow().isoformat()
            }
            
            logger.info(f"User analytics generated for user: {user_id}")
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'user_analytics': user_analytics
                })
            }
        except Exception as e:
            logger.error(f"Error generating user analytics: {str(e)}")
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'error': str(e)
                })
            }
    
    def record_metric(self, metric_data: Dict[str, Any]) -> Dict[str, Any]:
        """Record a custom metric"""
        try:
            required_fields = ['metric_name', 'value']
            for field in required_fields:
                if field not in metric_data:
                    raise ValueError(f"Missing required field: {field}")
            
            metric = {
                'metric_name': metric_data['metric_name'],
                'value': float(metric_data['value']),
                'timestamp': datetime.utcnow().isoformat(),
                'tags': metric_data.get('tags', {}),
                'unit': metric_data.get('unit', 'count')
            }
            
            self.metrics[metric['metric_name']].append(metric)
            logger.info(f"Metric recorded: {metric['metric_name']} = {metric['value']}")
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Metric recorded successfully',
                    'metric': metric
                })
            }
        except Exception as e:
            logger.error(f"Error recording metric: {str(e)}")
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'error': str(e)
                })
            }
    
    def get_metric_stats(self, metric_name: str) -> Dict[str, Any]:
        """Get statistics for a specific metric"""
        try:
            if metric_name not in self.metrics:
                return {
                    'statusCode': 404,
                    'body': json.dumps({
                        'error': 'Metric not found'
                    })
                }
            
            metric_values = [m['value'] for m in self.metrics[metric_name]]
            
            if not metric_values:
                return {
                    'statusCode': 404,
                    'body': json.dumps({
                        'error': 'No data points for metric'
                    })
                }
            
            stats = {
                'metric_name': metric_name,
                'count': len(metric_values),
                'min': min(metric_values),
                'max': max(metric_values),
                'mean': statistics.mean(metric_values),
                'median': statistics.median(metric_values),
                'sum': sum(metric_values),
                'generated_at': datetime.utcnow().isoformat()
            }
            
            # Add standard deviation if we have enough data points
            if len(metric_values) > 1:
                stats['std_dev'] = statistics.stdev(metric_values)
            
            logger.info(f"Metric stats generated for: {metric_name}")
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'metric_stats': stats
                })
            }
        except Exception as e:
            logger.error(f"Error generating metric stats: {str(e)}")
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'error': str(e)
                })
            }

# Initialize service
analytics_service = AnalyticsService()

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
        
        resource = path_parameters.get('resource')
        user_id = path_parameters.get('user_id')
        metric_name = path_parameters.get('metric_name')
        
        if http_method == 'POST' and resource == 'events':
            return analytics_service.track_event(body or {})
        elif http_method == 'GET' and resource == 'analytics':
            return analytics_service.get_event_analytics(query_parameters)
        elif http_method == 'GET' and resource == 'users' and user_id:
            return analytics_service.get_user_analytics(user_id)
        elif http_method == 'POST' and resource == 'metrics':
            return analytics_service.record_metric(body or {})
        elif http_method == 'GET' and resource == 'metrics' and metric_name:
            return analytics_service.get_metric_stats(metric_name)
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
        method = request.method
        path = request.path
        args = request.args
        
        if method == 'POST' and 'events' in path:
            data = request.get_json() or {}
            result = analytics_service.track_event(data)
        elif method == 'GET' and 'analytics' in path:
            filters = dict(args)
            result = analytics_service.get_event_analytics(filters)
        elif method == 'GET' and 'users' in path:
            user_id = args.get('user_id')
            if not user_id:
                return {'error': 'user_id parameter required'}, 400
            result = analytics_service.get_user_analytics(user_id)
        elif method == 'POST' and 'metrics' in path:
            data = request.get_json() or {}
            result = analytics_service.record_metric(data)
        elif method == 'GET' and 'metrics' in path:
            metric_name = args.get('metric_name')
            if not metric_name:
                return {'error': 'metric_name parameter required'}, 400
            result = analytics_service.get_metric_stats(metric_name)
        else:
            return {'error': 'Method not allowed'}, 405
        
        return json.loads(result['body']), result['statusCode']
    except Exception as e:
        logger.error(f"GCP handler error: {str(e)}")
        return {'error': 'Internal server error'}, 500

if __name__ == "__main__":
    # For local testing
    test_event = {
        'event_name': 'page_view',
        'user_id': 'user123',
        'properties': {
            'page': '/dashboard',
            'referrer': 'google.com'
        },
        'device_type': 'desktop',
        'platform': 'web'
    }
    
    # Test track event
    result = analytics_service.track_event(test_event)
    print("Track Event Result:", result)
    
    # Test get analytics
    analytics_result = analytics_service.get_event_analytics()
    print("Get Analytics Result:", analytics_result)
    
    # Test user analytics
    user_analytics_result = analytics_service.get_user_analytics('user123')
    print("Get User Analytics Result:", user_analytics_result)
    
    # Test record metric
    metric_data = {
        'metric_name': 'response_time',
        'value': 250.5,
        'unit': 'ms'
    }
    metric_result = analytics_service.record_metric(metric_data)
    print("Record Metric Result:", metric_result)
    
    # Test metric stats
    stats_result = analytics_service.get_metric_stats('response_time')
    print("Get Metric Stats Result:", stats_result)
