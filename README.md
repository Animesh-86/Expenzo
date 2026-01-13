# Expenzo - Smart Expense Tracker

A comprehensive Flutter-based expense tracking application that helps you manage your finances with intelligent features like SMS expense extraction, budget management, and detailed analytics.

##  Features

### Core Functionality
- **Expense Tracking**: Manually add and categorize expenses
- **SMS Auto-Extraction**: Automatically extract expenses from bank SMS messages
- **Budget Management**: Set and monitor spending limits by category
- **Recurring Expenses**: Track and manage regular payments
- **Analytics & Reports**: Visual charts and insights into spending patterns
- **Category Management**: Customize expense categories

### Advanced Features
- **Firebase Authentication**: Secure login and signup with Google Sign-In
- **Local Notifications**: Budget alerts and reminders
- **Offline Storage**: Hive database for local data persistence
- **Multi-platform Support**: Android, iOS, Web, Windows, macOS, Linux
- **Profile Management**: User profile customization
- **Data Export**: Export expense history and reports

### Smart SMS Processing
- **Bank Integration**: Supports major Indian banks (HDFC, ICICI, SBI, Axis, etc.)
- **UPI Detection**: Automatically detects UPI transactions
- **Amount Extraction**: Intelligent parsing of transaction amounts
- **Duplicate Prevention**: Prevents duplicate expense entries


## Technology Stack

- **Framework**: Flutter 3.8.1+
- **State Management**: Provider
- **Local Database**: Hive
- **Authentication**: Firebase Auth
- **Cloud Services**: Firebase Core, Firebase Messaging
- **Charts**: FL Chart
- **Notifications**: Flutter Local Notifications
- **SMS Processing**: Telephony
- **Permissions**: Permission Handler
- **Image Handling**: Image Picker
- **Storage**: Shared Preferences, Path Provider
- **UI Components**: Introduction Screen, Grouped List
- **Utilities**: UUID, Intl

## Prerequisites

- Flutter SDK 3.8.1 or higher
- Dart SDK
- Android Studio / VS Code
- Firebase project setup
- Google Services configuration

##  Installation & Setup

### 1. Clone the Repository
```bash
git clone https://github.com/Animesh-86/Expenzo
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Firebase Setup
1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Enable Authentication and add Google Sign-In
3. Download `google-services.json` and place it in `android/app/`
4. Configure Firebase for your platforms (iOS, Web, etc.)

### 4. Generate Code
```bash
flutter packages pub run build_runner build
```

### 5. Run the Application
```bash
flutter run
```

##  Project Structure

```
expenzo/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── theme.dart               # App theme configuration
│   ├── models/                  # Data models
│   │   ├── expense.dart
│   │   ├── category.dart
│   │   ├── budget.dart
│   │   └── recurring_expense.dart
│   ├── providers/               # State management
│   │   ├── expenses_provider.dart
│   │   ├── categories_provider.dart
│   │   ├── budgets_provider.dart
│   │   └── recurring_expenses_provider.dart
│   └── screens/                 # UI screens
│       ├── splash_screen.dart
│       ├── login_signup_screen.dart
│       ├── expense_entry_screen.dart
│       ├── expense_history_screen.dart
│       ├── analytics_screen.dart
│       ├── budget_management_screen.dart
│       ├── category_management_screen.dart
│       ├── recurring_expenses_screen.dart
│       └── profile_screen.dart
├── assets/
│   └── images/
│       └── splash.png
└── pubspec.yaml
```

##  Permissions Required

- **SMS Access**: For automatic expense extraction from bank messages
- **Storage**: For saving app data and images
- **Notifications**: For budget alerts and reminders
- **Camera/Gallery**: For profile picture upload

##  Key Features Explained

### SMS Expense Extraction
The app automatically scans incoming SMS messages from banks and financial institutions, extracts transaction amounts, and creates expense entries. It supports:
- Major Indian banks and UPI services
- Amount parsing with currency symbols
- Duplicate detection
- Category assignment

### Budget Management
- Set monthly budgets by category
- Real-time spending tracking
- Budget alerts and notifications
- Visual progress indicators

### Analytics Dashboard
- Spending trends and patterns
- Category-wise expense breakdown
- Monthly/yearly comparisons
- Interactive charts and graphs

##  Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

##  Support

If you encounter any issues or have questions:
1. Check the [Issues](https://github.com/Animesh-86/Expenzo/issues) page
2. Create a new issue with detailed information
3. Contact the development team

##  Version History

- **v1.0.0**: Initial release with core expense tracking features
- SMS auto-extraction
- Budget management
- Analytics dashboard
- Multi-platform support

---

**Expenzo** - Making expense tracking smarter and more efficient! 💰📊
