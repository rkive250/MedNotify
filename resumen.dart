import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initFirebaseMessaging();
  runApp(MyApp());
}

// Configuración de notificaciones locales
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initFirebaseMessaging() async {
  // Configurar Firebase Messaging
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Solicitar permisos (iOS)
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print('Permisos de notificación otorgados');
  } else {
    print('Permisos de notificación denegados');
  }

  // Configurar notificaciones locales
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Manejar notificaciones en primer plano
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Notificación recibida en primer plano: ${message.notification?.title}');
    _showNotification(message);
  });

  // Manejar notificaciones cuando la app está en segundo plano o terminada
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('Notificación abierta: ${message.notification?.title}');
    // Navegar a una pantalla específica si es necesario
  });

  // Obtener el token FCM
  String? token = await messaging.getToken();
  print('FCM Token: $token');
  // Enviar el token al servidor
  if (token != null) {
    await sendFcmTokenToServer(token);
  }

  // Escuchar actualizaciones del token
  messaging.onTokenRefresh.listen((newToken) async {
    print('Nuevo FCM Token: $newToken');
    await sendFcmTokenToServer(newToken);
  });
}

// Enviar el token FCM al servidor
Future<void> sendFcmTokenToServer(String token) async {
  const String apiUrl = 'http://your-server-ip:5000/api/save_fcm_token';
  const String jwtToken = 'your-jwt-token'; // Reemplaza con el token JWT del usuario

  try {
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $jwtToken',
      },
      body: jsonEncode({'fcm_token': token}),
    );

    if (response.statusCode == 200) {
      print('Token FCM enviado al servidor');
    } else {
      print('Error al enviar token FCM: ${response.body}');
    }
  } catch (e) {
    print('Error al conectar con el servidor: $e');
  }
}

// Mostrar notificación local
Future<void> _showNotification(RemoteMessage message) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'whs_medicine_channel',
    'WHS Medicine Notifications',
    channelDescription: 'Notificaciones para WHS Medicine',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
  );
  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

  await flutterLocalNotificationsPlugin.show(
    0, // ID de la notificación
    message.notification?.title ?? 'WHS Medicine',
    message.notification?.body ?? 'Nueva notificación',
    platformChannelSpecifics,
    payload: jsonEncode(message.data), // Para manejar datos adicionales como delete_request_id
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WHS Medicine',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> notifications = [];

  @override
  void initState() {
    super.initState();
    // Cargar notificaciones del servidor
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    const String apiUrl = 'http://your-server-ip:5000/api/notificaciones';
    const String jwtToken = 'your-jwt-token'; // Reemplaza con el token JWT del usuario

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $jwtToken',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          notifications = List<Map<String, dynamic>>.from(jsonDecode(response.body));
        });
      } else {
        print('Error al obtener notificaciones: ${response.body}');
      }
    } catch (e) {
      print('Error al conectar con el servidor: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('WHS Medicine'),
      ),
      body: ListView.builder(
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notification = notifications[index];
          return ListTile(
            title: Text(notification['mensaje']),
            subtitle: Text('${notification['fecha']} ${notification['hora']}'),
            onTap: () {
              if (notification['delete_request_id'] != null) {
                // Navegar a pantalla de confirmación de eliminación
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ConfirmDeleteScreen(
                      deleteRequestId: notification['delete_request_id'],
                    ),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}

class ConfirmDeleteScreen extends StatelessWidget {
  final String deleteRequestId;

  ConfirmDeleteScreen({required this.deleteRequestId});

  final TextEditingController _passwordController = TextEditingController();

  Future<void> confirmDelete(BuildContext context) async {
    const String apiUrl = 'http://your-server-ip:5000/api/confirm_delete';
    const String jwtToken = 'your-jwt-token'; // Reemplaza con el token JWT del usuario

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({
          'delete_request_id': deleteRequestId,
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registro eliminado correctamente')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${jsonDecode(response.body)['msg']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al conectar con el servidor')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Confirmar Eliminación'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Contraseña'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => confirmDelete(context),
              child: Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
  }
}