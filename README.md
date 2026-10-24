# Git-Inside
A Dormitory Tenant and Landlord Management System

## Project Scope
Git-Inside is a cross-platform app (mobile, web, desktop) that connects dormitory tenants and landlords, and also lets prospective tenants make inquiries.

**Tenants** can view their room and lease details, monitor their balance, due dates, and payment history, upload proof of payment, report repair issues with photos, and receive announcements.

**Landlords** can manage rooms, tenants, payments, announcements, and maintenance reports, and see who has paid, who is overdue, and which rooms are occupied or need repair.

**Prospective tenants (visitors)** can ask the chatbox about available rooms, rates, and house rules without an account, and leave a name and contact number for the landlord.

**AI Dorm Manager:** a chatbox that answers questions using live system data depending on the user's role. It suggests the category and urgency of repair reports and generates monthly summaries. The AI never changes data on its own: every action is shown as a confirmation first and only runs after the user approves it.

The system runs on a local development server (localhost). Online payment gateways, SMS/email notifications, and public deployment are out of scope.

## Tech Stack
- Frontend: Flutter (Dart), one codebase for mobile, web, and desktop
- Backend: Node.js, Express, Sequelize (REST API with JWT and role-based access)
- Database: MySQL (XAMPP)
- AI: Claude API, called only from the backend

## Repository Structure
- `backend/`: Node.js, Express, MySQL (API on http://localhost:3000)
- `frontend/`: Flutter (mobile, web, desktop) - in development

Backend and frontend are kept in separate folders, run independently, and never share code.

## Team
**Team name:** Git Git Aw - CS-B | **Group:** 3
**Submitted to:** Sir Henzon Paul Dionsay

- Team Leader: Karl Capilitan (main), Jessa Languido (support)
- Project Manager: Jannyl Santillas (main), Kent Dampayla (support), Lynde Narvaez (support)
- Developer: Jessa Languido (main), Karl Capilitan (support)
- QA: Lynde Narvaez (main), Kent Dampayla (support), Jannyl Santillas (support)

## Setup Instructions
1. Install Git, Node.js (LTS, version 18 or newer), XAMPP (MySQL), Flutter SDK, VS Code, and Postman.
2. Clone: `git clone https://github.com/Git-Git-Aw/git-it-done.git`
3. Set your Git name and email:
   `git config --global user.name "Your Name"`
   `git config --global user.email "you@example.com"`

**Backend**
1. Start MySQL in XAMPP. Create the database and tables by importing `backend/database/schema.sql` (phpMyAdmin: Import tab), or from the `backend/` folder run:
   `cmd /c "C:\xampp\mysql\bin\mysql.exe -u root < database\schema.sql"`
2. Open the `backend/` folder and run `npm install`.
3. Copy `.env.example` to `.env` and fill in your MySQL details (XAMPP default: user `root`, empty password), a long `JWT_SECRET`, and the `ANTHROPIC_API_KEY` for the AI feature. Never commit `.env`.
4. Optional demo data (this wipes the tables): `npm run seed`
5. Run `npm run dev`, then open http://localhost:3000/api/health to check.

**Frontend** (in development)
1. Open the `frontend/` folder and run `flutter pub get`.
2. Make sure the backend is running, then run `flutter run -d chrome` (or use an emulator or desktop). An Android emulator reaches the backend at `http://10.0.2.2:3000`, not `localhost`.

## Contribution Guide
1. Never push directly to `main`. It is protected and only receives merged Pull Requests.
2. `develop` is the integration branch where active work happens. Create a `feature/<name>` or `bugfix/<name>` branch from `develop` for each task.
3. Commit your changes and open a Pull Request to `develop`.
4. Another member must approve the Pull Request (1 approval required).
5. Merge after approval.
6. Keep backend and frontend code in their own folders.
