export const environment = {
  production: true,
  apiUrl: 'https://your-api-gateway.com/api',
  // Replace these with your actual deployed service URLs
  // GCP Cloud Functions URLs
  userServiceUrl: 'https://us-central1-your-project.cloudfunctions.net/user-service',
  notificationServiceUrl: 'https://us-central1-your-project.cloudfunctions.net/notification-service',
  analyticsServiceUrl: 'https://us-central1-your-project.cloudfunctions.net/analytics-service',
  
  // AWS Lambda URLs (via API Gateway)
  // userServiceUrl: 'https://your-api-id.execute-api.us-east-1.amazonaws.com/prod/users',
  // notificationServiceUrl: 'https://your-api-id.execute-api.us-east-1.amazonaws.com/prod/notifications',
  // analyticsServiceUrl: 'https://your-api-id.execute-api.us-east-1.amazonaws.com/prod/analytics'
};
