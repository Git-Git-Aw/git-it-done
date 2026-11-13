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
- Responsive: side menu on wide screens (web/desktop), bottom bar on phones (with a "More" menu)

## Part 2 (tenant features and AI chat)
- Payments: billing statements, payment history, upload proof of payment (gallery or camera)
- Maintenance: new report with category, urgency, description and photo; list with status
- AI Dorm Manager chat for tenants and landlords, plus a visitor chat on the login screen ("Ask about the dorm").
  The AI only proposes changes. They run only after you press Confirm on the card.

## Part 3 (landlord features and offline cache)
Landlord tabs: Dashboard (with "Generate AI summary"), Payments, Maintenance, AI Manager, Rooms, Tenants, Announcements, Inquiries, Reports, Dorm info, Notifications, Profile.
- Payments: month and status filters, generate bills, record cash/other payments, confirm or reject uploaded receipts
- Maintenance: filter by room and status, update status, assignee and remarks
- Rooms and tenants: add, edit, archive, restore, approve, assign a room, edit or end a lease (nothing is hard deleted)
- Announcements: post, edit, pin, archive, restore, show archived
- Inquiries from the visitor chat, dorm information, monthly report with CSV export (a download on web; copied to the clipboard on Windows and Android)

### Offline cache (Hive)
- Every successful GET answer is saved on the device in one Hive box (`hive_ce` and `hive_ce_flutter`, the maintained fork of Hive). It is kept per account and removed on logout.
- When the server cannot be reached, screens show the saved copy and a banner says "You are offline" with a Retry button. Changes (POST, PUT, PATCH) are never saved offline: the app says "Your change was NOT saved".
- After login the app asks `GET /api/sync?since=...` and refreshes the saved lists. Profile > Offline data shows the last sync and has a "Sync now" button.
- The login token and user stay in `shared_preferences`, not in Hive.

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
