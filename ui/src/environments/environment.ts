export const environment = {
  production: false,
  apiUrl: 'http://user-service:8080', // Point to user service for main API
  // Direct service URLs for microservices architecture (Docker internal network)
  userServiceUrl: 'http://user-service:8080',
  notificationServiceUrl: 'http://notification-service:8080',
  analyticsServiceUrl: 'http://analytics-service:8080'
 // apiUrl: 'http://localhost:3001', // Point to user service for main API
  // Direct service URLs for microservices architecture (host access via mapped ports)
  //userServiceUrl: 'http://localhost:3001',
  //notificationServiceUrl: 'http://localhost:3002',
  //analyticsServiceUrl: 'http://localhost:3003'
};
