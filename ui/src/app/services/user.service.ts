import { Injectable } from '@angular/core';
import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Observable, throwError } from 'rxjs';
import { catchError, map } from 'rxjs/operators';
import { environment } from '../../environments/environment';

export interface User {
  id: string;
  name: string;
  email: string;
  created_at: string;
  updated_at: string;
}

export interface CreateUserRequest {
  name: string;
  email: string;
}

export interface UpdateUserRequest {
  name?: string;
  email?: string;
}

export interface ApiResponse<T> {
  message?: string;
  user?: T;
  error?: string;
}

@Injectable({
  providedIn: 'root'
})
export class UserService {
  private readonly baseUrl = environment.apiUrl + '/users';

  constructor(private http: HttpClient) {}

  createUser(userData: CreateUserRequest): Observable<User> {
    return this.http.post<ApiResponse<User>>(this.baseUrl, userData)
      .pipe(
        map(response => {
          if (response.user) {
            return response.user;
          }
          throw new Error(response.error || 'Failed to create user');
        }),
        catchError(this.handleError)
      );
  }

  getUser(userId: string): Observable<User> {
    return this.http.get<ApiResponse<User>>(`${this.baseUrl}/${userId}`)
      .pipe(
        map(response => {
          if (response.user) {
            return response.user;
          }
          throw new Error(response.error || 'User not found');
        }),
        catchError(this.handleError)
      );
  }

  updateUser(userId: string, updateData: UpdateUserRequest): Observable<User> {
    return this.http.put<ApiResponse<User>>(`${this.baseUrl}/${userId}`, updateData)
      .pipe(
        map(response => {
          if (response.user) {
            return response.user;
          }
          throw new Error(response.error || 'Failed to update user');
        }),
        catchError(this.handleError)
      );
  }

  deleteUser(userId: string): Observable<void> {
    return this.http.delete<void>(`${this.baseUrl}/${userId}`)
      .pipe(
        catchError(this.handleError)
      );
  }

  getAllUsers(): Observable<User[]> {
    return this.http.get<ApiResponse<User[]>>(this.baseUrl)
      .pipe(
        map(response => {
          // For demo purposes, return mock data if no backend
          if (environment.production === false) {
            return this.getMockUsers();
          }
          return response.user || [];
        }),
        catchError(this.handleError)
      );
  }

  private getMockUsers(): User[] {
    return [
      {
        id: '1',
        name: 'John Doe',
        email: 'john@example.com',
        created_at: '2023-01-01T00:00:00Z',
        updated_at: '2023-01-01T00:00:00Z'
      },
      {
        id: '2',
        name: 'Jane Smith',
        email: 'jane@example.com',
        created_at: '2023-01-02T00:00:00Z',
        updated_at: '2023-01-02T00:00:00Z'
      },
      {
        id: '3',
        name: 'Bob Johnson',
        email: 'bob@example.com',
        created_at: '2023-01-03T00:00:00Z',
        updated_at: '2023-01-03T00:00:00Z'
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
    
    console.error('UserService Error:', errorMessage);
    return throwError(() => new Error(errorMessage));
  }
}
