import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, debugPrint;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'theme.dart';

// Models
import 'models/expense.dart';
import 'models/category.dart';
import 'models/budget.dart';
import 'models/recurring_expense.dart';
import 'models/saving_goal.dart';

// Providers
import 'providers/expenses_provider.dart';
import 'providers/categories_provider.dart';
import 'providers/budgets_provider.dart';
import 'providers/recurring_expenses_provider.dart';
import 'providers/saving_goals_provider.dart';

// Screens
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

// SMS scanning functionality removed to reduce app size
// Can be re-enabled by uncommenting telephony dependency and this function

@pragma('vm:entry-point')
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
  Hive.registerAdapter(SavingGoalAdapter());
  // Helper to open boxes with recovery
  Future<void> openBoxWithRecovery<T>(String name) async {
    try {
      await Hive.openBox<T>(name);
    } catch (e) {
      debugPrint('Failed to open box $name: $e. Attempting recovery...');
      try {
        // If opening fails (corruption), delete and try again
        await Hive.deleteBoxFromDisk(name);
        await Hive.openBox<T>(name);
        debugPrint('Box $name recovered (data cleared).');
      } catch (e2) {
        debugPrint('Critical: Could not recover box $name: $e2');
      }
    }
  }

  try {
    await openBoxWithRecovery<Expense>('expenses');
    await openBoxWithRecovery<Category>('categories');
    await openBoxWithRecovery<Budget>('budgets');
    await openBoxWithRecovery<RecurringExpense>('recurring_expenses');
    await openBoxWithRecovery<SavingGoal>('saving_goals');
  } catch (e, st) {
    debugPrint('General error during Hive box opening: $e\n$st');
  }

  // Initialize notifications
  final bool isAndroid =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  final InitializationSettings initializationSettings = isAndroid
      ? const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        )
      : const InitializationSettings();
  try {
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  } catch (e) {
    // Ignore on unsupported platforms
    debugPrint('Local notifications init skipped/failed: $e');
  }

  // Defer time zone initialization until after first frame to avoid startup jank

  // Ensure default categories are present before the UI
  final categoriesProvider = CategoriesProvider();
  await categoriesProvider.initializeDefaults();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ExpensesProvider()),
        ChangeNotifierProvider(create: (_) => categoriesProvider),
        ChangeNotifierProvider(create: (_) => BudgetsProvider()),
        ChangeNotifierProvider(create: (_) => RecurringExpensesProvider()),
        ChangeNotifierProvider(create: (_) => SavingGoalsProvider()),
      ],
      child: const ExpenzoApp(),
    ),
  );
}

class ExpenzoApp extends StatefulWidget {
  const ExpenzoApp({super.key});

  @override
  State<ExpenzoApp> createState() => _ExpenzoAppState();
}

class _ExpenzoAppState extends State<ExpenzoApp> {
  bool _minSplashElapsed = false;
  bool _initCompleted = false;
  bool _forceContinue = false;
  bool _firebaseReady = false;
  String? _firebaseError;

  Future<void> _initializeServices() async {
    final bool isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final bool isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final bool isMobile = isAndroid || isIOS;
    try {
      if (isMobile) {
        debugPrint('Initializing Firebase...');
        try {
          await Firebase.initializeApp().timeout(const Duration(seconds: 8));
          if (mounted) {
            setState(() {
              _firebaseReady = true;
              _firebaseError = null;
            });
          }
        } on TimeoutException catch (_) {
          debugPrint('Firebase initialization timed out');
          if (mounted) {
            setState(() {
              _firebaseReady = false;
              _firebaseError = 'Firebase init timed out';
            });
          }
        }
        // Initialize time zones after Firebase
        try {
          tz.initializeTimeZones();
        } catch (e) {
          debugPrint('Time zone init failed/skipped: $e');
        }
        debugPrint('Configuring FCM...');
        try {
          FirebaseMessaging.onBackgroundMessage(
            _firebaseMessagingBackgroundHandler,
          );
          final fcm = FirebaseMessaging.instance;
          await fcm.requestPermission();
          await fcm.setAutoInitEnabled(true);
        } catch (e) {
          debugPrint('FCM setup failed/skipped: $e');
        }

        if (isAndroid) {
          const AndroidNotificationChannel channel = AndroidNotificationChannel(
            'high_importance_channel',
            'High Importance Notifications',
            description: 'This channel is used for important notifications.',
            importance: Importance.high,
          );
          try {
            await flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.createNotificationChannel(channel);
          } catch (e) {
            debugPrint('Notification channel creation failed/skipped: $e');
          }

          try {
            FirebaseMessaging.onMessage.listen((RemoteMessage message) {
              final RemoteNotification? notification = message.notification;
              final AndroidNotification? android =
                  message.notification?.android;
              if (notification != null && android != null) {
                const String channelId = 'high_importance_channel';
                const String channelName = 'High Importance Notifications';
                const String channelDescription =
                    'This channel is used for important notifications.';
                flutterLocalNotificationsPlugin.show(
                  notification.hashCode,
                  notification.title,
                  notification.body,
                  const NotificationDetails(
                    android: AndroidNotificationDetails(
                      channelId,
                      channelName,
                      channelDescription: channelDescription,
                      icon: '@mipmap/ic_launcher',
                    ),
                  ),
                );
              }
            });
          } catch (e) {
            debugPrint('onMessage listener failed/skipped: $e');
          }
        }
      } else {
        debugPrint('Skipping Firebase init on non-mobile platform');
      }
    } catch (e) {
      debugPrint('Service initialization error: $e');
      if (mounted) {
        setState(() {
          _firebaseReady = false;
          _firebaseError = e.toString();
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Start service initialization after first frame so splash renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServices().whenComplete(() {
        if (!mounted) return;
        setState(() {
          _initCompleted = true;
        });
      });
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _minSplashElapsed = true;
      });
    });

    // Watchdog to avoid getting stuck forever
    Future.delayed(const Duration(seconds: 10), () {
      if (!mounted) return;
      if (!_initCompleted) {
        debugPrint('Force continuing app initialization after timeout');
        setState(() {
          _forceContinue = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expenzo',
      theme: glassDarkTheme, // Use your custom dark theme
      home: !(_minSplashElapsed && (_initCompleted || _forceContinue))
          ? const SplashScreen()
          : _forceContinue
          ? const LoginSignUpScreen()
          : (!kIsWeb &&
                (defaultTargetPlatform == TargetPlatform.android ||
                    defaultTargetPlatform == TargetPlatform.iOS))
          ? (_firebaseReady
                ? StreamBuilder<User?>(
                    stream: FirebaseAuth.instance.authStateChanges(),
                    builder: (context, snapshot) {
                      print(
                        'StreamBuilder state: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, hasError: ${snapshot.hasError}',
                      );

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        print('Firebase still initializing, showing splash...');
                        return const SplashScreen();
                      }

                      if (snapshot.hasError) {
                        return Scaffold(
                          backgroundColor: Colors.black,
                          body: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.redAccent,
                                  size: 64,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Error initializing app',
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                  ),
                                  child: Text(
                                    '${snapshot.error}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _minSplashElapsed = false;
                                      _initCompleted = false;
                                      _forceContinue = false;
                                    });
                                    // Restart splash and initialization
                                    initState();
                                  },
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      if (snapshot.data == null) {
                        return const LoginSignUpScreen();
                      }

                      return const ExpenseHistoryScreen();
                    },
                  )
                : Scaffold(
                    backgroundColor: Colors.black,
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            color: Colors.blueAccent,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Finalizing setup...',
                            style: TextStyle(color: Colors.white70),
                          ),
                          if (_firebaseError != null) ...[
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Text(
                                _firebaseError!,
                                style: const TextStyle(color: Colors.redAccent),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ))
          : const LoginSignUpScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// REMOVED: The unused HomeScreen widget is now gone.
