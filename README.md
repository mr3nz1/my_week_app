# My Week

Plan your week of courses: add, edit and delete courses, and see hours per day,
hours per week, the busiest day, and clashes, all computed live from your data.
Mini project for Mobile Programming, Session 6 (Firebase).

## Works with or without Firebase

The screens only talk to two interfaces in `lib/backend/backend.dart`:
`AuthService` (accounts) and `CourseRepository` (courses). There are two implementations:

| Backend | Where data lives | When it is used |
|---|---|---|
| `LocalBackend` | On this device (shared_preferences), one set of courses per account | Firebase is not configured, or `--dart-define=BACKEND=local` |
| `FirebaseBackend` | Firebase Auth + Firestore under `users/{uid}/courses` | `google-services.json` is present (Android) |

`lib/backend/select_backend.dart` tries `Firebase.initializeApp()` at startup and
falls back to local storage if that fails. The login screen and the week summary
show which one is active ("Saved on this device only" / "Saved in the cloud").

To force a backend: `flutter run --dart-define=BACKEND=local` or `--dart-define=BACKEND=firebase`.

## Plugging in Firebase (Android)

1. In the [Firebase console](https://console.firebase.google.com), create a project (Analytics off).
2. Add an **Android** app with package name **`com.example.my_week`**, then download
   `google-services.json` and put it in **`android/app/`**.
3. **Authentication → Get started → Email/Password → Enable.**
4. **Firestore Database → Create database → production mode**, then publish these rules:

   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /users/{userId}/{document=**} {
         allow read, write: if request.auth != null && request.auth.uid == userId;
       }
     }
   }
   ```
5. Stop and run the app again. Nothing else to change: the Gradle google-services
   plugin is applied automatically once the file exists (`android/app/build.gradle.kts`).

## Data

Collection `users/{uid}/courses`, one document per course:

| Field | Type | Example |
|---|---|---|
| `name` | string | `Algorithms` |
| `day` | int, 1 = Monday … 7 = Sunday | `2` |
| `start` | int, minutes since midnight | `600` (10:00) |
| `end` | int, minutes since midnight | `720` (12:00) |
| `createdAt` | server timestamp (Firestore only) | |

Never saved, always computed (`lib/models/week_stats.dart`): hours per day, hours
per week, busiest day, clashes.

Every new account gets sample courses (`lib/sample_data.dart`), with one Monday
clash so the warning can be seen straight away.

## Run and test

```
flutter run            # Android device/emulator, or -d chrome
flutter test           # stats, local backend (auth, privacy, CRUD + undo), widget flow
```
