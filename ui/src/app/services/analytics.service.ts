import { Injectable } from '@angular/core';
import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Observable, throwError } from 'rxjs';
import { catchError, map } from 'rxjs/operators';
import { environment } from '../../environments/environment';

export interface AnalyticsEvent {
  id: string;
  event_name: string;
  user_id: string;
  properties: { [key: string]: any };
  timestamp: string;
  session_id?: string;
  device_type: string;
  platform: string;
}

export interface TrackEventRequest {
  event_name: string;
  user_id: string;
  properties?: { [key: string]: any };
  session_id?: string;
  device_type?: string;
  platform?: string;
}

export interface EventAnalytics {
  total_events: number;
  unique_users: number;
  event_counts: { [key: string]: number };
  device_distribution: { [key: string]: number };
  platform_distribution: { [key: string]: number };
  hourly_events_24h: { [key: string]: number };
  filters_applied: { [key: string]: any };
  generated_at: string;
}

export interface UserAnalytics {
  user_id: string;
  total_events: number;
  total_sessions: number;
  event_counts: { [key: string]: number };
  first_activity: string;
  last_activity: string;
  devices_used: string[];
  platforms_used: string[];
  activity_by_day: { [key: string]: number };
  generated_at: string;
}

export interface Metric {
  metric_name: string;
  value: number;
  timestamp: string;
  tags: { [key: string]: any };
  unit: string;
}

export interface MetricStats {
  metric_name: string;
  count: number;
  min: number;
  max: number;
  mean: number;
  median: number;
  sum: number;
  std_dev?: number;
  generated_at: string;
}

export interface AnalyticsApiResponse<T> {
  message?: string;
  event_id?: string;
  analytics?: T;
  user_analytics?: T;
  metric?: T;
  metric_stats?: T;
  error?: string;
}

@Injectable({
  providedIn: 'root'
})
export class AnalyticsService {
  private readonly baseUrl = environment.analyticsServiceUrl;

  constructor(private http: HttpClient) {}

  trackEvent(eventData: TrackEventRequest): Observable<string> {
    return this.http.post<AnalyticsApiResponse<any>>(`${this.baseUrl}/events`, eventData)
      .pipe(
        map(response => {
          if (response.event_id) {
            return response.event_id;
          }
          throw new Error(response.error || 'Failed to track event');
        }),
        catchError(this.handleError)
      );
  }

  getEventAnalytics(filters?: { [key: string]: any }): Observable<EventAnalytics> {
    const params = new URLSearchParams();
    if (filters) {
      Object.keys(filters).forEach(key => {
        if (filters[key] !== null && filters[key] !== undefined) {
          params.append(key, filters[key].toString());
        }
      });
    }

    const url = `${this.baseUrl}/analytics${params.toString() ? '?' + params.toString() : ''}`;
    
    return this.http.get<AnalyticsApiResponse<EventAnalytics>>(url)
      .pipe(
        map(response => {
          if (response.analytics) {
            return response.analytics;
          }
          // For demo purposes, return mock data if no backend
          if (environment.production === false) {
            return this.getMockEventAnalytics();
          }
          throw new Error(response.error || 'Failed to fetch analytics');
        }),
        catchError(this.handleError)
      );
  }

  getUserAnalytics(userId: string): Observable<UserAnalytics> {
    return this.http.get<AnalyticsApiResponse<UserAnalytics>>(`${this.baseUrl}/users/${userId}`)
      .pipe(
        map(response => {
          if (response.user_analytics) {
            return response.user_analytics;
          }
          // For demo purposes, return mock data if no backend
          if (environment.production === false) {
            return this.getMockUserAnalytics(userId);
          }
          throw new Error(response.error || 'Failed to fetch user analytics');
        }),
        catchError(this.handleError)
      );
  }

  recordMetric(metricData: { metric_name: string; value: number; tags?: any; unit?: string }): Observable<Metric> {
    return this.http.post<AnalyticsApiResponse<Metric>>(`${this.baseUrl}/metrics`, metricData)
      .pipe(
        map(response => {
          if (response.metric) {
            return response.metric;
          }
          throw new Error(response.error || 'Failed to record metric');
        }),
        catchError(this.handleError)
      );
  }

  getMetricStats(metricName: string): Observable<MetricStats> {
    return this.http.get<AnalyticsApiResponse<MetricStats>>(`${this.baseUrl}/metrics/${metricName}`)
      .pipe(
        map(response => {
          if (response.metric_stats) {
            return response.metric_stats;
          }
          // For demo purposes, return mock data if no backend
          if (environment.production === false) {
            return this.getMockMetricStats(metricName);
          }
          throw new Error(response.error || 'Failed to fetch metric stats');
        }),
        catchError(this.handleError)
      );
  }

  getDashboardData(): Observable<any> {
    // Combine multiple analytics calls for dashboard
    return this.getEventAnalytics().pipe(
      map(analytics => ({
        totalEvents: analytics.total_events,
        uniqueUsers: analytics.unique_users,
        eventCounts: analytics.event_counts,
        deviceDistribution: analytics.device_distribution,
        platformDistribution: analytics.platform_distribution,
        hourlyEvents: analytics.hourly_events_24h
      }))
    );
  }

  getDashboardData(): Observable<any> {
    // Get dashboard summary data
    return this.getEventAnalytics().pipe(
      map(analytics => ({
        totalEvents: analytics.total_events,
        uniqueUsers: analytics.unique_users,
        eventCounts: analytics.event_counts,
        deviceDistribution: analytics.device_distribution,
        platformDistribution: analytics.platform_distribution,
        hourlyEvents: analytics.hourly_events_24h
      }))
    );
  }

  private getMockEventAnalytics(): EventAnalytics {
    return {
      total_events: 1250,
      unique_users: 89,
      event_counts: {
        'page_view': 650,
        'button_click': 320,
        'form_submit': 180,
        'user_signup': 45,
        'purchase': 55
      },
      device_distribution: {
        'desktop': 720,
        'mobile': 430,
        'tablet': 100
      },
      platform_distribution: {
        'web': 950,
        'ios': 180,
        'android': 120
      },
      hourly_events_24h: {
        '2023-01-01 00:00': 12,
        '2023-01-01 01:00': 8,
        '2023-01-01 02:00': 5,
        '2023-01-01 03:00': 3,
        '2023-01-01 04:00': 2,
        '2023-01-01 05:00': 4,
        '2023-01-01 06:00': 15,
        '2023-01-01 07:00': 25,
        '2023-01-01 08:00': 45,
        '2023-01-01 09:00': 65,
        '2023-01-01 10:00': 85,
        '2023-01-01 11:00': 95
      },
      filters_applied: {},
      generated_at: new Date().toISOString()
    };
  }

  private getMockUserAnalytics(userId: string): UserAnalytics {
    return {
      user_id: userId,
      total_events: 45,
      total_sessions: 8,
      event_counts: {
        'page_view': 25,
        'button_click': 12,
        'form_submit': 5,
        'purchase': 3
      },
      first_activity: '2023-01-01T10:00:00Z',
      last_activity: '2023-01-03T16:30:00Z',
      devices_used: ['desktop', 'mobile'],
      platforms_used: ['web', 'ios'],
      activity_by_day: {
        'Monday': 8,
        'Tuesday': 12,
        'Wednesday': 15,
        'Thursday': 6,
        'Friday': 4,
        'Saturday': 0,
        'Sunday': 0
      },
      generated_at: new Date().toISOString()
    };
  }

  private getMockMetricStats(metricName: string): MetricStats {
    return {
      metric_name: metricName,
      count: 100,
      min: 50.5,
      max: 500.2,
      mean: 275.8,
      median: 250.0,
      sum: 27580.0,
      std_dev: 125.4,
      generated_at: new Date().toISOString()
    };
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
    
    console.error('AnalyticsService Error:', errorMessage);
    return throwError(() => new Error(errorMessage));
  }
}
