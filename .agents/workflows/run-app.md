---
description: How to run SpeakUp and access on mobile
---

To run the application and access it from your PC and mobile device, follow these steps:

### 1. Run the Backend
Open a terminal in the `backend` directory and run:
```powershell
.\VENV\Scripts\python.exe -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```
*Note: Using `--host 0.0.0.0` allows other devices on your Wi-Fi to connect.*

### 2. Run the Frontend
Open another terminal in the `apps/mobile_web_app` directory and run:
```powershell
$env:Path += ";C:\Users\Nauti\flutter\bin"
flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0
```

### 3. Access on Mobile
1. Ensure your mobile and PC are on the **same Wi-Fi network**.
2. Find your PC's IP address (it is currently **10.199.232.180**).
3. On your mobile phone browser, go to:
   `http://10.199.232.180:8080`

### 4. Update API Configuration (Crucial for Mobile)
For the mobile device to talk to the backend, you must update the `baseUrl` in `lib/core/constants.dart` to use your IP address instead of `localhost`:

```dart
// lib/core/constants.dart
static const String baseUrl = 'http://10.199.232.180:8000';
```
*(If you only use the PC browser, `localhost` is fine.)*
