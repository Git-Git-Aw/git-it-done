# Git-Inside Frontend (Flutter)

Flutter app for tenants and landlords (web, Windows, Android from one codebase).
The backend lives in `../backend` and must be running first (http://localhost:3000).

## Run
1. Start MySQL (XAMPP) and the backend (`npm run dev` inside `backend/`).
2. In this folder:
   - `flutter pub get`
   - `flutter run -d chrome`
3. Demo logins (after `npm run seed` in the backend):
   - Landlord: landlord@gitinside.test / Landlord123!
   - Tenant: ana@gitinside.test / Tenant123!

## Backend address
Default is `http://localhost:3000`. Use another address with:
`flutter run -d chrome --dart-define=API_BASE_URL=http://192.168.1.10:3000`
(the Android emulator reaches your PC at `http://10.0.2.2:3000`).

## What works so far (Part 1)
- Login, register (waits for landlord approval), forgot/reset password, change password, log out
- Tenant dashboard: balance, next due date, room and lease, latest announcements
- Landlord dashboard: collections, outstanding balance, occupancy rate, paid / awaiting / unpaid / overdue counts, rooms needing maintenance, month selector
- Announcements list, notifications (unread badge, mark read, mark all read), profile
- Responsive: side menu on wide screens (web/desktop), bottom bar on phones

Coming in Part 2 (tenant features and AI chat) and Part 3 (landlord features and offline cache).

## Tests
`flutter test`

## Structure
- `lib/api/` HTTP client (adds the login token, turns errors into messages)
- `lib/models/` data classes that read the backend JSON
- `lib/state/` login state (`AuthController`)
- `lib/screens/auth/` login, register, forgot password
- `lib/screens/home/` the signed-in app (shell, dashboards, announcements, notifications, profile)
- `lib/widgets/` shared widgets
- `lib/utils/` formatting helpers
- `assets/logo.png` app logo
