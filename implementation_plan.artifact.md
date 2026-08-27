# Implementation Plan - Dynamic Conference Management System

This plan outlines the architecture, current implementation status, and extension roadmap for the Conference Management System on your machine (`d:/conference_app`).

## Workspace Environment & Paths

- **Root Directory**: `d:/conference_app`
- **Backend API**: [backend](file:///d:/conference_app/backend) (Node.js Express + Socket.IO + MySQL)
- **Admin Portal**: [admin_web](file:///d:/conference_app/admin_web) (React + Vite Dashboard)
- **Mobile/Delegate App**: [flutter_app](file:///d:/conference_app/flutter_app) (Flutter Multi-platform)
- **Database**: MySQL 8.x running on `localhost:3306` (`conference_management`)

---

## Architectural & Modules Analysis

| Module / Phase | Backend ([server.js](file:///d:/conference_app/backend/src/server.js)) | Admin Web ([main.jsx](file:///d:/conference_app/admin_web/src/main.jsx)) | Mobile App ([main.dart](file:///d:/conference_app/flutter_app/lib/main.dart)) | Status |
| :--- | :--- | :--- | :--- | :--- |
| **1. Conference Details & Branding** | Details, Venue, Branding, Settings APIs (`/api/conference`, `/api/admin/conference/*`) | Full editable forms with live preview | Dynamic branding theme (colors, banner, welcome message) | ✅ Complete |
| **2. Participants Management** | CRUD, Registration, QR token generation (`/api/admin/participants`) | Table, filters, Add/Edit modals | Delegate profile & Digital QR ID card | ✅ Complete |
| **3. Speakers & Schedule** | CRUD for Speakers, Sessions, Halls (`/api/admin/speakers`, `/api/admin/sessions`, `/api/admin/halls`) | Management UI for speakers & schedule tracks | Interactive Day-wise Schedule & Speaker Bios | ✅ Complete |
| **4. Accommodation** | Hotels, Rooms, Room Allocations with conflict checks | Hotel/Room inventory & Participant allocation | Personal Accommodation & Check-in info | ✅ Complete |
| **5. Transport** | Vehicles, Drivers, Transport Assignments (`/api/admin/transport/*`) | Transport assignment & live driver allocation | Personal Pickup/Drop schedule & Driver contact | ✅ Complete |
| **6. Attendance & QR** | QR Scanner endpoint, Session attendance, Check-in | Live attendance stats & manual/scanner entry | Delegate QR display for fast scanning | ✅ Complete |
| **7. Notices & Emergency** | Notice broadcasting, Emergency Contacts API | Notice composer with role targeting | Notice board & Emergency helpline directory | ✅ Complete |
| **8. Photo Gallery** | Photo upload, album grouping (`/api/admin/photos`) | Album creation, photo upload, delete | Grid photo gallery & event albums | ✅ Complete |
| **9. Meals & Catering** | Meal schedule & Meal scan verification (`/api/admin/meals`) | Meal schedule editor & scan reports | Personal meal coupons & venue info | ✅ Complete |
| **10. Duty Roster** | Duties & Volunteer/Staff assignments | Assignment grid & role allocations | Personal Duty schedule & supervisor info | ✅ Complete |
| **11. Certificates** | Certificate generation, issue tracking, QR verification | Certificate management UI | Certificate view & download | ✅ Complete |
| **12. Chat & Real-Time** | Socket.IO messaging foundation (`/api/chat/*`) | Admin chat interface | Participant messaging foundation | ✅ Complete |

---

## Component Files

### Backend Layer
- [server.js](file:///d:/conference_app/backend/src/server.js): Core Express application, WebSocket server, and business logic.
- [db.js](file:///d:/conference_app/backend/src/db.js): MySQL connection pool and transaction helpers.
- [middleware.js](file:///d:/conference_app/backend/src/middleware.js): JWT auth verification, role-based access control (`roles()`), and centralized error handler.
- [schema.sql](file:///d:/conference_app/backend/sql/schema.sql): Complete database DDL and initial seeds.
- [seed.js](file:///d:/conference_app/backend/src/seed.js): Database seeder for demo credentials and sample data.

### Admin Web Layer
- [main.jsx](file:///d:/conference_app/admin_web/src/main.jsx): Single-page React application with role-aware navigation and management modules.
- [style.css](file:///d:/conference_app/admin_web/src/style.css): Responsive layout, sidebar navigation, modal styling, and data tables.

### Flutter Mobile App Layer
- [main.dart](file:///d:/conference_app/flutter_app/lib/main.dart): Multi-screen delegate app (Dashboard, QR Pass, Schedule, Transport, Stay, Notices, Gallery).
- [config.dart](file:///d:/conference_app/flutter_app/lib/config.dart): Environment and platform-aware API configuration.
- [api_service.dart](file:///d:/conference_app/flutter_app/lib/services/api_service.dart): Authenticated HTTP client with token handling and error formatting.

---

## Verification & Execution Guide

### 1. Database
```powershell
# MySQL (via XAMPP or native service on port 3306)
Get-Content backend\sql\schema.sql | & "C:\xampp\mysql\bin\mysql.exe" -u root
cd backend
npm run seed
```

### 2. Backend API
```powershell
cd backend
npm run dev
# Running on http://localhost:5000/api
```

### 3. Admin Web Portal
```powershell
cd admin_web
npm run dev
# Running on http://localhost:5173
```

### 4. Flutter App
```powershell
cd flutter_app
flutter run -d chrome    # For Web preview (http://localhost:3000)
flutter run              # For Android Emulator or physical device
```
