# Frontend

Flutter client for Talk to Quran. Firebase Auth for sign-in, a single chat screen that talks to the Flask backend.

## Setup

```bash
flutter pub get
```

Firebase is already configured via `lib/firebase_options.dart`. If you fork this into your own Firebase project, regenerate it with `flutterfire configure`.

## Run

```bash
flutter run              # attached device / emulator
flutter analyze          # lint
flutter test             # run widget tests
flutter build apk        # Android release build
```

## Point the app at your backend

`_apiUrl` in `lib/screens/chat_screen.dart` is hardcoded. Update it to match where the backend is reachable:

| Setup                             | URL                                |
| --------------------------------- | ---------------------------------- |
| Android emulator → host machine   | `http://10.0.2.2:8000/chat`        |
| iOS simulator → host machine      | `http://localhost:8000/chat`       |
| Physical device via ngrok tunnel  | `https://<sub>.ngrok-free.dev/chat` |

When using ngrok, keep the `ngrok-skip-browser-warning: 69420` header on the request so ngrok's interstitial page doesn't break the response.

## Structure

```
lib/
├── main.dart                    # Firebase init + MaterialApp
├── firebase_options.dart        # generated
├── screens/
│   ├── splash_screen.dart
│   ├── auth_gate.dart           # splash → login or chat based on FirebaseAuth stream
│   ├── login_screen.dart
│   ├── register_screen.dart
│   └── chat_screen.dart         # conversation UI + HTTP call to backend
└── services/
    └── auth_service.dart        # thin wrapper around FirebaseAuth
```

The backend is stateless, so `chat_screen.dart` rebuilds the entire conversation history from `_messages` on every send.
