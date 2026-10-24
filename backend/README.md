# Git-Inside Backend (Node.js + Express + Sequelize + MySQL)

REST API for the Git-Inside dormitory tenant and landlord management system, including the AI Dorm Manager (Claude API, called only from this backend).

## Setup (XAMPP)
1. Install Node.js (LTS, 18 or newer) and XAMPP. Start **MySQL** in the XAMPP Control Panel.
2. Open phpMyAdmin (http://localhost/phpmyadmin), click **Import**, choose `database/schema.sql`, click **Import**. This creates the `git_inside` database and its tables.
3. In this folder run `npm install`.
4. Copy `.env.example` to `.env` and fill it in:
   - `DB_USER=root` and an empty `DB_PASS` (XAMPP default)
   - `JWT_SECRET`: a long random string
   - `ANTHROPIC_API_KEY`: needed only for the AI chatbox
5. Optional demo data (**wipes the tables**): `npm run seed`
6. Start: `npm run dev` (auto-restart) or `npm start`
7. Check: http://localhost:3000/api/health

The server listens on `0.0.0.0:3000`, so a phone on the same Wi-Fi can reach it at `http://<your-PC-IP>:3000`. The Android emulator uses `http://10.0.2.2:3000`.

## Demo accounts (after `npm run seed`)
| Role | Email | Password |
|---|---|---|
| Landlord | landlord@gitinside.test | Landlord123! |
| Tenant | ana@gitinside.test (also ben@, carla@) | Tenant123! |
| Pending tenant | pending@gitinside.test | Tenant123! (cannot log in until approved) |

## Authentication
Send `Authorization: Bearer <token>` on every request except register, login, forgot/reset password, `GET /api/dorm-info`, and the AI chat in visitor mode. Tokens last 8 hours.

## Endpoints
| Module | Method + Path | Who |
|---|---|---|
| Auth | POST /api/auth/register, /login, /logout, /forgot-password, /reset-password, /change-password; GET /api/auth/me | public / any |
| Tenants | GET/POST /api/tenants, GET/PUT /api/tenants/:id, PATCH /:id/approve, /:id/archive | landlord |
| Rooms | GET/POST /api/rooms, GET/PUT /:id, PATCH /:id/archive, /:id/restore | landlord |
| Leases | GET/POST /api/leases, PUT /:id, PATCH /:id/end | landlord |
| Payments (tenant) | GET /api/payments/mine; POST /api/payments/:id/proof (multipart field `proof`) | tenant |
| Payments (landlord) | GET /api/payments?status=paid\|unpaid\|overdue\|pending_confirmation&period=YYYY-MM; POST /generate; PATCH /:id/record, /:id/confirm, /:id/reject | landlord |
| Maintenance | POST /api/maintenance (multipart field `photo`), GET /mine | tenant |
| | GET /api/maintenance?roomId=&status=; PATCH /:id {status, remarks, assignedTo} | landlord |
| Announcements | GET /api/announcements (landlord: `?archived=true` includes archived); POST, PUT /:id, PATCH /:id/archive, /:id/restore | any / landlord |
| Notifications | GET /api/notifications; PATCH /:id/read, /read-all | any |
| Dashboards | GET /api/dashboard/tenant; GET /api/dashboard/landlord?period=YYYY-MM | tenant / landlord |
| Reports | GET /api/reports/monthly?month=YYYY-MM&format=csv\|json | landlord |
| Sync | GET /api/sync?since=ISO | any |
| Dorm info | GET /api/dorm-info (public); PUT /api/dorm-info | public / landlord |
| Inquiries | GET /api/inquiries?status=; PATCH /api/inquiries/:id {status: new\|contacted} | landlord |
| AI chat | POST /api/chat; POST /api/chat/actions/:id/confirm, /cancel; POST /api/chat/summary | visitor / tenant / landlord (summary: landlord) |

### AI Dorm Manager
- `POST /api/chat` body: `{ "messages": [{ "role": "user", "content": "..." }] }`. The last 12 messages are kept, each up to 1000 characters, and the list must end with a user message.
- Works without a token (visitor mode, public information only) or with a token (tenant or landlord mode).
- Response: `{ role, reply, pendingActions: [{ id, tool, summary, expiresAt }] }`.
- **The AI never changes data on its own.** Every write action (bill generation, recording a payment, updating a maintenance report, posting an announcement, submitting a repair report, leaving a visitor inquiry) is only proposed. The user must confirm it with `POST /api/chat/actions/:id/confirm` (or cancel with `/cancel`). Pending actions expire after 15 minutes.
- Tools are limited by role in code: tenants only reach their own data, visitors only reach public dorm information.
- Rate limits per 10 minutes: 20 messages for visitors, 60 for logged-in users (`AI_LIMIT_VISITOR`, `AI_LIMIT_USER` in `.env`).
- Errors: 429 too many messages, 503 no `ANTHROPIC_API_KEY`, 502 the Claude API could not be reached (check the internet connection).

## Testing
- Automated logic tests (no database or internet needed): `npm test`
- API tests in Postman: import `postman/Git-Inside.postman_collection.json`, run **01 Auth > Login - Landlord** and **Login - Tenant Ana** first (tokens are saved automatically), then the other requests.

## Notes
- **No hard deletes.** Records are archived instead of deleted: tenants (`archive`), rooms (`archive` / `restore`), announcements (`archive` / `restore`), and leases (`end`). Nothing is removed from the database through the API.
- `forgot-password` returns the reset token in the response only when `NODE_ENV` is not `production` (email delivery is out of scope).
- Never commit `.env`. Uploaded images go to `uploads/` and are ignored by Git.
