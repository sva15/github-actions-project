import { Component, OnInit, ViewChild } from '@angular/core';
import { MatTableDataSource } from '@angular/material/table';
import { MatPaginator } from '@angular/material/paginator';
import { MatSort } from '@angular/material/sort';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { FormControl } from '@angular/forms';
import { NotificationService } from '../../services/notification.service';
import { AnalyticsService } from '../../services/analytics.service';

export interface Notification {
  id: string;
  type: 'email' | 'sms' | 'push';
  recipient: string;
  subject?: string;
  message: string;
  status: 'pending' | 'sent' | 'delivered' | 'failed';
  createdAt: Date;
  sentAt?: Date;
  deliveredAt?: Date;
  errorMessage?: string;
}

@Component({
  selector: 'app-notification-center',
  templateUrl: './notification-center.component.html',
  styleUrls: ['./notification-center.component.scss']
})
export class NotificationCenterComponent implements OnInit {
  @ViewChild(MatPaginator) paginator!: MatPaginator;
  @ViewChild(MatSort) sort!: MatSort;

  displayedColumns: string[] = ['type', 'recipient', 'subject', 'status', 'createdAt', 'actions'];
  dataSource = new MatTableDataSource<Notification>();
  
  // Form controls
  typeFilter = new FormControl('');
  statusFilter = new FormControl('');
  searchControl = new FormControl('');
  
  // Statistics
  stats = {
    total: 0,
    sent: 0,
    pending: 0,
    failed: 0,
    deliveryRate: 0
  };
  
  // Loading states
  loading = false;
  sending = false;
  
  // Filter options
  notificationTypes = ['email', 'sms', 'push'];
  statusOptions = ['pending', 'sent', 'delivered', 'failed'];
  
  // New notification form
  showNewNotificationForm = false;
  newNotification = {
    type: 'email' as 'email' | 'sms' | 'push',
    recipient: '',
    subject: '',
    message: ''
  };

  constructor(
    private notificationService: NotificationService,
    private analyticsService: AnalyticsService,
    private dialog: MatDialog,
    private snackBar: MatSnackBar
  ) {}

  ngOnInit(): void {
    this.loadNotifications();
    this.setupFilters();
    this.loadStatistics();
    
    // Track page view
    this.analyticsService.trackEvent({
      event_type: 'page_view',
      page: 'notification_center',
      user_id: 'current_user'
    }).subscribe();
  }

  ngAfterViewInit(): void {
    this.dataSource.paginator = this.paginator;
    this.dataSource.sort = this.sort;
  }

  loadNotifications(): void {
    this.loading = true;
    
    // Simulate API call - replace with actual service call
    setTimeout(() => {
      const mockNotifications: Notification[] = [
        {
          id: '1',
          type: 'email',
          recipient: 'user@example.com',
          subject: 'Welcome to our platform',
          message: 'Thank you for joining us!',
          status: 'delivered',
          createdAt: new Date('2024-01-15T10:00:00'),
          sentAt: new Date('2024-01-15T10:01:00'),
          deliveredAt: new Date('2024-01-15T10:02:00')
        },
        {
          id: '2',
          type: 'sms',
          recipient: '+1234567890',
          message: 'Your verification code is 123456',
          status: 'sent',
          createdAt: new Date('2024-01-15T11:00:00'),
          sentAt: new Date('2024-01-15T11:01:00')
        },
        {
          id: '3',
          type: 'push',
          recipient: 'device_token_123',
          subject: 'New message',
          message: 'You have a new message',
          status: 'failed',
          createdAt: new Date('2024-01-15T12:00:00'),
          errorMessage: 'Invalid device token'
        },
        {
          id: '4',
          type: 'email',
          recipient: 'admin@example.com',
          subject: 'System Alert',
          message: 'High CPU usage detected',
          status: 'pending',
          createdAt: new Date('2024-01-15T13:00:00')
        }
      ];
      
      this.dataSource.data = mockNotifications;
      this.loading = false;
    }, 1000);
  }

  loadStatistics(): void {
    // Calculate statistics from current data
    const notifications = this.dataSource.data;
    this.stats.total = notifications.length;
    this.stats.sent = notifications.filter(n => n.status === 'sent' || n.status === 'delivered').length;
    this.stats.pending = notifications.filter(n => n.status === 'pending').length;
    this.stats.failed = notifications.filter(n => n.status === 'failed').length;
    this.stats.deliveryRate = this.stats.total > 0 ? (this.stats.sent / this.stats.total) * 100 : 0;
  }

  setupFilters(): void {
    // Search filter
    this.searchControl.valueChanges.subscribe(value => {
      this.dataSource.filter = value?.trim().toLowerCase() || '';
    });
    
    // Type filter
    this.typeFilter.valueChanges.subscribe(value => {
      this.applyFilters();
    });
    
    // Status filter
    this.statusFilter.valueChanges.subscribe(value => {
      this.applyFilters();
    });
    
    // Custom filter predicate
    this.dataSource.filterPredicate = (data: Notification, filter: string) => {
      const searchTerm = filter.toLowerCase();
      return data.recipient.toLowerCase().includes(searchTerm) ||
             data.message.toLowerCase().includes(searchTerm) ||
             (data.subject && data.subject.toLowerCase().includes(searchTerm));
    };
  }

  applyFilters(): void {
    const typeFilter = this.typeFilter.value;
    const statusFilter = this.statusFilter.value;
    
    this.dataSource.data = this.dataSource.data.filter(notification => {
      const matchesType = !typeFilter || notification.type === typeFilter;
      const matchesStatus = !statusFilter || notification.status === statusFilter;
      return matchesType && matchesStatus;
    });
  }

  sendNotification(): void {
    if (!this.newNotification.recipient || !this.newNotification.message) {
      this.snackBar.open('Please fill in all required fields', 'Close', { duration: 3000 });
      return;
    }
    
    this.sending = true;
    
    this.notificationService.sendNotification(this.newNotification).subscribe({
      next: (response) => {
        this.snackBar.open('Notification sent successfully!', 'Close', { duration: 3000 });
        this.resetNewNotificationForm();
        this.loadNotifications();
        this.sending = false;
        
        // Track event
        this.analyticsService.trackEvent({
          event_type: 'notification_sent',
          notification_type: this.newNotification.type,
          user_id: 'current_user'
        }).subscribe();
      },
      error: (error) => {
        this.snackBar.open('Failed to send notification', 'Close', { duration: 3000 });
        this.sending = false;
      }
    });
  }

  resendNotification(notification: Notification): void {
    this.notificationService.sendNotification({
      type: notification.type,
      recipient: notification.recipient,
      subject: notification.subject || '',
      message: notification.message
    }).subscribe({
      next: (response) => {
        this.snackBar.open('Notification resent successfully!', 'Close', { duration: 3000 });
        this.loadNotifications();
      },
      error: (error) => {
        this.snackBar.open('Failed to resend notification', 'Close', { duration: 3000 });
      }
    });
  }

  checkStatus(notificationId: string): void {
    this.notificationService.getNotificationStatus(notificationId).subscribe({
      next: (status) => {
        this.snackBar.open(`Status: ${status.status}`, 'Close', { duration: 3000 });
        this.loadNotifications();
      },
      error: (error) => {
        this.snackBar.open('Failed to check status', 'Close', { duration: 3000 });
      }
    });
  }

  exportNotifications(): void {
    const data = this.dataSource.data;
    const csv = this.convertToCSV(data);
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `notifications_${new Date().toISOString().split('T')[0]}.csv`;
    a.click();
    window.URL.revokeObjectURL(url);
    
    // Track export event
    this.analyticsService.trackEvent({
      event_type: 'data_export',
      export_type: 'notifications',
      user_id: 'current_user'
    }).subscribe();
  }

  private convertToCSV(data: Notification[]): string {
    const headers = ['ID', 'Type', 'Recipient', 'Subject', 'Message', 'Status', 'Created At', 'Sent At'];
    const rows = data.map(n => [
      n.id,
      n.type,
      n.recipient,
      n.subject || '',
      n.message,
      n.status,
      n.createdAt.toISOString(),
      n.sentAt?.toISOString() || ''
    ]);
    
    return [headers, ...rows].map(row => row.map(field => `"${field}"`).join(',')).join('\n');
  }

  resetNewNotificationForm(): void {
    this.newNotification = {
      type: 'email',
      recipient: '',
      subject: '',
      message: ''
    };
    this.showNewNotificationForm = false;
  }

  clearFilters(): void {
    this.typeFilter.setValue('');
    this.statusFilter.setValue('');
    this.searchControl.setValue('');
    this.loadNotifications();
  }

  getStatusColor(status: string): string {
    switch (status) {
      case 'delivered': return 'primary';
      case 'sent': return 'accent';
      case 'pending': return 'warn';
      case 'failed': return 'warn';
      default: return '';
    }
  }

  getStatusIcon(status: string): string {
    switch (status) {
      case 'delivered': return 'check_circle';
      case 'sent': return 'send';
      case 'pending': return 'schedule';
      case 'failed': return 'error';
      default: return 'help';
    }
  }
}
