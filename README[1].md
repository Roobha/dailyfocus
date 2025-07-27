<p align="center">
  <img src="assets/icon/dailyfocus.jpg" alt="DailyFocus Logo" width="200"/>
</p>

# DailyFocus 🧠📅  
Organize your tasks. Stay focused. Sync with the cloud.


# 📝 DailyFocus - Todo Task Manager (Flutter + Firebase + Hive)

**DailyFocus** is a cross-platform Todo Task Management app built using **Flutter**, with support for **Google Sign-In**, **offline access**, and **Firestore sync**.

![DailyFocus Logo](assets/icon/dailyfocus.jpg)

---

## 🚀 Features

- ✅ **Google Sign-In** (Firebase Auth)
- 📝 **Add/Edit/Delete tasks** with due date
- 📴 **Offline access** (Hive local DB)
- 🔄 **Auto sync with Firestore** on login/network
- 🔁 **Conflict resolution** using `updatedAt` timestamps
- 📶 **Sync Hive ↔ Firestore** for multi-device support
- 🔔 *(Coming Soon)* Local push reminders
- ☁️ Firebase Web + Android support
- 🌓 Light/Dark mode aware UI

---

## 📂 Project Structure

```
lib/
├── main.dart
├── login_screen.dart
├── firebase_options.dart
├── models/
│   └── task_model.dart
├── screens/
│   ├── home_screen.dart
│   └── add_task_screen.dart
├── notifications/
│   └── notification_service.dart (coming soon)
assets/
└── icon/dailyfocus.jpg
```

---

## 🧰 Tech Stack

| Tech            | Purpose                         |
|-----------------|---------------------------------|
| Flutter         | UI framework                    |
| Firebase Auth   | Google Sign-In                  |
| Cloud Firestore | Online task sync                |
| Hive            | Offline-first storage           |
| Connectivity    | Network status detection        |
| flutter_local_notifications | Local notifications (WIP) |

---

## 🔧 Setup Instructions

### 1. 📥 Clone the Repo

### 2. 🔌 Install Flutter Dependencies

```bash
flutter pub get
```

---

### 3. 🔥 Firebase Setup

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a project → Enable **Authentication → Google Sign-In**
3. Enable **Firestore Database**
4. Go to **Project Settings → General → Add app**
   - For Android: use your package name `com.example.todo_app`
   - Download `google-services.json` → Place in `android/app/`
   - For Web: Copy the config and paste into `firebase_options.dart` (already included)

---

### 4. 💾 Hive Setup (Offline Support)

- Hive is used to persist tasks locally even when offline
- Tasks will sync automatically once logged in and network is available

```bash
flutter packages pub run build_runner build
```

> This will generate the Hive TypeAdapters.

---

## ⚡ Run on Device or Emulator

```bash
flutter run
```

> Optionally, connect your Android phone and run:

```bash
flutter run --release
```

---

## 📱 Build APK for Installation

```bash
flutter build apk --release
```

Your APK will be available at:

```
build/app/outputs/flutter-apk/app-release.apk
```

---

## 🔄 Sync & Conflict Resolution

- On login:
  - Firestore tasks are synced to Hive
  - Hive tasks marked `isSynced=false` are pushed to Firestore
- If the same task exists on both but with different `updatedAt`, the latest wins

---

## 🔔 Push Notifications (Coming Soon)

We will use:

- `flutter_local_notifications`
- Scheduled reminders for tasks
- Notifications on task due

> To enable, uncomment `NotificationService.init()` in `main.dart` after setup.

---

## 🧪 Testing Tips

- Disable Wi-Fi → test offline mode
- Create a task while offline → it syncs on next login
- Edit same task on two devices → latest `updatedAt` wins

---

## 📱 APK Download

Download the working APK from the link below:

➡️ [Download DailyFocus APK](https://drive.google.com/file/d/1wjtwapNLJdV6yasnScB-3vURUHhOVbT6/view?usp=sharing)

---

## 👤 Developer

Built with ❤️ by [Roobha](https://github.com/Roobha)

---

## 📝 License

MIT © 2025 DailyFocus

This project is a part of a hackathon run by
https://www.katomaran.com
