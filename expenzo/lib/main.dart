import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ADDED: For persistent storage
import 'package:telephony/telephony.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'theme.dart';

// Models
import 'models/expense.dart';
import 'models/category.dart';
import 'models/budget.dart';
import 'models/recurring_expense.dart';

// Providers
import 'providers/expenses_provider.dart';
import 'providers/categories_provider.dart';
import 'providers/budgets_provider.dart';
import 'providers/recurring_expenses_provider.dart';

// Screens
import 'screens/expense_entry_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/login_signup_screen.dart';
import 'screens/expense_history_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> showBudgetNotification(String title, String body) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
        'budget_channel',
        'Budget Alerts',
        channelDescription: 'Notifications for budget limits',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
      );
  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    0,
    title,
    body,
    platformChannelSpecifics,
  );
}

// CHANGED: The function now handles its own state for the last scan time
Future<void> scanAndExtractSms(BuildContext context) async {
  final expensesProvider = Provider.of<ExpensesProvider>(
    context,
    listen: false,
  );
  final categoriesProvider = Provider.of<CategoriesProvider>(
    context,
    listen: false,
  );

  final telephony = Telephony.instance;
  final permissionGranted = await telephony.requestSmsPermissions ?? false;
  if (!permissionGranted) return;

  // ADDED: Use SharedPreferences to get the last scanned timestamp
  final prefs = await SharedPreferences.getInstance();
  final lastScannedMillis =
      prefs.getInt('lastScannedTimestamp') ??
      DateTime.now().subtract(const Duration(days: 2)).millisecondsSinceEpoch;
  final lastScanned = DateTime.fromMillisecondsSinceEpoch(lastScannedMillis);

  final smsList = await telephony.getInboxSms(
    columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
    filter: SmsFilter.where(
      SmsColumn.DATE,
    ).greaterThan(lastScanned.millisecondsSinceEpoch.toString()),
    sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
  );

  // Simple regex for amount and UPI/bank detection
  final amountRegex = RegExp(r'(?:INR|Rs\.?|₹)\s?([0-9,]+\.?[0-9]*)');
  final bankSenders = [
    'HDFCBK',
    'ICICIB',
    'SBIINB',
    'AXISBK',
    'KOTAKB',
    'PNBSMS',
    'CITIBK',
    'IDFCSB',
    'YESBNK',
    'PAYTM',
    'GOOGLE',
    'PNB',
    'BOIINB',
    'UPI',
    'FDRLBNK',
    'INDUSB',
    'IDBIBK',
    'CANBNK',
    'UNIONB',
    'BANKBARODA',
    'BOM',
    'MAHABANK',
    'KVBANK',
    'UCOBNK',
    'HSBC',
    'SCB',
    'CUBANK',
    'DBSBNK',
    'DCB',
    'RBLBNK',
    'BANDHAN',
    'AUFB',
    'SIB',
    'JKBANK',
    'KARNATAKA',
    'DENA',
    'VIJAYA',
    'ALLAHABAD',
    'ANDHRABANK',
    'CORPBANK',
    'SYNDICATE',
    'ORIENTAL',
    'UNITED',
    'CENTRAL',
    'INDIAN',
    'UJJIVAN',
    'EQUITAS',
    'NSDL',
    'FINCARE',
    'PAYZAPP',
    'AMEX',
    'CITI',
    'HSBC',
    'SBI',
    'ICICI',
    'HDFC',
    'AXIS',
    'KOTAK',
    'IDFC',
    'YES',
    'BOB',
    'PNB',
    'IDBI',
    'CANARA',
    'UNION',
    'BANK',
    'RBL',
    'DBS',
    'DCB',
    'BANDHAN',
    'AU',
    'SIB',
    'JKB',
    'KARNATAKA',
    'DENA',
    'VIJAYA',
    'ALLAHABAD',
    'ANDHRA',
    'CORP',
    'SYNDICATE',
    'ORIENTAL',
    'UNITED',
    'CENTRAL',
    'INDIAN',
    'UJJIVAN',
    'EQUITAS',
    'NSDL',
    'FINCARE',
    'PAYZAPP',
    'AMEX',
    'CITI',
    'HSBC',
  ];

  if (categoriesProvider.categories.isEmpty) {
    return; // Prevent crash if no categories
  }

  bool newExpensesAdded = false;
  for (final sms in smsList) {
    final sender = sms.address?.toUpperCase() ?? '';
    if (!bankSenders.any((b) => sender.contains(b))) continue;
    final body = sms.body ?? '';
    // Ensure the message indicates a debit/payment
    if (!body.toLowerCase().contains('debited') &&
        !body.toLowerCase().contains('spent') &&
        !body.toLowerCase().contains('paid')) {
      continue;
    }
    final match = amountRegex.firstMatch(body);
    if (match != null) {
      final amount = double.tryParse(match.group(1)!.replaceAll(',', ''));
      if (amount != null) {
        // Try to guess category
        String categoryId = categoriesProvider.categories.first.id;
        for (final cat in categoriesProvider.categories) {
          if (body.toLowerCase().contains(cat.name.toLowerCase())) {
            categoryId = cat.id;
            break;
          }
        }
        // Check for duplicate (same amount, date, and sender)
        final date = DateTime.fromMillisecondsSinceEpoch(sms.date ?? 0);
        final alreadyExists = expensesProvider.expenses.any(
          (e) =>
              (e.amount - amount).abs() < 0.01 &&
              e.date.difference(date).inHours.abs() < 2 &&
              e.description.contains(sender),
        );
        if (!alreadyExists) {
          expensesProvider.addExpense(
            Expense(
              id: '${sender}_${amount}_${date.millisecondsSinceEpoch}',
              amount: amount,
              category: categoryId,
              description: 'SMS: $sender',
              date: date,
            ),
          );
          newExpensesAdded = true;
        }
      }
    }
  }

  // ADDED: Update the timestamp after scanning completes
  if (newExpensesAdded) {
    await prefs.setInt(
      'lastScannedTimestamp',
      DateTime.now().millisecondsSinceEpoch,
    );
    print('SMS scan complete. New expenses added. Timestamp updated.');
  } else {
    print('SMS scan complete. No new expenses found.');
  }
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Optionally handle background messages
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(ExpenseAdapter());
  Hive.registerAdapter(CategoryAdapter());
  Hive.registerAdapter(BudgetAdapter());
  Hive.registerAdapter(RecurringExpenseAdapter());
  await Hive.openBox<Expense>('expenses');
  await Hive.openBox<Category>('categories');
  await Hive.openBox<Budget>('budgets');
  await Hive.openBox<RecurringExpense>('recurring_expenses');

  // Initialize notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  await Firebase.initializeApp();
  tz.initializeTimeZones();

  // Ensure default categories are present
  final categoriesProvider = CategoriesProvider();
  await categoriesProvider.initializeDefaults();

  // FCM setup
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  final fcm = FirebaseMessaging.instance;
  await fcm.requestPermission();
  await fcm.setAutoInitEnabled(true);

  // Local notification channel for FCM
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
  );
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;
    if (notification != null && android != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    }
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ExpensesProvider()),
        ChangeNotifierProvider(create: (_) => categoriesProvider),
        ChangeNotifierProvider(create: (_) => BudgetsProvider()),
        ChangeNotifierProvider(create: (_) => RecurringExpensesProvider()),
      ],
      child: const ExpenzoApp(),
    ),
  );
}

class ExpenzoApp extends StatelessWidget {
  const ExpenzoApp({super.key});

  @override
  Widget build(BuildContext context) {
    // REMOVED: The logic from addPostFrameCallback has been moved.
    return MaterialApp(
      title: 'Expenzo',
      theme: glassDarkTheme, // Use your custom dark theme
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          }
          if (snapshot.hasError) {
            return Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: Text(
                  'Error initializing app: ${snapshot.error}',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          // REMOVED: The problematic reload() call is gone.
          if (snapshot.data == null) {
            return const LoginSignUpScreen();
          }
          // The user is logged in, show the main screen
          return const ExpenseHistoryScreen();
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

// REMOVED: The unused HomeScreen widget is now gone.
