# Firebase Configuration Instructions

To run this pharmacy system, you must connect it to a Firebase project.

### 1. Create a Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/).
2. Create a new project named `pharmacy-management`.

### 2. Enable Services
1. **Authentication:** Enable **Email/Password** sign-in method.
2. **Firestore Database:** Create a database in **Production Mode**.
3. **Cloud Messaging:** Enable for push notifications.

### 3. Add Platforms
Run the following command in your terminal within the project directory:
```bash
dart pub global activate flutterfire_cli
flutterfire configure
```
*Note: This will generate `lib/firebase_options.dart` which you should import in `lib/main.dart`. It will also automatically configure your iOS/Android native projects.*

### 3.1 Initial Setup for iOS
1. In the **Firebase Console**, add an iOS app to your project.
2. Download the `GoogleService-Info.plist` file.
3. Open the `ios/` folder in Xcode.
4. Drag and drop the `GoogleService-Info.plist` file into the `Runner` folder (choose "Copy items if needed").
5. In Xcode, ensure your **Bundle Identifier** in the "Signing & Capabilities" tab matches the one you entered in Firebase.
6. Run `pod install` in the `ios/` directory to install dependencies.

### 4. Setup Firestore Rules
Paste the following rules in your Firestore Rules tab:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /medicines/{medicineId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null && (
        (get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin') ||
        (request.resource.data.diff(resource.data).affectedKeys().hasOnly(['quantity', 'updatedAt']))
      );
      allow delete: if request.auth != null && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    match /sales/{saleId} {
      allow read, create: if request.auth != null;
      allow update, delete: if false; 
    }
    
    match /suppliers/{supplierId} {
      allow read, write: if request.auth != null && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }

    match /notifications/{notifId} {
       allow read, create, update: if request.auth != null;
    }
  }
}
```

### 5. Create Initial Admin User
Manually add a document to the `users` collection in Firestore:
- **Document ID:** (Your Firebase Auth UID)
- **Email:** (Your admin email)
- **Role:** `admin` (Important: must be lowercase)
