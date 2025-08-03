import { Component, OnInit, ViewChild } from '@angular/core';
import { MatTableDataSource } from '@angular/material/table';
import { MatPaginator } from '@angular/material/paginator';
import { MatSort } from '@angular/material/sort';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { UserService, User } from '../../services/user.service';
import { UserFormDialogComponent } from '../user-form-dialog/user-form-dialog.component';

@Component({
  selector: 'app-user-management',
  templateUrl: './user-management.component.html',
  styleUrls: ['./user-management.component.scss']
})
export class UserManagementComponent implements OnInit {
  displayedColumns: string[] = ['name', 'email', 'created_at', 'updated_at', 'actions'];
  dataSource = new MatTableDataSource<User>();
  loading = false;
  error: string | null = null;

  @ViewChild(MatPaginator) paginator!: MatPaginator;
  @ViewChild(MatSort) sort!: MatSort;

  constructor(
    private userService: UserService,
    private dialog: MatDialog,
    private snackBar: MatSnackBar
  ) {}

  ngOnInit(): void {
    this.loadUsers();
  }

  ngAfterViewInit(): void {
    this.dataSource.paginator = this.paginator;
    this.dataSource.sort = this.sort;
  }

  loadUsers(): void {
    this.loading = true;
    this.error = null;

    this.userService.getAllUsers().subscribe({
      next: (users) => {
        this.dataSource.data = users;
        this.loading = false;
      },
      error: (error) => {
        console.error('Error loading users:', error);
        this.error = 'Failed to load users';
        this.loading = false;
        this.showSnackBar('Failed to load users', 'error');
      }
    });
  }

  applyFilter(event: Event): void {
    const filterValue = (event.target as HTMLInputElement).value;
    this.dataSource.filter = filterValue.trim().toLowerCase();

    if (this.dataSource.paginator) {
      this.dataSource.paginator.firstPage();
    }
  }

  openCreateUserDialog(): void {
    const dialogRef = this.dialog.open(UserFormDialogComponent, {
      width: '500px',
      data: { mode: 'create' }
    });

    dialogRef.afterClosed().subscribe(result => {
      if (result) {
        this.createUser(result);
      }
    });
  }

  openEditUserDialog(user: User): void {
    const dialogRef = this.dialog.open(UserFormDialogComponent, {
      width: '500px',
      data: { mode: 'edit', user: { ...user } }
    });

    dialogRef.afterClosed().subscribe(result => {
      if (result) {
        this.updateUser(user.id, result);
      }
    });
  }

  createUser(userData: { name: string; email: string }): void {
    this.loading = true;

    this.userService.createUser(userData).subscribe({
      next: (user) => {
        this.dataSource.data = [...this.dataSource.data, user];
        this.loading = false;
        this.showSnackBar('User created successfully', 'success');
      },
      error: (error) => {
        console.error('Error creating user:', error);
        this.loading = false;
        this.showSnackBar('Failed to create user', 'error');
      }
    });
  }

  updateUser(userId: string, userData: { name?: string; email?: string }): void {
    this.loading = true;

    this.userService.updateUser(userId, userData).subscribe({
      next: (updatedUser) => {
        const index = this.dataSource.data.findIndex(u => u.id === userId);
        if (index !== -1) {
          const newData = [...this.dataSource.data];
          newData[index] = updatedUser;
          this.dataSource.data = newData;
        }
        this.loading = false;
        this.showSnackBar('User updated successfully', 'success');
      },
      error: (error) => {
        console.error('Error updating user:', error);
        this.loading = false;
        this.showSnackBar('Failed to update user', 'error');
      }
    });
  }

  deleteUser(user: User): void {
    if (confirm(`Are you sure you want to delete user "${user.name}"?`)) {
      this.loading = true;

      this.userService.deleteUser(user.id).subscribe({
        next: () => {
          this.dataSource.data = this.dataSource.data.filter(u => u.id !== user.id);
          this.loading = false;
          this.showSnackBar('User deleted successfully', 'success');
        },
        error: (error) => {
          console.error('Error deleting user:', error);
          this.loading = false;
          this.showSnackBar('Failed to delete user', 'error');
        }
      });
    }
  }

  viewUserDetails(user: User): void {
    // Navigate to user details or open a details dialog
    console.log('View user details:', user);
    this.showSnackBar(`Viewing details for ${user.name}`, 'info');
  }

  refreshUsers(): void {
    this.loadUsers();
  }

  exportUsers(): void {
    // Export users to CSV or other format
    const csvContent = this.generateCSV(this.dataSource.data);
    this.downloadCSV(csvContent, 'users.csv');
    this.showSnackBar('Users exported successfully', 'success');
  }

  private generateCSV(users: User[]): string {
    const headers = ['ID', 'Name', 'Email', 'Created At', 'Updated At'];
    const csvRows = [headers.join(',')];

    users.forEach(user => {
      const row = [
        user.id,
        `"${user.name}"`,
        user.email,
        user.created_at,
        user.updated_at
      ];
      csvRows.push(row.join(','));
    });

    return csvRows.join('\n');
  }

  private downloadCSV(content: string, filename: string): void {
    const blob = new Blob([content], { type: 'text/csv' });
    const url = window.URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = filename;
    link.click();
    window.URL.revokeObjectURL(url);
  }

  private showSnackBar(message: string, type: 'success' | 'error' | 'info'): void {
    const config = {
      duration: 3000,
      panelClass: [`snackbar-${type}`]
    };

    this.snackBar.open(message, 'Close', config);
  }

  formatDate(dateString: string): string {
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  }
}
