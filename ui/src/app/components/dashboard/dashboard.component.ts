import { Component, OnInit } from '@angular/core';
import { AnalyticsService } from '../../services/analytics.service';
import { UserService } from '../../services/user.service';
import { NotificationService } from '../../services/notification.service';
import { ChartConfiguration, ChartOptions, ChartType } from 'chart.js';

@Component({
  selector: 'app-dashboard',
  templateUrl: './dashboard.component.html',
  styleUrls: ['./dashboard.component.scss']
})
export class DashboardComponent implements OnInit {
  loading = true;
  error: string | null = null;

  // Dashboard stats
  totalUsers = 0;
  totalEvents = 0;
  totalNotifications = 0;
  uniqueUsers = 0;

  // Chart data
  eventChartData: ChartConfiguration<'doughnut'>['data'] = {
    labels: [],
    datasets: [{
      data: [],
      backgroundColor: [
        '#FF6384',
        '#36A2EB',
        '#FFCE56',
        '#4BC0C0',
        '#9966FF'
      ]
    }]
  };

  deviceChartData: ChartConfiguration<'bar'>['data'] = {
    labels: [],
    datasets: [{
      label: 'Device Usage',
      data: [],
      backgroundColor: '#36A2EB'
    }]
  };

  hourlyChartData: ChartConfiguration<'line'>['data'] = {
    labels: [],
    datasets: [{
      label: 'Events per Hour',
      data: [],
      borderColor: '#FF6384',
      backgroundColor: 'rgba(255, 99, 132, 0.2)',
      tension: 0.1
    }]
  };

  // Chart options
  doughnutChartOptions: ChartOptions<'doughnut'> = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        position: 'bottom'
      }
    }
  };

  barChartOptions: ChartOptions<'bar'> = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        display: false
      }
    },
    scales: {
      y: {
        beginAtZero: true
      }
    }
  };

  lineChartOptions: ChartOptions<'line'> = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        display: false
      }
    },
    scales: {
      y: {
        beginAtZero: true
      }
    }
  };

  constructor(
    private analyticsService: AnalyticsService,
    private userService: UserService,
    private notificationService: NotificationService
  ) {}

  ngOnInit(): void {
    this.loadDashboardData();
  }

  loadDashboardData(): void {
    this.loading = true;
    this.error = null;

    // Load analytics data
    this.analyticsService.getDashboardData().subscribe({
      next: (data) => {
        this.totalEvents = data.totalEvents;
        this.uniqueUsers = data.uniqueUsers;
        
        // Update event chart
        this.eventChartData.labels = Object.keys(data.eventCounts);
        this.eventChartData.datasets[0].data = Object.values(data.eventCounts);

        // Update device chart
        this.deviceChartData.labels = Object.keys(data.deviceDistribution);
        this.deviceChartData.datasets[0].data = Object.values(data.deviceDistribution);

        // Update hourly chart
        const hourlyLabels = Object.keys(data.hourlyEvents).map(hour => 
          new Date(hour).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })
        );
        this.hourlyChartData.labels = hourlyLabels;
        this.hourlyChartData.datasets[0].data = Object.values(data.hourlyEvents);

        this.loading = false;
      },
      error: (error) => {
        console.error('Error loading analytics data:', error);
        this.error = 'Failed to load analytics data';
        this.loading = false;
      }
    });

    // Load user count
    this.userService.getAllUsers().subscribe({
      next: (users) => {
        this.totalUsers = users.length;
      },
      error: (error) => {
        console.error('Error loading users:', error);
      }
    });

    // Load notification count
    this.notificationService.getAllNotifications().subscribe({
      next: (notifications) => {
        this.totalNotifications = notifications.length;
      },
      error: (error) => {
        console.error('Error loading notifications:', error);
      }
    });
  }

  refreshData(): void {
    this.loadDashboardData();
  }

  trackEvent(eventName: string): void {
    this.analyticsService.trackEvent({
      event_name: eventName,
      user_id: 'dashboard-user',
      properties: {
        source: 'dashboard'
      },
      device_type: 'desktop',
      platform: 'web'
    }).subscribe({
      next: (eventId) => {
        console.log('Event tracked:', eventId);
      },
      error: (error) => {
        console.error('Error tracking event:', error);
      }
    });
  }
}
