import { Injectable } from '@angular/core';
import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Observable, throwError, OperatorFunction } from 'rxjs';
import { catchError, map } from 'rxjs/operators';
import { environment } from '../../environments/environment';

export interface Notification {
  id: string;
  recipient: string;
  type: 'email' | 'sms' | 'push';
  template: string;
  subject: string;
  message: string; // Renamed from body
  status: 'pending' | 'sent' | 'delivered' | 'failed'; // Added 'delivered'
  createdAt: Date; // Renamed from created_at and changed to Date type
  sentAt?: Date; // Renamed from sent_at and changed to Date type
  deliveredAt?: Date; // Added for component
  errorMessage?: string; // Renamed from error_message
}

export interface SendNotificationRequest {
  recipient: string;
  type: 'email' | 'sms' | 'push';
  subject?: string;
  message: string;
  template?: string;
  variables?: { [key: string]: any };
}

export interface NotificationApiResponse<T> {
  message?: string;
  notification?: T;
  notifications?: T[];
  count?: number;
  error?: string;
}

@Injectable({
  providedIn: 'root'
})
export class NotificationService {
  private readonly baseUrl = environment.notificationServiceUrl + '/notifications';

  constructor(private http: HttpClient) {}

  sendNotification(notificationData: SendNotificationRequest): Observable<Notification> {
    // Map frontend data to backend's expected format
    const payload = {
      recipient: notificationData.recipient,
      type: notificationData.type,
      template: notificationData.template || 'welcome', // Default to 'welcome' if not provided
      variables: {
        // Include any variables that the template might need
        name: notificationData.recipient.split('@')[0], // Extract name from email
        subject: notificationData.subject,
        message: notificationData.message
      }
    };

    return this.http.post<NotificationApiResponse<Notification>>(this.baseUrl, payload)
      .pipe(
        map(response => {
          if (response.notification) {
            return response.notification;
          }
          throw new Error(response.error || 'Failed to send notification');
        }),
        catchError(this.handleError)
      );
  }

  getNotificationStatus(notificationId: string): Observable<Notification> {
    return this.http.get<NotificationApiResponse<Notification>>(`${this.baseUrl}/${notificationId}`)
      .pipe(
        map(response => {
          if (response.notification) {
            return response.notification;
          }
          throw new Error(response.error || 'Notification not found');
        }),
        catchError(this.handleError)
      );
  }

  getNotificationsByRecipient(recipient: string): Observable<Notification[]> {
    return this.http.get<NotificationApiResponse<Notification>>(`${this.baseUrl}?recipient=${recipient}`)
      .pipe(
        map((response): Notification[] => {
          if (response.notifications) {
            return response.notifications;
          }
          throw new Error(response.error || 'Failed to fetch notifications');
        }),
        catchError(this.handleError)
      );
  }

  getAllNotifications(): Observable<Notification[]> {
    return this.http.get<NotificationApiResponse<any>>(this.baseUrl) // Use <any> to handle raw response
      .pipe(
        map(response => {
          const notifications = response.notifications || [];
          return notifications.map((n: any) => ({
            ...n,
            message: n.body, // map body to message
            createdAt: new Date(n.created_at), // map created_at to createdAt and convert to Date
            sentAt: n.sent_at ? new Date(n.sent_at) : undefined,
            errorMessage: n.error_message
          }));
        }),
        catchError(this.handleError)
      );
  }

  getAvailableTemplates(): string[] {
    return ['welcome', 'password_reset', 'order_confirmation'];
  }

  getNotificationTypes(): Array<{value: string, label: string}> {
    return [
      { value: 'email', label: 'Email' },
      { value: 'sms', label: 'SMS' },
      { value: 'push', label: 'Push Notification' }
    ];
  }

  private getMockNotifications(): Notification[] {
    return [
      {
        id: '1',
        recipient: 'john@example.com',
        type: 'email',
        template: 'welcome',
        subject: 'Welcome to our platform!',
        message: 'Hello John, welcome to our amazing platform!',
        status: 'sent',
        createdAt: new Date('2023-01-01T10:00:00Z'),
        sentAt: new Date('2023-01-01T10:01:00Z'),
        deliveredAt: new Date('2023-01-01T10:01:00Z'),
      },
      {
        id: '2',
        recipient: 'jane@example.com',
        type: 'email',
        template: 'password_reset',
        subject: 'Password Reset Request',
        message: 'Hello Jane, click here to reset your password',
        status: 'delivered',
        createdAt: new Date('2023-01-02T14:30:00Z'),
        sentAt: new Date('2023-01-02T14:31:00Z'),
        deliveredAt: new Date('2023-01-02T14:31:00Z'),
      },
      {
        id: '3',
        recipient: '+1234567890',
        type: 'sms',
        template: 'order_confirmation',
        subject: 'Order Confirmation',
        message: 'Your order #12345 has been confirmed!',
        status: 'failed',
        createdAt: new Date('2023-01-03T16:45:00Z'),
        errorMessage: 'Invalid phone number'
      }
    ];
  }

  private handleError(error: HttpErrorResponse): Observable<never> {
    let errorMessage = 'An unknown error occurred';
    
    if (error.error instanceof ErrorEvent) {
      // Client-side error
      errorMessage = `Error: ${error.error.message}`;
    } else {
      // Server-side error
      errorMessage = `Error Code: ${error.status}\nMessage: ${error.message}`;
      if (error.error && error.error.error) {
        errorMessage = error.error.error;
      }
    }
    
    console.error('NotificationService Error:', errorMessage);
    return throwError(() => new Error(errorMessage));
  }
}
