# 🏢 HRM ERP — Flutter + Supabase

Full-stack Employee Management ERP with CRM and Payroll for Android & iOS.

---

## ⚡ Quick Start (5 Steps)

### 1. Create Supabase Project
1. Go to [supabase.com](https://supabase.com) → New Project (free)
2. Copy your **Project URL** and **anon public key** from Settings → API

### 2. Run Database Migrations
In Supabase Dashboard → SQL Editor, paste and run **in order**:
```
supabase/001_hrm_schema.sql   ← Core HR tables
supabase/002_crm_schema.sql   ← CRM tables
```

### 3. Configure Supabase in Flutter
In `lib/main.dart`, replace:
```dart
url: 'https://YOUR_PROJECT_ID.supabase.co',
anonKey: 'YOUR_ANON_KEY_HERE',
```

Or use `--dart-define` at build time (recommended):
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGci...
```

### 4. Install Dependencies & Generate Code
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### 5. Run the App
```bash
flutter run                    # default device
flutter run -d android         # Android emulator
flutter run -d ios             # iOS simulator
```

---

## 📁 Project Structure

```
lib/
├── main.dart                          # App entry, Supabase init
├── core/
│   ├── constants/app_colors.dart      # Brand colors
│   ├── router/app_router.dart         # GoRouter + auth guards
│   └── theme/app_theme.dart           # Material 3 theme
│
├── presentation/
│   ├── providers/all_providers.dart   # All Riverpod providers
│   ├── shared/widgets/
│   │   └── main_shell.dart            # Bottom nav shell
│   └── modules/
│       ├── auth/                      # Splash + Login
│       ├── dashboard/                 # KPIs + fl_chart analytics
│       ├── employees/                 # List, Detail, Form
│       ├── attendance/                # Clock-in/out, calendar
│       ├── leave/                     # Request, approval workflow
│       ├── payroll/                   # Runs, payslip + PDF
│       └── crm/                       # Leads, pipeline, clients
│
supabase/
├── 001_hrm_schema.sql                 # 12 core HR tables + RLS
└── 002_crm_schema.sql                 # CRM tables + triggers
```

---

## 🗄️ Database Tables

| Table | Purpose |
|---|---|
| `employees` | Core employee records |
| `departments` | Org structure |
| `user_roles` | admin/hr/manager/employee |
| `attendance` | Daily clock-in/out + computed hours |
| `leave_types` | Annual, Sick, Casual, etc. |
| `leave_balances` | Per-employee yearly balance |
| `leave_requests` | Request + approval workflow |
| `salary_structures` | Per-employee pay components |
| `payroll_runs` | Monthly payroll batches |
| `payslips` | Individual computed payslips |
| `holidays` | Public holiday calendar |
| `employee_documents` | File uploads via Supabase Storage |
| `crm_leads` | Sales pipeline leads |
| `crm_lead_activities` | Call/email/meeting logs |
| `crm_clients` | Converted clients |
| `crm_tasks` | Follow-up tasks |

---

## 🔐 Role-Based Access

| Feature | Employee | Manager | HR | Admin |
|---|---|---|---|---|
| View own profile | ✅ | ✅ | ✅ | ✅ |
| View all employees | ❌ | Team | ✅ | ✅ |
| Approve leave | ❌ | ✅ | ✅ | ✅ |
| Run payroll | ❌ | ❌ | ✅ | ✅ |
| View own payslip | ✅ | ✅ | ✅ | ✅ |
| CRM access | ❌ | ❌ | ✅ | ✅ |
| System settings | ❌ | ❌ | ❌ | ✅ |

---

## 🧩 Modules

### ✅ Completed
- Auth (login, splash, session guard, role detection)
- GoRouter with auth guards and shell route
- All Riverpod providers (auth, employees, attendance, leave, payroll, CRM, dashboard)
- Employee CRUD (list, detail, add, edit)
- Attendance (clock-in/out, calendar heatmap, monthly summary)
- Leave (apply, balance tracker, manager approval workflow)
- Payroll (monthly run engine, payslip detail, PDF generation & share)
- Dashboard (KPI cards, bar chart, line chart, pie chart — fl_chart)
- CRM (lead list, pipeline kanban, lead form, client list, auto-client on won)

### 🔜 Recommended Next
- Push notifications (Firebase Cloud Messaging)
- Offline mode with Hive cache
- Employee document upload (Supabase Storage)
- Org chart view
- Payroll bank export (CSV)
- CRM task management
- Reports & exports (Excel)
- Multi-company support

---

## 📦 Key Dependencies

| Package | Version | Purpose |
|---|---|---|
| `supabase_flutter` | ^2.5.0 | Backend (DB, Auth, Storage) |
| `flutter_riverpod` | ^2.5.1 | State management |
| `go_router` | ^13.2.0 | Navigation + auth guards |
| `fl_chart` | ^0.68.0 | Analytics charts |
| `pdf` + `printing` | ^3.11 / ^5.13 | Payslip PDF generation |
| `freezed` | ^2.5.2 | Immutable models |
| `hive_flutter` | ^1.1.0 | Local offline cache |
| `image_picker` | ^1.1.2 | Employee photo upload |

---

## 🔧 Code Generation

Run after any model/provider change:
```bash
# One-time
dart run build_runner build --delete-conflicting-outputs

# Watch mode (auto-regenerate on save)
dart run build_runner watch --delete-conflicting-outputs
```

---

## 🚀 Build for Production

```bash
# Android APK
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://xxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...

# Android App Bundle (Play Store)
flutter build appbundle --release

# iOS (requires Mac + Xcode)
flutter build ios --release
```

---

## 🆓 Supabase Free Tier

| Resource | Free Limit |
|---|---|
| Database | 500 MB |
| Auth users | Unlimited |
| Storage | 1 GB |
| Realtime | 200 concurrent connections |
| Edge Functions | 500K calls/month |
| API requests | Unlimited |

More than enough for a team of 200+ employees.

---

*Built with Flutter 3.x + Supabase + Riverpod 2.x + GoRouter + fl_chart*
