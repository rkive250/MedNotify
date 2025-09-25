import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Configuración de notificaciones locales
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Manejar notificaciones en segundo plano
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Notificación en segundo plano: ${message.notification?.title}');
  await _showNotification(message);
}

Future<void> initFirebaseMessaging() async {
  await Firebase.initializeApp();

  FirebaseMessaging messaging = FirebaseMessaging.instance;

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

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Notificación recibida en primer plano: ${message.notification?.title}');
    _showNotification(message);
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('Notificación abierta: ${message.notification?.title}');
  });

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  String? token = await messaging.getToken();
  print('FCM Token: $token');
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
  const String apiUrl = 'https://ec1bff1533be.ngrok-free.app/api/save_fcm_token';
  final prefs = await SharedPreferences.getInstance();
  final jwtToken = prefs.getString('access_token');

  if (jwtToken == null) {
    print('No hay token JWT disponible');
    return;
  }

  try {
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $jwtToken',
        'ngrok-skip-browser-warning': 'true',
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
    0,
    message.notification?.title ?? 'WHS Medicine',
    message.notification?.body ?? 'Nueva notificación',
    platformChannelSpecifics,
    payload: jsonEncode(message.data),
  );
}

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  bool _isLoading = false;
  String? _mensaje;
  List<dynamic> _notificaciones = [];
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchNotificaciones();
  }

  Future<void> _fetchNotificaciones() async {
    setState(() {
      _isLoading = true;
      _mensaje = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token == null) {
      setState(() {
        _mensaje = 'No estás autenticado.';
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('https://ec1bff1533be.ngrok-free.app/api/notificaciones'),
        headers: {
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _notificaciones = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _mensaje = jsonDecode(response.body)['msg'] ?? 'Error al obtener notificaciones';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mensaje = 'Error de conexión: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmDelete(String deleteRequestId) async {
    setState(() {
      _isLoading = true;
      _mensaje = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token == null) {
      setState(() {
        _mensaje = 'No estás autenticado.';
        _isLoading = false;
      });
      return;
    }

    if (_passwordController.text.isEmpty) {
      setState(() {
        _mensaje = 'Por favor, ingresa tu contraseña.';
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://ec1bff1533be.ngrok-free.app/api/confirm_delete'),
        headers: {
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'delete_request_id': deleteRequestId,
          'password': _passwordController.text,
        }),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _mensaje = 'Registro eliminado ✅';
          _passwordController.clear();
        });
        await _fetchNotificaciones();
      } else {
        final errorMsg = jsonDecode(response.body)['msg'] ?? 'Error desconocido';
        setState(() {
          _mensaje = 'Error: $errorMsg';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mensaje = 'Error de conexión: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones', style: TextStyle(fontFamily: 'Roboto', color: Colors.white, fontSize: 18)),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        leading: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Image.asset(
            'assets/mednotify.jpg',
            fit: BoxFit.contain,
            width: 18,
            height: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(size.width * 0.03),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Historial de Notificaciones',
                style: TextStyle(
                  fontSize: size.width * 0.045,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto',
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: size.height * 0.015),
              if (_mensaje != null)
                Container(
                  padding: EdgeInsets.all(10),
                  margin: EdgeInsets.symmetric(horizontal: size.width * 0.015),
                  decoration: BoxDecoration(
                    color: _mensaje!.contains('exitoso') || _mensaje!.contains('eliminado')
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _mensaje!,
                    style: TextStyle(
                      color: _mensaje!.contains('exitoso') || _mensaje!.contains('eliminado')
                          ? Colors.green[800]
                          : Colors.red[800],
                      fontSize: size.width * 0.035,
                      fontFamily: 'Roboto',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              SizedBox(height: size.height * 0.015),
              _isLoading
                  ? Center(child: CircularProgressIndicator(color: Colors.blue[700]))
                  : _notificaciones.isEmpty
                      ? Center(
                          child: Text(
                            'No hay notificaciones.',
                            style: TextStyle(
                              fontSize: size.width * 0.04,
                              fontFamily: 'Roboto',
                              color: Colors.black54,
                            ),
                          ),
                        )
                      : Expanded(
                          child: ListView.builder(
                            itemCount: _notificaciones.length,
                            itemBuilder: (context, index) {
                              final notificacion = _notificaciones[index];
                              final mensaje = notificacion['mensaje'];
                              final isHigh = mensaje.contains('alto') || mensaje.contains('Resumen diario');
                              final isLow = mensaje.contains('bajo');
                              final deleteRequestId = notificacion['delete_request_id'];

                              return Card(
                                margin: EdgeInsets.symmetric(
                                  vertical: size.height * 0.005,
                                  horizontal: size.width * 0.01,
                                ),
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                child: ListTile(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: size.width * 0.02,
                                    vertical: size.height * 0.005,
                                  ),
                                  title: Text(
                                    notificacion['mensaje'],
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: size.width * 0.03,
                                      fontWeight: FontWeight.bold,
                                      color: isHigh
                                          ? Colors.red[700]
                                          : isLow
                                              ? Colors.yellow[700]
                                              : Colors.black87,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    'Fecha: ${notificacion['fecha']} - ${notificacion['hora']}',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: size.width * 0.025,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  trailing: deleteRequestId != null
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: Icon(Icons.lock, color: Colors.blue[700], size: size.width * 0.04),
                                              onPressed: () => _showPasswordDialog(deleteRequestId),
                                            ),
                                          ],
                                        )
                                      : Icon(
                                          isHigh
                                              ? Icons.warning
                                              : isLow
                                                  ? Icons.info
                                                  : Icons.check_circle,
                                          color: isHigh
                                              ? Colors.red[700]
                                              : isLow
                                                  ? Colors.yellow[700]
                                                  : Colors.green[700],
                                          size: size.width * 0.04,
                                        ),
                                ),
                              );
                            },
                          ),
                        ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPasswordDialog(String deleteRequestId) {
    showDialog(
      context: context,
      builder: (context) {
        final size = MediaQuery.of(context).size;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: Text(
            'Confirmar Eliminación',
            style: TextStyle(
              fontFamily: 'Roboto',
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: size.width * 0.04,
            ),
            textAlign: TextAlign.center,
          ),
          content: SizedBox(
            width: size.width * 0.8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Ingresa tu contraseña para confirmar:',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.black87,
                    fontSize: size.width * 0.035,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: size.height * 0.01),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: Icon(Icons.lock, color: Colors.blue[700], size: size.width * 0.04),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: size.width * 0.035,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: TextStyle(
                  color: Colors.grey,
                  fontFamily: 'Roboto',
                  fontSize: size.width * 0.035,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _confirmDelete(deleteRequestId);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: EdgeInsets.symmetric(
                  horizontal: size.width * 0.04,
                  vertical: size.height * 0.01,
                ),
              ),
              child: Text(
                'Confirmar',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: size.width * 0.035,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }
}