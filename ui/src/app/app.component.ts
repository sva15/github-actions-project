import { Component } from '@angular/core';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.scss']
})
export class AppComponent {
  title = 'Mono Repo Application';
  
  menuItems = [
    { path: '/dashboard', icon: 'dashboard', label: 'Dashboard' },
    { path: '/users', icon: 'people', label: 'User Management' },
    { path: '/notifications', icon: 'notifications', label: 'Notifications' },
    { path: '/analytics', icon: 'analytics', label: 'Analytics' }
  ];
}
