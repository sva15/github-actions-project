import { Component, OnInit, ViewChild, ElementRef } from '@angular/core';
import { FormControl } from '@angular/forms';
import { MatDateRangePicker } from '@angular/material/datepicker';
import { MatSnackBar } from '@angular/material/snack-bar';
import { Chart, ChartConfiguration, ChartType, registerables } from 'chart.js';
import { AnalyticsService } from '../../services/analytics.service';

Chart.register(...registerables);

export interface AnalyticsData {
  pageViews: number;
  uniqueUsers: number;
  sessions: number;
  bounceRate: number;
  avgSessionDuration: number;
  conversionRate: number;
}

export interface EventData {
  event_type: string;
  count: number;
  percentage: number;
}

@Component({
  selector: 'app-analytics',
  templateUrl: './analytics.component.html',
  styleUrls: ['./analytics.component.scss']
})
export class AnalyticsComponent implements OnInit {
  @ViewChild('pageViewsChart') pageViewsChartRef!: ElementRef<HTMLCanvasElement>;
  @ViewChild('eventsChart') eventsChartRef!: ElementRef<HTMLCanvasElement>;
  @ViewChild('userActivityChart') userActivityChartRef!: ElementRef<HTMLCanvasElement>;
  @ViewChild('conversionChart') conversionChartRef!: ElementRef<HTMLCanvasElement>;

  // Charts
  pageViewsChart: Chart | null = null;
  eventsChart: Chart | null = null;
  userActivityChart: Chart | null = null;
  conversionChart: Chart | null = null;

  // Data
  analyticsData: AnalyticsData = {
    pageViews: 0,
    uniqueUsers: 0,
    sessions: 0,
    bounceRate: 0,
    avgSessionDuration: 0,
    conversionRate: 0
  };

  eventData: EventData[] = [];
  recentEvents: any[] = [];
  
  // Controls
  dateRange = new FormControl();
  selectedMetric = new FormControl('pageViews');
  selectedPeriod = new FormControl('7days');
  
  // Options
  metrics = [
    { value: 'pageViews', label: 'Page Views' },
    { value: 'uniqueUsers', label: 'Unique Users' },
    { value: 'sessions', label: 'Sessions' },
    { value: 'conversionRate', label: 'Conversion Rate' }
  ];
  
  periods = [
    { value: '24hours', label: 'Last 24 Hours' },
    { value: '7days', label: 'Last 7 Days' },
    { value: '30days', label: 'Last 30 Days' },
    { value: '90days', label: 'Last 90 Days' }
  ];

  // Loading states
  loading = false;
  chartsLoading = false;

  constructor(
    private analyticsService: AnalyticsService,
    private snackBar: MatSnackBar
  ) {}

  ngOnInit(): void {
    this.loadAnalyticsData();
    this.setupControlListeners();
    
    // Track page view
    this.analyticsService.trackEvent({
      event_type: 'page_view',
      page: 'analytics',
      user_id: 'current_user'
    }).subscribe();
  }

  ngAfterViewInit(): void {
    // Initialize charts after view init
    setTimeout(() => {
      this.initializeCharts();
    }, 100);
  }

  ngOnDestroy(): void {
    // Destroy charts to prevent memory leaks
    if (this.pageViewsChart) this.pageViewsChart.destroy();
    if (this.eventsChart) this.eventsChart.destroy();
    if (this.userActivityChart) this.userActivityChart.destroy();
    if (this.conversionChart) this.conversionChart.destroy();
  }

  setupControlListeners(): void {
    this.selectedPeriod.valueChanges.subscribe(() => {
      this.loadAnalyticsData();
    });

    this.selectedMetric.valueChanges.subscribe(() => {
      this.updateCharts();
    });
  }

  loadAnalyticsData(): void {
    this.loading = true;
    
    // Simulate API calls - replace with actual service calls
    setTimeout(() => {
      // Mock analytics data
      this.analyticsData = {
        pageViews: 12543,
        uniqueUsers: 3421,
        sessions: 4567,
        bounceRate: 34.5,
        avgSessionDuration: 245,
        conversionRate: 12.3
      };

      // Mock event data
      this.eventData = [
        { event_type: 'page_view', count: 8543, percentage: 45.2 },
        { event_type: 'button_click', count: 3421, percentage: 18.1 },
        { event_type: 'form_submit', count: 2876, percentage: 15.2 },
        { event_type: 'user_login', count: 2234, percentage: 11.8 },
        { event_type: 'user_signup', count: 1876, percentage: 9.9 }
      ];

      // Mock recent events
      this.recentEvents = [
        {
          id: '1',
          event_type: 'user_signup',
          user_id: 'user_123',
          timestamp: new Date(Date.now() - 300000),
          metadata: { source: 'organic', page: '/signup' }
        },
        {
          id: '2',
          event_type: 'purchase',
          user_id: 'user_456',
          timestamp: new Date(Date.now() - 600000),
          metadata: { amount: 99.99, product: 'Premium Plan' }
        },
        {
          id: '3',
          event_type: 'page_view',
          user_id: 'user_789',
          timestamp: new Date(Date.now() - 900000),
          metadata: { page: '/dashboard', referrer: 'google.com' }
        }
      ];

      this.loading = false;
      this.updateCharts();
    }, 1000);
  }

  initializeCharts(): void {
    this.createPageViewsChart();
    this.createEventsChart();
    this.createUserActivityChart();
    this.createConversionChart();
  }

  createPageViewsChart(): void {
    if (!this.pageViewsChartRef) return;

    const ctx = this.pageViewsChartRef.nativeElement.getContext('2d');
    if (!ctx) return;

    // Mock time series data
    const labels = this.generateDateLabels();
    const data = this.generateMockTimeSeriesData(labels.length);

    this.pageViewsChart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: labels,
        datasets: [{
          label: 'Page Views',
          data: data,
          borderColor: '#2196f3',
          backgroundColor: 'rgba(33, 150, 243, 0.1)',
          tension: 0.4,
          fill: true
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: false
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            grid: {
              color: '#e0e0e0'
            }
          },
          x: {
            grid: {
              color: '#e0e0e0'
            }
          }
        }
      }
    });
  }

  createEventsChart(): void {
    if (!this.eventsChartRef) return;

    const ctx = this.eventsChartRef.nativeElement.getContext('2d');
    if (!ctx) return;

    this.eventsChart = new Chart(ctx, {
      type: 'doughnut',
      data: {
        labels: this.eventData.map(e => e.event_type.replace('_', ' ').toUpperCase()),
        datasets: [{
          data: this.eventData.map(e => e.count),
          backgroundColor: [
            '#2196f3',
            '#4caf50',
            '#ff9800',
            '#f44336',
            '#9c27b0'
          ],
          borderWidth: 2,
          borderColor: '#fff'
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'bottom',
            labels: {
              padding: 20,
              usePointStyle: true
            }
          }
        }
      }
    });
  }

  createUserActivityChart(): void {
    if (!this.userActivityChartRef) return;

    const ctx = this.userActivityChartRef.nativeElement.getContext('2d');
    if (!ctx) return;

    // Mock hourly activity data
    const hours = Array.from({ length: 24 }, (_, i) => `${i}:00`);
    const activityData = Array.from({ length: 24 }, () => Math.floor(Math.random() * 100) + 20);

    this.userActivityChart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: hours,
        datasets: [{
          label: 'Active Users',
          data: activityData,
          backgroundColor: '#4caf50',
          borderColor: '#388e3c',
          borderWidth: 1
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: false
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            grid: {
              color: '#e0e0e0'
            }
          },
          x: {
            grid: {
              display: false
            }
          }
        }
      }
    });
  }

  createConversionChart(): void {
    if (!this.conversionChartRef) return;

    const ctx = this.conversionChartRef.nativeElement.getContext('2d');
    if (!ctx) return;

    // Mock conversion funnel data
    const stages = ['Visitors', 'Sign Ups', 'Trials', 'Purchases'];
    const values = [10000, 2500, 1200, 450];

    this.conversionChart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: stages,
        datasets: [{
          label: 'Conversion Funnel',
          data: values,
          backgroundColor: [
            '#2196f3',
            '#4caf50',
            '#ff9800',
            '#f44336'
          ],
          borderWidth: 1
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        indexAxis: 'y',
        plugins: {
          legend: {
            display: false
          }
        },
        scales: {
          x: {
            beginAtZero: true,
            grid: {
              color: '#e0e0e0'
            }
          },
          y: {
            grid: {
              display: false
            }
          }
        }
      }
    });
  }

  updateCharts(): void {
    this.chartsLoading = true;
    
    // Simulate data update
    setTimeout(() => {
      if (this.pageViewsChart) {
        const newData = this.generateMockTimeSeriesData(this.pageViewsChart.data.labels?.length || 7);
        this.pageViewsChart.data.datasets[0].data = newData;
        this.pageViewsChart.update();
      }
      
      this.chartsLoading = false;
    }, 500);
  }

  generateDateLabels(): string[] {
    const period = this.selectedPeriod.value;
    const labels: string[] = [];
    const now = new Date();
    
    let days = 7;
    switch (period) {
      case '24hours': days = 1; break;
      case '7days': days = 7; break;
      case '30days': days = 30; break;
      case '90days': days = 90; break;
    }
    
    for (let i = days - 1; i >= 0; i--) {
      const date = new Date(now);
      date.setDate(date.getDate() - i);
      labels.push(date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' }));
    }
    
    return labels;
  }

  generateMockTimeSeriesData(length: number): number[] {
    return Array.from({ length }, () => Math.floor(Math.random() * 1000) + 100);
  }

  exportAnalytics(): void {
    const data = {
      period: this.selectedPeriod.value,
      analytics: this.analyticsData,
      events: this.eventData,
      exportedAt: new Date().toISOString()
    };
    
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `analytics_${new Date().toISOString().split('T')[0]}.json`;
    a.click();
    window.URL.revokeObjectURL(url);
    
    // Track export event
    this.analyticsService.trackEvent({
      event_type: 'data_export',
      export_type: 'analytics',
      user_id: 'current_user'
    }).subscribe();
    
    this.snackBar.open('Analytics data exported successfully!', 'Close', { duration: 3000 });
  }

  refreshData(): void {
    this.loadAnalyticsData();
    this.snackBar.open('Analytics data refreshed!', 'Close', { duration: 2000 });
  }

  formatDuration(seconds: number): string {
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = seconds % 60;
    return `${minutes}m ${remainingSeconds}s`;
  }

  formatNumber(num: number): string {
    if (num >= 1000000) {
      return (num / 1000000).toFixed(1) + 'M';
    } else if (num >= 1000) {
      return (num / 1000).toFixed(1) + 'K';
    }
    return num.toString();
  }

  getEventIcon(eventType: string): string {
    switch (eventType) {
      case 'page_view': return 'visibility';
      case 'button_click': return 'touch_app';
      case 'form_submit': return 'send';
      case 'user_login': return 'login';
      case 'user_signup': return 'person_add';
      case 'purchase': return 'shopping_cart';
      default: return 'event';
    }
  }

  getEventColor(eventType: string): string {
    switch (eventType) {
      case 'page_view': return '#2196f3';
      case 'button_click': return '#4caf50';
      case 'form_submit': return '#ff9800';
      case 'user_login': return '#9c27b0';
      case 'user_signup': return '#f44336';
      case 'purchase': return '#795548';
      default: return '#666';
    }
  }
}
