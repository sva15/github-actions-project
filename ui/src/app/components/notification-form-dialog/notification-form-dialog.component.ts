import { Component, Inject } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { MatDialogRef, MAT_DIALOG_DATA } from '@angular/material/dialog';

export interface NotificationData {
  id?: number;
  title: string;
  message: string;
  type: 'email' | 'sms' | 'push';
  recipients: string[];
  scheduled_time?: string;
}

@Component({
  selector: 'app-notification-form-dialog',
  templateUrl: './notification-form-dialog.component.html',
  styleUrls: ['./notification-form-dialog.component.scss']
})
export class NotificationFormDialogComponent {
  notificationForm: FormGroup;
  isEditMode: boolean;
  notificationTypes = ['email', 'sms', 'push'];
  templates = ['welcome', 'password_reset', 'order_confirmation'];

  constructor(
    private fb: FormBuilder,
    public dialogRef: MatDialogRef<NotificationFormDialogComponent>,
    @Inject(MAT_DIALOG_DATA) public data: NotificationData
  ) {
    this.isEditMode = !!data?.id;
    this.notificationForm = this.createForm();
  }

  private createForm(): FormGroup {
    return this.fb.group({
      title: [this.data?.title || '', [Validators.required, Validators.minLength(3)]],
      message: [this.data?.message || '', [Validators.required, Validators.minLength(10)]],
      type: [this.data?.type || 'email', Validators.required],
      template: [this.data?.template || this.templates[0], Validators.required],
      recipients: [this.data?.recipients?.join(', ') || '', Validators.required],
      scheduled_time: [this.data?.scheduled_time || '']
    });
  }

  onSubmit(): void {
    if (this.notificationForm.valid) {
      const formValue = this.notificationForm.value;
      const notificationData: NotificationData = {
        ...formValue,
        recipients: formValue.recipients.split(',').map((r: string) => r.trim()),
        template: formValue.template,
        id: this.data?.id
      };
      this.dialogRef.close(notificationData);
    }
  }

  onCancel(): void {
    this.dialogRef.close();
  }

  getErrorMessage(field: string): string {
    const control = this.notificationForm.get(field);
    if (control?.hasError('required')) {
      return `${field.charAt(0).toUpperCase() + field.slice(1)} is required`;
    }
    if (control?.hasError('minlength')) {
      const requiredLength = control.errors?.['minlength']?.requiredLength;
      return `${field.charAt(0).toUpperCase() + field.slice(1)} must be at least ${requiredLength} characters`;
    }
    return '';
  }
}
