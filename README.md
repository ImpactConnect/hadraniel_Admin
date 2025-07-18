# Hadraniel Frozen Foods Admin App

A Flutter desktop application for managing Hadraniel Frozen Foods' retail operations with offline-first capabilities.

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (^3.8.1)
- Dart SDK
- Supabase Account
- SQLite

### 📥 Installation

1. Clone the repository:
```bash
git clone [repository-url]
cd hadraniel_admin
```

2. Install dependencies:
```bash
flutter pub get
```

3. Set up environment variables:
- Create a `.env` file in the `lib/env` directory
- Add your Supabase credentials:
```env
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

4. Run the app:
```bash
flutter run -d windows
```

## 🏗️ Project Structure

```
lib/
├── main.dart
├── core/
│ ├── database/
│ │ └── database_helper.dart
│ ├── services/
│ │ ├── supabase_service.dart
│ │ ├── sync_service.dart
│ │ └── auth_service.dart
│ ├── models/
│ │ └── profile_model.dart
│ └── utils/
│   └── formatters.dart
├── screens/
│ ├── auth/
│ ├── dashboard/
│ ├── outlets/
│ ├── reps/
│ ├── customers/
│ ├── sales/
│ ├── stock/
│ └── products/
└── widgets/
```

## 🔄 Sync Strategy

- Initial sync on first successful login
- Local SQLite database for offline operations
- Automatic sync when online
- Manual sync option
- Conflict resolution handling

## 🔐 Security

- Secure credential storage using flutter_secure_storage
- Environment variables for sensitive data
- Role-based access control
- Session management

## 🧪 Testing

Run tests using:
```bash
flutter test
```

## 📚 Documentation

For detailed documentation about the project architecture and features, refer to:
- [Project Overview](admin_app_project_description.md)
- [Phase 2: User Profile Sync](phase_2_user_profile_sync.md)
#   h a d r a n i e l _ A d m i n  
 #   h a d r a n i e l _ A d m i n  
 