import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:math';
import 'dart:ui';
import 'firebase_options.dart';
import 'screens/glucosa_screen.dart';
import 'screens/presion_arterial.dart';
import 'screens/oxigenacion_screen.dart';
import 'screens/frecuencia_cardiaca_screen.dart';
import 'screens/medicamento_screen.dart';
import 'screens/notificaciones_screen.dart';
import 'screens/recommendations_screen.dart';
import 'screens/tv_summary_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'health_reminder_channel',
  'Recordatorios de Salud',
  description: 'Canal para recordatorios médicos diarios',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

final List<String> _motivationalQuotes = [
  '¡Cuida tu salud, tú puedes!',
  '¡Un paso más hacia tu bienestar!',
  '¡Tu salud es lo primero, sigue adelante!',
  '¡Hoy es un gran día para cuidarte!',
  '¡Pequeños hábitos, grandes resultados!'
];

class ResponsiveSize {
  static bool isMobile(BuildContext context) => MediaQuery.of(context).size.width < 600;
  static bool isTablet(BuildContext context) => MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width < 1200;
  static bool isDesktop(BuildContext context) => MediaQuery.of(context).size.width >= 1200;
  static bool isTV(BuildContext context) => MediaQuery.of(context).size.width >= 1200 && MediaQuery.of(context).size.height >= 800;

  static double getCardHeight(BuildContext context) {
    if (isTV(context)) return 100.0;
    if (isTablet(context)) return 90.0;
    return 80.0;
  }

  static double getIconSize(BuildContext context) {
    if (isTV(context)) return 36.0;
    if (isTablet(context)) return 28.0;
    return 24.0;
  }

  static double getFontSize(BuildContext context, double baseFontSize) {
    if (isTV(context)) return baseFontSize * 1.4;
    if (isTablet(context)) return baseFontSize * 1.2;
    return baseFontSize;
  }

  static EdgeInsets getPadding(BuildContext context) {
    if (isTV(context)) return const EdgeInsets.all(24.0);
    if (isTablet(context)) return const EdgeInsets.all(20.0);
    return const EdgeInsets.all(16.0);
  }

  static double getHorizontalPadding(BuildContext context) {
    if (isTV(context)) return MediaQuery.of(context).size.width * 0.1;
    if (isTablet(context)) return MediaQuery.of(context).size.width * 0.06;
    return MediaQuery.of(context).size.width * 0.04;
  }

  static int getCrossAxisCount(BuildContext context) {
    if (isTV(context)) return 3;
    if (isTablet(context)) return 2;
    return 1;
  }
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('Mensaje en segundo plano: ${message.messageId}');
  _showNotification(message);
}

Future<void> _showNotification(RemoteMessage message) async {
  RemoteNotification? notification = message.notification;
  AndroidNotification? android = message.notification?.android;

  if (notification != null && android != null) {
    await flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          icon: '@mipmap/ic_launcher',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
      ),
      payload: 'navigate_to_data',
    );
  }
}

Future<bool> checkAndRequestNotificationPermissions() async {
  try {
    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    bool? notificationsEnabled = await androidPlugin?.areNotificationsEnabled();
    if (notificationsEnabled == null || !notificationsEnabled) {
      bool? granted = await androidPlugin?.requestNotificationsPermission();
      print('Permiso notificaciones Android solicitado: $granted');
      if (granted != true) {
        return false;
      }
    }

    NotificationSettings settings =
        await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    bool pushAuthorized = settings.authorizationStatus == AuthorizationStatus.authorized;
    print('Permiso notificaciones push: $pushAuthorized');
    return pushAuthorized;
  } catch (e) {
    print('Error al verificar/solicitar permisos: $e');
    return false;
  }
}

Future<void> _registerLocalNotification(String message, tz.TZDateTime scheduledTime) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('access_token');
  if (token == null) {
    print('No hay token para registrar notificación local');
    return;
  }

  try {
    final response = await http.post(
      Uri.parse('https://ec1bff1533be.ngrok-free.app/api/notificaciones/locales'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': 'true',
      },
      body: jsonEncode({
        'mensaje': message,
        'fecha': scheduledTime.toIso8601String().split('T')[0],
        'hora': '${scheduledTime.hour}:${scheduledTime.minute}:00',
      }),
    );

    if (response.statusCode == 200) {
      print('Notificación local registrada en la API');
    } else {
      print('Error al registrar notificación local: ${response.body}');
    }
  } catch (e) {
    print('Error de conexión al registrar notificación local: $e');
  }
}

Future<void> scheduleDailyNotification({TimeOfDay? newTime}) async {
  final prefs = await SharedPreferences.getInstance();

  await flutterLocalNotificationsPlugin.cancel(0);
  await prefs.setBool('notification_scheduled', false);

  if (newTime != null) {
    await prefs.setInt('notification_hour', newTime.hour);
    await prefs.setInt('notification_minute', newTime.minute);
  }

  bool isNotificationScheduled = prefs.getBool('notification_scheduled') ?? false;
  if (isNotificationScheduled) {
    print('Notificación diaria ya programada, omitiendo...');
    return;
  }

  if (!await checkAndRequestNotificationPermissions()) {
    print('Corporate Theme by xAI');
    return;
  }

  tz.initializeTimeZones();

  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'health_reminder_channel',
    'Recordatorios de Salud',
    channelDescription: 'Canal para recordatorios médicos diarios',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
    playSound: true,
    enableVibration: true,
  );

  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
  );

  final random = Random();
  final randomQuote = _motivationalQuotes[random.nextInt(_motivationalQuotes.length)];

  try {
    final scheduledTime = await _nextInstanceOfScheduledTime();
    await flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'No olvides llevar tus registros médicos hoy',
      randomQuote,
      scheduledTime,
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    print('Notificación programada para $scheduledTime con mensaje: $randomQuote');

    await _registerLocalNotification('No olvides llevar tus registros médicos hoy', scheduledTime);

    await prefs.setBool('notification_scheduled', true);
  } catch (e) {
    print('Error al programar notificación: $e');
  }
}

Future<tz.TZDateTime> _nextInstanceOfScheduledTime() async {
  final prefs = await SharedPreferences.getInstance();
  int hour = prefs.getInt('notification_hour') ?? 1;
  int minute = prefs.getInt('notification_minute') ?? 20;

  final now = tz.TZDateTime.now(tz.getLocation('America/Matamoros'));
  var scheduledDate = tz.TZDateTime(
    tz.getLocation('America/Matamoros'),
    now.year,
    now.month,
    now.day,
    hour,
    minute,
  );
  if (scheduledDate.isBefore(now)) {
    scheduledDate = scheduledDate.add(const Duration(days: 1));
  }
  return scheduledDate;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    print('Firebase inicializado correctamente');
  } catch (e) {
    print('Error inicializando Firebase: $e');
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  try {
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (response.payload == 'navigate_to_data') {
          navigatorKey.currentState?.pushNamed('/notificaciones');
        }
      },
    );
    print('Notificaciones locales inicializadas correctamente');
  } catch (e) {
    print('Error inicializando notificaciones locales: $e');
  }

  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  try {
    await androidPlugin?.createNotificationChannel(channel);
    print('Canal de notificaciones creado');
  } catch (e) {
    print('Error creando canal de notificaciones: $e');
  }

  await checkAndRequestNotificationPermissions();

  await scheduleDailyNotification();

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Mensaje en primer plano: ${message.messageId}');
    _showNotification(message);
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('Notificación abierta: ${message.messageId}');
    navigatorKey.currentState?.pushNamed('/notificaciones');
  });

  RemoteMessage? initialMessage =
      await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    print('App abierta desde notificación cerrada: ${initialMessage.messageId}');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigatorKey.currentState?.pushNamed('/notificaciones');
    });
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WHS Medicine',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red, // Changed to red
        scaffoldBackgroundColor: Colors.white,
        textTheme: const TextTheme(
          displayLarge: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              fontFamily: 'Inter',
              color: Colors.black), // Changed to black
          headlineMedium: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
              color: Colors.black), // Changed to black
          bodyLarge: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              fontFamily: 'Inter',
              color: Colors.black87), // Adjusted to dark gray for readability
          bodyMedium: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              fontFamily: 'Inter',
              color: Colors.black54), // Adjusted to lighter gray for readability
          labelLarge: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
              color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.black, // Changed to black
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
            elevation: 3,
            shadowColor: Colors.black.withOpacity(0.2),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
              color: Colors.black, // Changed to black
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.black26, width: 1), // Changed to light black
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.red, width: 2), // Changed to red
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.black26, width: 1), // Changed to light black
            borderRadius: BorderRadius.circular(12),
          ),
          errorBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.red, width: 1), // Changed to red
            borderRadius: BorderRadius.circular(12),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.red, width: 2), // Changed to red
            borderRadius: BorderRadius.circular(12),
          ),
          labelStyle: const TextStyle(
              color: Colors.black54, fontFamily: 'Inter', fontSize: 14), // Changed to gray
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          prefixIconColor: Colors.black, // Changed to black
          suffixIconColor: Colors.black54, // Changed to gray
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black, // Changed to black
          elevation: 0,
          shadowColor: Colors.black12,
          titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
            color: Colors.black, // Changed to black
          ),
          iconTheme: const IconThemeData(color: Colors.black, size: 24), // Changed to black
        ),
        cardTheme: CardTheme(
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          color: Colors.white,
        ),
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.red, // Changed to red
          accentColor: Colors.black, // Changed to black
          backgroundColor: Colors.white,
          errorColor: Colors.red, // Changed to red
        ).copyWith(secondary: Colors.red), // Changed to red
      ),
      navigatorKey: navigatorKey,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/notificaciones': (context) => const NotificacionesScreen(),
        '/recomendaciones': (context) => const HealthMonitorApp(),
        '/tv_summary': (context) => const TVSummaryScreen(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    await Future.delayed(const Duration(seconds: 3));
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (!mounted) return;

    if (token != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.black, // Changed to black
              Colors.red, // Changed to red
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/mednotify.jpg',
                        fit: BoxFit.contain,
                        width: ResponsiveSize.isTV(context)
                            ? 220
                            : ResponsiveSize.isTablet(context)
                                ? 180
                                : 140,
                        height: ResponsiveSize.isTV(context)
                            ? 220
                            : ResponsiveSize.isTablet(context)
                                ? 180
                                : 140,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    '',
                    style: TextStyle(
                      fontSize: ResponsiveSize.getFontSize(context, 40),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.5,
                      fontFamily: 'Inter',
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: ResponsiveSize.isTV(context) ? 6 : 4,
                    backgroundColor: Colors.white.withOpacity(0.3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = Colors.black // Changed to black
      ..style = PaintingStyle.fill;

    final paint2 = Paint()
      ..color = Colors.red // Changed to red
      ..style = PaintingStyle.fill;

    // Draw the first half (black)
    final path1 = Path()
      ..moveTo(0, 0)
      ..lineTo(0, size.height)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.7,
        size.width * 0.5,
        size.height * 0.8,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.9,
        size.width,
        size.height * 0.6,
      )
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path1, paint1);

    // Draw the second half (red)
    final path2 = Path()
      ..moveTo(0, 0)
      ..lineTo(0, size.height)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.7,
        size.width * 0.5,
        size.height * 0.8,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.9,
        size.width,
        size.height * 0.6,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isRegisterMode = false;
  bool _obscurePassword = true;
  String? _fcmToken;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeFcm();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
  }

  Future<void> _initializeFcm() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        _fcmToken = await messaging.getToken();
        if (_fcmToken != null && mounted) {
          print('FCM Token obtenido: $_fcmToken');
          setState(() {});
        }
      } else {
        print('Permisos de notificaciones push no otorgados');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error inicializando FCM: $e';
      });
    }
  }

  Future<void> _saveFcmToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null || _fcmToken == null) {
      print('No hay token o FCM token para guardar');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://ec1bff1533be.ngrok-free.app/api/save_fcm_token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'fcm_token': _fcmToken,
          'timezone': 'America/Matamoros',
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        print('FCM token guardado en la API');
      } else {
        print('Error al guardar FCM token: ${response.body}');
      }
    } catch (e) {
      print('Error de conexión al guardar FCM token: $e');
    }
  }

  Future<void> _login() async {
    if (!_validateInputs()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await http.post(
        Uri.parse('https://ec1bff1533be.ngrok-free.app/api/login'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'correo': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
          'fcm_token': _fcmToken ?? '',
          'timezone': 'America/Matamoros',
        }),
      ).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', data['access_token']);
        await _saveFcmToken();
        await scheduleDailyNotification();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        setState(() {
          _errorMessage = jsonDecode(response.body)['msg'] ?? 'Error en el login';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error de conexión: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _register() async {
    if (!_validateInputs()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await http.post(
        Uri.parse('https://ec1bff1533be.ngrok-free.app/api/registro'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'nombre': _nameController.text.trim(),
          'correo': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
          'fcm_token': _fcmToken ?? '',
          'timezone': 'America/Matamoros',
        }),
      ).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', data['access_token']);
        await _saveFcmToken();
        await scheduleDailyNotification();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        setState(() {
          _errorMessage = jsonDecode(response.body)['msg'] ?? 'Error en el registro';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error de conexión: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _validateInputs() {
    if (_isRegisterMode && _nameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'El nombre es obligatorio';
      });
      return false;
    }
    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'El correo es obligatorio';
      });
      return false;
    }
    if (_passwordController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'La contraseña es obligatoria';
      });
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Two-color geometric background with wave
          CustomPaint(
            painter: WavePainter(),
            child: Container(),
          ),
          // Glassmorphism overlay for content
          SafeArea(
            child: Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: SingleChildScrollView(
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: ResponsiveSize.isTV(context) ? 600 : 400,
                      ),
                      margin: EdgeInsets.symmetric(
                        horizontal: ResponsiveSize.getHorizontalPadding(context),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/mednotify.jpg',
                                height: ResponsiveSize.isTV(context)
                                    ? 250
                                    : ResponsiveSize.isTablet(context)
                                        ? 180
                                        : 150,
                                width: ResponsiveSize.isTV(context)
                                    ? 250
                                    : ResponsiveSize.isTablet(context)
                                        ? 180
                                        : 150,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          SizedBox(height: ResponsiveSize.isTV(context) ? 32 : 24),
                          Text(
                            '',
                            style: TextStyle(
                              fontSize: ResponsiveSize.getFontSize(context, 36),
                              fontWeight: FontWeight.bold,
                              color: Colors.black, // Changed to black
                              letterSpacing: 1.2,
                              fontFamily: 'Inter',
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: ResponsiveSize.isTV(context) ? 40 : 32),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: Colors.white.withOpacity(0.1),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  padding: ResponsiveSize.getPadding(context).copyWith(top: 32, bottom: 32),
                                  child: Column(
                                    children: [
                                      if (_isRegisterMode)
                                        _buildTextField(
                                          controller: _nameController,
                                          label: 'Nombre',
                                          icon: Icons.person,
                                          textInputAction: TextInputAction.next,
                                        ),
                                      if (_isRegisterMode) const SizedBox(height: 16),
                                      _buildTextField(
                                        controller: _emailController,
                                        label: 'Correo electrónico',
                                        icon: Icons.email,
                                        keyboardType: TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                      ),
                                      const SizedBox(height: 16),
                                      _buildTextField(
                                        controller: _passwordController,
                                        label: 'Contraseña',
                                        icon: Icons.lock,
                                        obscureText: _obscurePassword,
                                        textInputAction: TextInputAction.done,
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                            color: Colors.white.withOpacity(0.7),
                                            size: ResponsiveSize.getIconSize(context),
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscurePassword = !_obscurePassword;
                                            });
                                          },
                                        ),
                                        onSubmitted: (_) => _isRegisterMode ? _register() : _login(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: ResponsiveSize.isTV(context) ? 32 : 24),
                          if (_errorMessage != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.9), // Changed to red
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: ResponsiveSize.getFontSize(context, 14),
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          if (_errorMessage != null) const SizedBox(height: 24),
                          _isLoading
                              ? Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: ResponsiveSize.isTV(context) ? 6 : 4,
                                    backgroundColor: Colors.white.withOpacity(0.3),
                                  ),
                                )
                              : _buildAnimatedButton(
                                  context: context,
                                  label: _isRegisterMode ? 'Registrarse' : 'Iniciar Sesión',
                                  onPressed: _isRegisterMode ? _register : _login,
                                ),
                          SizedBox(height: ResponsiveSize.isTV(context) ? 24 : 16),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isRegisterMode = !_isRegisterMode;
                                _errorMessage = null;
                                _emailController.clear();
                                _passwordController.clear();
                                _nameController.clear();
                                _obscurePassword = true;
                              });
                              _animationController.reset();
                              _animationController.forward();
                            },
                            child: Text(
                              _isRegisterMode
                                  ? '¿Ya tienes cuenta? Inicia sesión'
                                  : '¿No tienes cuenta? Regístrate',
                              style: TextStyle(
                                color: Colors.black, // Changed to black
                                fontSize: ResponsiveSize.getFontSize(context, 16),
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.black.withOpacity(0.7), // Changed to black
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    Widget? suffixIcon,
    Function(String)? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontSize: ResponsiveSize.getFontSize(context, 14),
          fontFamily: 'Inter',
        ),
        prefixIcon: Icon(
          icon,
          color: Colors.white.withOpacity(0.9),
          size: ResponsiveSize.getIconSize(context),
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.red.withOpacity(0.5), // Changed to red
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 16,
        ),
      ),
      style: TextStyle(
        color: Colors.white,
        fontSize: ResponsiveSize.getFontSize(context, 16),
        fontFamily: 'Inter',
      ),
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
    );
  }

  Widget _buildAnimatedButton({
    required BuildContext context,
    required String label,
    required VoidCallback onPressed,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: ResponsiveSize.isTV(context) ? 60 : 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black, // Changed to black
          elevation: 5,
          shadowColor: Colors.black.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.symmetric(
            vertical: ResponsiveSize.isTV(context) ? 18 : 14,
            horizontal: ResponsiveSize.isTV(context) ? 40 : 32,
          ),
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: TextStyle(
            fontSize: ResponsiveSize.getFontSize(context, 16),
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
            color: Colors.black, // Changed to black
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    String? fcmToken;
    try {
      fcmToken = await FirebaseMessaging.instance.getToken();
      print('FCM Token obtenido para logout: $fcmToken');
    } catch (e) {
      print('Error al obtener FCM token para logout: $e');
    }

    if (token != null && fcmToken != null) {
      try {
        final response = await http.post(
          Uri.parse('https://ec1bff1533be.ngrok-free.app/api/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
            'ngrok-skip-browser-warning': 'true',
          },
          body: jsonEncode({
            'fcm_token': fcmToken,
          }),
        );

        if (response.statusCode == 200) {
          print('Cierre de sesión exitoso en la API');
        } else {
          print('Error al cerrar sesión en la API: ${response.body}');
        }
      } catch (e) {
        print('Error de conexión al cerrar sesión: $e');
      }
    } else {
      print('No se pudo cerrar sesión en la API: token=$token, fcmToken=$fcmToken');
    }

    await prefs.remove('access_token');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> menuItems = [
      {
        'icon': Icons.bloodtype,
        'title': 'Glucosa',
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RegistroScreen()),
            ),
      },
      {
        'icon': Icons.favorite,
        'title': 'Presión Arterial',
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PresionArterialScreen()),
            ),
      },
      {
        'icon': Icons.air,
        'title': 'Oxigenación',
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const OxigenacionScreen()),
            ),
      },
      {
        'icon': Icons.monitor_heart,
        'title': 'Frecuencia Cardíaca',
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FrecuenciaCardiacaScreen()),
            ),
      },
      {
        'icon': Icons.medication,
        'title': 'Medicamentos',
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MedicamentoScreen()),
            ),
      },
      {
        'icon': Icons.lightbulb_outline,
        'title': 'Recomendaciones',
        'onTap': () => Navigator.pushNamed(context, '/recomendaciones'),
      },
      {
        'icon': Icons.tv,
        'title': 'Resumen en TV',
        'onTap': () => Navigator.pushNamed(context, '/tv_summary'),
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '¿Qué deseas registrar?',
          style: TextStyle(fontSize: ResponsiveSize.getFontSize(context, 20)),
        ),
        elevation: 2,
        shadowColor: Colors.red.withOpacity(0.1), // Changed to red
        toolbarHeight: ResponsiveSize.isTV(context) ? 80 : 56,
        actions: [
          IconButton(
            icon: Icon(
              Icons.notifications,
              size: ResponsiveSize.getIconSize(context),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NotificacionesScreen()),
            ),
            tooltip: 'Notificaciones',
            splashRadius: ResponsiveSize.isTV(context) ? 30 : 22,
          ),
          IconButton(
            icon: Icon(
              Icons.logout,
              size: ResponsiveSize.getIconSize(context),
            ),
            onPressed: () => _logout(context),
            tooltip: 'Cerrar sesión',
            splashRadius: ResponsiveSize.isTV(context) ? 30 : 22,
          ),
          SizedBox(width: ResponsiveSize.isTV(context) ? 16 : 8),
        ],
      ),
      body: ResponsiveSize.isTV(context) || ResponsiveSize.isTablet(context)
          ? _buildGridLayout(context, menuItems)
          : _buildListLayout(context, menuItems),
    );
  }

  Widget _buildGridLayout(BuildContext context, List<Map<String, dynamic>> menuItems) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveSize.getHorizontalPadding(context),
        vertical: ResponsiveSize.isTV(context) ? 24 : 16,
      ),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: ResponsiveSize.getCrossAxisCount(context),
          crossAxisSpacing: ResponsiveSize.isTV(context) ? 24 : 16,
          mainAxisSpacing: ResponsiveSize.isTV(context) ? 24 : 16,
          childAspectRatio: ResponsiveSize.isTV(context) ? 2.5 : 2.8,
        ),
        itemCount: menuItems.length,
        itemBuilder: (context, index) {
          final item = menuItems[index];
          return _buildMenuCard(
            context,
            icon: item['icon'],
            title: item['title'],
            onTap: item['onTap'],
          );
        },
      ),
    );
  }

  Widget _buildListLayout(BuildContext context, List<Map<String, dynamic>> menuItems) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveSize.getHorizontalPadding(context),
        vertical: 16,
      ),
      child: ListView.builder(
        itemCount: menuItems.length,
        itemBuilder: (context, index) {
          final item = menuItems[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildMenuCard(
              context,
              icon: item['icon'],
              title: item['title'],
              onTap: item['onTap'],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context,
      {required IconData icon, required String title, required VoidCallback onTap}) {
    return Card(
      elevation: ResponsiveSize.isTV(context) ? 6 : 3,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: ResponsiveSize.getCardHeight(context),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
          ),
          padding: ResponsiveSize.getPadding(context),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(ResponsiveSize.isTV(context) ? 16 : 12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1), // Changed to light red
                  borderRadius: BorderRadius.circular(ResponsiveSize.isTV(context) ? 14 : 10),
                ),
                child: Icon(
                  icon,
                  size: ResponsiveSize.getIconSize(context),
                  color: Colors.black, // Changed to black
                ),
              ),
              SizedBox(width: ResponsiveSize.isTV(context) ? 24 : 16),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: ResponsiveSize.getFontSize(context, 18),
                        fontWeight: FontWeight.w600,
                        color: Colors.black, // Changed to black
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: ResponsiveSize.getFontSize(context, 16),
                color: Colors.black, // Changed to black
              ),
            ],
          ),
        ),
      ),
    );
  }  }

