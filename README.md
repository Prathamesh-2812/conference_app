# Conference Management Platform

A production-oriented starter for a multi-conference platform inspired by the supplied DPU/AIU conference screenshots.

## Stack
- Flutter mobile app (Android + iOS)
- Node.js + Express REST API
- MySQL 8
- React/Vite admin web app
- Socket.IO-ready backend
- JWT authentication

## Modules
Authentication, dashboard, schedule, speakers, profile, accommodation, transport, duty roster, liaison, notices, real-time chat foundation, gallery, QR ID, attendance, meals, feedback, polls, certificates, reports and role-based admin.

## Quick start

### 1. Database
```bash
mysql -u root -p < backend/sql/schema.sql
```

### 2. API
```bash
cd backend
cp .env.example .env
npm install
npm run dev
```

### 3. Admin
```bash
cd admin_web
npm install
npm run dev
```

### 4. Flutter
Create platform folders once on a machine with Flutter installed:
```bash
cd flutter_app
flutter create .
flutter pub get
flutter run
```

Set `API_BASE_URL` in `lib/config.dart` for a physical device/emulator.

## Demo credentials
Seeded in SQL:
- Admin: admin@conference.local / Admin@123
- Participant: participant@conference.local / Demo@123

Change these credentials before production.

## Production checklist
Configure HTTPS, secrets, object storage, Firebase/APNs, payment gateway, email/SMS provider, backups, monitoring, rate limiting, audit retention and privacy/consent policies.
