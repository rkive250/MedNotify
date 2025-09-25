import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';

class PresionArterialScreen extends StatefulWidget {
  const PresionArterialScreen({super.key});

  @override
  State<PresionArterialScreen> createState() => _PresionArterialScreenState();
}

class _PresionArterialScreenState extends State<PresionArterialScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  DateTime? _searchDate;
  final _sistolicaController = TextEditingController();
  final _diastolicaController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _searchDateController = TextEditingController();
  bool _isLoading = false;
  String? _mensaje;
  List<dynamic> _registros = [];
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  static const String _baseUrl = 'https://ec1bff1533be.ngrok-free.app';

  @override
  void initState() {
    super.initState();
    _fetchRegistros();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  Future<void> _fetchRegistros({String? fecha}) async {
    print('Iniciando recarga de registros${fecha != null ? ' para fecha: $fecha' : ''}');
    setState(() {
      _isLoading = true;
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
      final uri = Uri.parse('$_baseUrl/api/presiones_arteriales')
          .replace(queryParameters: fecha != null ? {'fecha': fecha} : null);
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _registros = jsonDecode(response.body);
          _isLoading = false;
          _animationController.reset();
          _animationController.forward();
        });
        print('Registros recargados exitosamente: ${_registros.length} registros');
      } else {
        setState(() {
          _mensaje = jsonDecode(response.body)['msg'] ?? 'Error al obtener registros';
          _isLoading = false;
        });
        print('Error al recargar registros: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mensaje = 'Error de conexión: $e';
        _isLoading = false;
      });
      print('Error de conexión al recargar registros: $e');
    }
  }

  Future<void> _submitRegistro() async {
    if (!_formKey.currentState!.validate() || _selectedDate == null || _selectedTime == null) {
      setState(() {
        _mensaje = 'Por favor, completa todos los campos.';
      });
      return;
    }
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
    final String fecha = _selectedDate!.toIso8601String().split('T')[0];
    final String hora = '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}:00';
    final int sistolica = int.parse(_sistolicaController.text);
    final int diastolica = int.parse(_diastolicaController.text);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/registros_salud'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'fecha': fecha,
          'hora': hora,
          'tipo': 'presion_arterial',
          'sistolica': sistolica,
          'diastolica': diastolica,
        }),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 201) {
        setState(() {
          _mensaje = 'Registro exitoso ✅';
          _sistolicaController.clear();
          _diastolicaController.clear();
          _dateController.clear();
          _timeController.clear();
          _selectedDate = null;
          _selectedTime = null;
        });
        await _fetchRegistros();
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text(
                'Éxito',
                style: TextStyle(fontFamily: 'Roboto', color: Colors.black87, fontWeight: FontWeight.bold),
              ),
              content: const Text(
                'Registro creado correctamente ✅',
                style: TextStyle(fontFamily: 'Roboto', color: Colors.black87),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK', style: TextStyle(fontFamily: 'Roboto', color: Colors.blue)),
                ),
              ],
            ),
          );
        }
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

  Future<void> _updateRegistro(int id, DateTime fecha, TimeOfDay hora, int sistolica, int diastolica) async {
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
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text(
              'Error',
              style: TextStyle(fontFamily: 'Roboto', color: Colors.black87, fontWeight: FontWeight.bold),
            ),
            content: const Text(
              'No estás autenticado.',
              style: TextStyle(fontFamily: 'Roboto', color: Colors.black87),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(fontFamily: 'Roboto', color: Colors.blue)),
              ),
            ],
          ),
        );
      }
      return;
    }

    final String fechaStr = fecha.toIso8601String().split('T')[0];
    final String horaStr = '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}:00';

    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/api/presiones_arteriales/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'fecha': fechaStr,
          'hora': horaStr,
          'sistolica': sistolica,
          'diastolica': diastolica,
        }),
      ).timeout(const Duration(seconds: 10));

      print('Respuesta del backend (PUT /api/presiones_arteriales/$id): ${response.statusCode} - ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _mensaje = 'Registro editado correctamente ✅';
        });
        if (mounted) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text(
                'Éxito',
                style: TextStyle(fontFamily: 'Roboto', color: Colors.black87, fontWeight: FontWeight.bold),
              ),
              content: const Text(
                'Registro editado correctamente ✅',
                style: TextStyle(fontFamily: 'Roboto', color: Colors.black87),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _fetchRegistros();
                  },
                  child: const Text('OK', style: TextStyle(fontFamily: 'Roboto', color: Colors.blue)),
                ),
              ],
            ),
          );
        }
      } else {
        final errorMsg = jsonDecode(response.body)['msg'] ?? 'Error desconocido';
        setState(() {
          _mensaje = 'Error: $errorMsg';
        });
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text(
                'Error',
                style: TextStyle(fontFamily: 'Roboto', color: Colors.black87, fontWeight: FontWeight.bold),
              ),
              content: Text(
                'Error: $errorMsg',
                style: const TextStyle(fontFamily: 'Roboto', color: Colors.black87),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK', style: TextStyle(fontFamily: 'Roboto', color: Colors.blue)),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      print('Error en _updateRegistro: $e');
      if (!mounted) return;
      setState(() {
        _mensaje = 'Error de conexión: $e';
      });
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text(
              'Error',
              style: TextStyle(fontFamily: 'Roboto', color: Colors.black87, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Error de conexión: $e',
              style: const TextStyle(fontFamily: 'Roboto', color: Colors.black87),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(fontFamily: 'Roboto', color: Colors.blue)),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteRegistro(int id, String fecha, String hora) async {
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
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text(
              'Error',
              style: TextStyle(fontFamily: 'Roboto', color: Colors.black87, fontWeight: FontWeight.bold),
            ),
            content: const Text(
              'No estás autenticado.',
              style: TextStyle(fontFamily: 'Roboto', color: Colors.black87),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(fontFamily: 'Roboto', color: Colors.blue)),
              ),
            ],
          ),
        );
      }
      return;
    }

    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/presiones_arteriales/$id'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final deleteRequestId = responseData['delete_request_id'];
        setState(() {
          _mensaje = 'Solicitud de eliminación enviada correctamente ✅';
        });
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text(
                'Solicitud Enviada',
                style: TextStyle(fontFamily: 'Roboto', color: Colors.black87, fontWeight: FontWeight.bold),
              ),
              content: const Text(
                'La solicitud de eliminación ha sido enviada al módulo de notificaciones. Por favor, confirma la eliminación con tu contraseña.',
                style: TextStyle(fontFamily: 'Roboto', color: Colors.black87),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK', style: TextStyle(fontFamily: 'Roboto', color: Colors.blue)),
                ),
              ],
            ),
          );
        }
        _showConfirmDeleteDialog(id, fecha, hora, deleteRequestId);
      } else {
        final errorMsg = jsonDecode(response.body)['msg'] ?? 'Error desconocido';
        setState(() {
          _mensaje = 'Error: $errorMsg';
          _isLoading = false;
        });
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text(
                'Error',
                style: TextStyle(fontFamily: 'Roboto', color: Colors.black87, fontWeight: FontWeight.bold),
              ),
              content: Text(
                'Error: $errorMsg',
                style: const TextStyle(fontFamily: 'Roboto', color: Colors.black87),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK', style: TextStyle(fontFamily: 'Roboto', color: Colors.blue)),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      print('Error en _deleteRegistro: $e');
      if (!mounted) return;
      setState(() {
        _mensaje = 'Error de conexión: $e';
        _isLoading = false;
      });
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text(
              'Error',
              style: TextStyle(fontFamily: 'Roboto', color: Colors.black87, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Error de conexión: $e',
              style: const TextStyle(fontFamily: 'Roboto', color: Colors.black87),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(fontFamily: 'Roboto', color: Colors.blue)),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _confirmDelete(String deleteRequestId, String password) async {
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
      final response = await http.post(
        Uri.parse('$_baseUrl/api/confirm_delete'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'delete_request_id': deleteRequestId,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _mensaje = '';
        });
        await _fetchRegistros();
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text(
                'Éxito',
                style: TextStyle(fontFamily: 'Roboto', color: Colors.black87, fontWeight: FontWeight.bold),
              ),
              content: const Text(
                'Registro eliminado correctamente ✅',
                style: TextStyle(fontFamily: 'Roboto', color: Colors.black87),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK', style: TextStyle(fontFamily: 'Roboto', color: Colors.blue)),
                ),
              ],
            ),
          );
        }
      } else {
        final errorMsg = jsonDecode(response.body)['msg'] ?? 'Error desconocido';
        setState(() {
          _mensaje = 'Error: $errorMsg';
        });
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text(
                'Error',
                style: TextStyle(fontFamily: 'Roboto', color: Colors.black87, fontWeight: FontWeight.bold),
              ),
              content: Text(
                'Error: $errorMsg',
                style: const TextStyle(fontFamily: 'Roboto', color: Colors.black87),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK', style: TextStyle(fontFamily: 'Roboto', color: Colors.blue)),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      print('Error en _confirmDelete: $e');
      if (!mounted) return;
      setState(() {
        _mensaje = 'Error de conexión: $e';
      });
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text(
              'Error',
              style: TextStyle(fontFamily: 'Roboto', color: Colors.black87, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Error de conexión: $e',
              style: const TextStyle(fontFamily: 'Roboto', color: Colors.black87),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(fontFamily: 'Roboto', color: Colors.blue)),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteNotificacion(int id) async {
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
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text(
              'Error',
              style: TextStyle(fontFamily: 'Roboto', color: Colors.black87, fontWeight: FontWeight.bold),
            ),
            content: const Text(
              'No estás autenticado.',
              style: TextStyle(fontFamily: 'Roboto', color: Colors.black87),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(fontFamily: 'Roboto', color: Colors.blue)),
              ),
            ],
          ),
        );
      }
      return;
    }

    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/notificaciones/$id'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _mensaje = 'Notificación eliminada correctamente ✅';
        });
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text(
                'Éxito',
                style: TextStyle(fontFamily: 'Roboto', color: Colors.black87, fontWeight: FontWeight.bold),
              ),
              content: const Text(
                'Notificación eliminada correctamente ✅',
                style: TextStyle(fontFamily: 'Roboto', color: Colors.black87),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK', style: TextStyle(fontFamily: 'Roboto', color: Colors.blue)),
                ),
              ],
            ),
          );
        }
      } else {
        final errorMsg = jsonDecode(response.body)['msg'] ?? 'Error desconocido';
        setState(() {
          _mensaje = 'Error: $errorMsg';
        });
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text(
                'Error',
                style: TextStyle(fontFamily: 'Roboto', color: Colors.black87, fontWeight: FontWeight.bold),
              ),
              content: Text(
                'Error: $errorMsg',
                style: const TextStyle(fontFamily: 'Roboto', color: Colors.black87),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK', style: TextStyle(fontFamily: 'Roboto', color: Colors.blue)),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      print('Error en _deleteNotificacion: $e');
      if (!mounted) return;
      setState(() {
        _mensaje = 'Error de conexión: $e';
      });
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text(
              'Error',
              style: TextStyle(fontFamily: 'Roboto', color: Colors.black87, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Error de conexión: $e',
              style: const TextStyle(fontFamily: 'Roboto', color: Colors.black87),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(fontFamily: 'Roboto', color: Colors.blue)),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickSearchDate() async {
    final size = MediaQuery.of(context).size;
    DateTime? selectedDate;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: size.height * 0.6,
              maxWidth: size.width * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.all(size.width * 0.02),
                  child: Text(
                    'Seleccionar Fecha de Búsqueda',
                    style: TextStyle(
                      fontSize: size.width * 0.04,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Roboto',
                      color: Colors.black87,
                    ),
                  ),
                ),
                Expanded(
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(
                        primary: Colors.blue[700]!,
                        onPrimary: Colors.white,
                        onSurface: Colors.black87,
                      ),
                      textButtonTheme: TextButtonThemeData(
                        style: TextButton.styleFrom(foregroundColor: Colors.blue[700]),
                      ),
                    ),
                    child: CalendarDatePicker(
                      initialDate: _searchDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      onDateChanged: (date) {
                        selectedDate = date;
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selectedDate != null && mounted) {
      setState(() {
        _searchDate = selectedDate;
        _searchDateController.text = selectedDate!.toLocal().toString().split(' ')[0];
      });
      await _fetchRegistros(fecha: selectedDate!.toIso8601String().split('T')[0]);
    }
  }

  Future<void> _pickDate() async {
    final size = MediaQuery.of(context).size;
    DateTime? selectedDate;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: size.height * 0.6,
              maxWidth: size.width * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.all(size.width * 0.02),
                  child: Text(
                    'Seleccionar Fecha',
                    style: TextStyle(
                      fontSize: size.width * 0.04,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Roboto',
                      color: Colors.black87,
                    ),
                  ),
                ),
                Expanded(
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(
                        primary: Colors.blue[700]!,
                        onPrimary: Colors.white,
                        onSurface: Colors.black87,
                      ),
                      textButtonTheme: TextButtonThemeData(
                        style: TextButton.styleFrom(foregroundColor: Colors.blue[700]),
                      ),
                    ),
                    child: CalendarDatePicker(
                      initialDate: _selectedDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      onDateChanged: (date) {
                        selectedDate = date;
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selectedDate != null && mounted) {
      setState(() {
        _selectedDate = selectedDate;
        _dateController.text = selectedDate!.toLocal().toString().split(' ')[0];
      });
    }
  }

  Future<void> _pickTime() async {
    final size = MediaQuery.of(context).size;
    final selected = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue[700]!,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.blue[700]),
            ),
          ),
          child: child!,
        );
      },
    );
    if (selected != null && mounted) {
      setState(() {
        _selectedTime = selected;
        _timeController.text = selected.format(context);
      });
    }
  }

  void _showEditDialog(dynamic registro) {
    final editDateController = TextEditingController(text: registro['fecha']);
    final editTimeController = TextEditingController(text: registro['hora'].substring(0, 5));
    final editSistolicaController = TextEditingController(text: registro['sistolica'].toString());
    final editDiastolicaController = TextEditingController(text: registro['diastolica'].toString());
    DateTime? editDate = DateTime.parse(registro['fecha']);
    TimeOfDay editTime = TimeOfDay(
      hour: int.parse(registro['hora'].split(':')[0]),
      minute: int.parse(registro['hora'].split(':')[1]),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Editar Registro', style: TextStyle(fontFamily: 'Roboto', color: Colors.black87, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: editDateController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Fecha',
                    prefixIcon: Icon(Icons.calendar_today, color: Colors.blue[700]),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  onTap: () async {
                    await _pickDate();
                    if (_selectedDate != null) {
                      editDate = _selectedDate;
                      editDateController.text = _selectedDate!.toIso8601String().split('T')[0];
                    }
                  },
                  validator: (value) => value!.isEmpty ? 'Selecciona una fecha' : null,
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: editTimeController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Hora',
                    prefixIcon: Icon(Icons.access_time, color: Colors.blue[700]),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  onTap: () async {
                    await _pickTime();
                    if (_selectedTime != null) {
                      editTime = _selectedTime!;
                      editTimeController.text =
                          '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';
                    }
                  },
                  validator: (value) => value!.isEmpty ? 'Selecciona una hora' : null,
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: editSistolicaController,
                  decoration: InputDecoration(
                    labelText: 'Presión Sistólica (mmHg)',
                    prefixIcon: Icon(Icons.arrow_upward, color: Colors.blue[700]),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Introduce la presión sistólica';
                    }
                    final intVal = int.tryParse(value);
                    if (intVal == null || intVal < 0 || intVal > 300) {
                      return 'Valor inválido (0 - 300)';
                    }
                    return null;
                  },
                  style: const TextStyle(fontFamily: 'Roboto', color: Colors.black87),
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: editDiastolicaController,
                  decoration: InputDecoration(
                    labelText: 'Presión Diastólica (mmHg)',
                    prefixIcon: Icon(Icons.arrow_downward, color: Colors.blue[700]),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Introduce la presión diastólica';
                    }
                    final intVal = int.tryParse(value);
                    if (intVal == null || intVal < 0 || intVal > 200) {
                      return 'Valor inválido (0 - 200)';
                    }
                    return null;
                  },
                  style: const TextStyle(fontFamily: 'Roboto', color: Colors.black87),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontFamily: 'Roboto', fontSize: 16)),
            ),
            ElevatedButton(
              onPressed: () {
                if (editDate == null || editTime == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Selecciona fecha y hora')),
                  );
                  return;
                }
                final int? sistolica = int.tryParse(editSistolicaController.text);
                final int? diastolica = int.tryParse(editDiastolicaController.text);
                if (sistolica == null || sistolica < 0 || sistolica > 300) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Valor de presión sistólica inválido')),
                  );
                  return;
                }
                if (diastolica == null || diastolica < 0 || diastolica > 200) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Valor de presión diastólica inválido')),
                  );
                  return;
                }
                Navigator.pop(context);
                _updateRegistro(registro['id'], editDate!, editTime, sistolica, diastolica);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text('Guardar', style: TextStyle(fontFamily: 'Roboto', fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteDialog(dynamic registro) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text(
            'Confirmar Eliminación',
            style: TextStyle(fontFamily: 'Roboto', color: Colors.black87, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Confirma la eliminación del registro de presión arterial del ${registro['fecha']} a las ${registro['hora'].substring(0, 5)} (ID: ${registro['id']})',
            style: const TextStyle(fontFamily: 'Roboto', color: Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(fontFamily: 'Roboto', color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteRegistro(registro['id'], registro['fecha'], registro['hora']);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text('Eliminar', style: TextStyle(fontFamily: 'Roboto', fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  void _showConfirmDeleteDialog(int id, String fecha, String hora, String deleteRequestId) {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text(
            'Confirmar Eliminación',
            style: TextStyle(fontFamily: 'Roboto', color: Colors.black87, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Por favor, ingresa tu contraseña para confirmar la eliminación del registro del $fecha a las $hora (ID: $id).',
                style: const TextStyle(fontFamily: 'Roboto', color: Colors.black87),
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: Icon(Icons.lock, color: Colors.blue[700]),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                style: const TextStyle(fontFamily: 'Roboto', color: Colors.black87),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                passwordController.dispose();
                Navigator.pop(context);
              },
              child: const Text('Cancelar', style: TextStyle(fontFamily: 'Roboto', color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                final password = passwordController.text;
                if (password.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Por favor, ingresa tu contraseña')),
                  );
                  return;
                }
                Navigator.pop(context);
                passwordController.dispose();
                _confirmDelete(deleteRequestId, password);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text('Confirmar', style: TextStyle(fontFamily: 'Roboto', fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRangeRow({
    required BuildContext context,
    required Color color,
    required String range,
    required String description,
  }) {
    final size = MediaQuery.of(context).size;
    return Row(
      children: [
        Container(
          width: size.width * 0.05,
          height: size.width * 0.05,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: size.width * 0.02),
        Flexible(
          child: Text(
            '$range: $description',
            style: TextStyle(
              fontSize: size.width * 0.035,
              fontFamily: 'Roboto',
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Presión Arterial', style: TextStyle(fontFamily: 'Roboto', color: Colors.white, fontSize: 18)),
backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        leading: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Image.asset(
            'assets/mednotify.jpg',
            fit: BoxFit.contain,
            width: 20,
            height: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(size.width * 0.03),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: EdgeInsets.all(size.width * 0.03),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Buscar por Fecha',
                            style: TextStyle(
                              fontSize: size.width * 0.045,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Roboto',
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: size.height * 0.015),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _searchDateController,
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    labelText: 'Seleccionar Fecha',
                                    labelStyle: const TextStyle(color: Colors.black87, fontFamily: 'Roboto'),
                                    prefixIcon: Icon(Icons.calendar_today, color: Colors.blue[700], size: size.width * 0.04),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                  ),
                                  onTap: _pickSearchDate,
                                  style: TextStyle(fontFamily: 'Roboto', fontSize: size.width * 0.035, color: Colors.black87),
                                ),
                              ),
                              SizedBox(width: size.width * 0.02),
                              ElevatedButton(
                                onPressed: () {
                                  if (_searchDate == null) {
                                    _fetchRegistros();
                                  } else {
                                    _fetchRegistros(fecha: _searchDate!.toIso8601String().split('T')[0]);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[700],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: EdgeInsets.symmetric(
                                    vertical: size.height * 0.015,
                                    horizontal: size.width * 0.08,
                                  ),
                                  elevation: 3,
                                ),
                                child: Text(
                                  'Buscar',
                                  style: TextStyle(
                                    fontSize: size.width * 0.035,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Roboto',
                                  ),
                                ),
                              ),
                              SizedBox(width: size.width * 0.02),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _searchDate = null;
                                    _searchDateController.clear();
                                  });
                                  _fetchRegistros();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[400],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: EdgeInsets.symmetric(
                                    vertical: size.height * 0.015,
                                    horizontal: size.width * 0.08,
                                  ),
                                  elevation: 3,
                                ),
                                child: Text(
                                  'Limpiar',
                                  style: TextStyle(
                                    fontSize: size.width * 0.035,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Roboto',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: size.height * 0.02),
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: EdgeInsets.all(size.width * 0.03),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nuevo Registro',
                            style: TextStyle(
                              fontSize: size.width * 0.045,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Roboto',
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: size.height * 0.015),
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _dateController,
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    labelText: 'Fecha',
                                    labelStyle: const TextStyle(color: Colors.black87, fontFamily: 'Roboto'),
                                    prefixIcon: Icon(Icons.calendar_today, color: Colors.blue[700], size: size.width * 0.04),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                  ),
                                  onTap: _pickDate,
                                  validator: (value) => value!.isEmpty ? 'Selecciona una fecha' : null,
                                  style: TextStyle(fontFamily: 'Roboto', fontSize: size.width * 0.035, color: Colors.black87),
                                ),
                                SizedBox(height: size.height * 0.01),
                                TextFormField(
                                  controller: _timeController,
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    labelText: 'Hora',
                                    prefixIcon: Icon(Icons.access_time, color: Colors.blue[700], size: size.width * 0.04),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                  ),
                                  onTap: _pickTime,
                                  validator: (value) => value!.isEmpty ? 'Selecciona una hora' : null,
                                  style: TextStyle(fontFamily: 'Roboto', fontSize: size.width * 0.035, color: Colors.black87),
                                ),
                                SizedBox(height: size.height * 0.01),
                                TextFormField(
                                  controller: _sistolicaController,
                                  decoration: InputDecoration(
                                    labelText: 'Presión Sistólica (mmHg)',
                                    labelStyle: const TextStyle(color: Colors.black87, fontFamily: 'Roboto'),
                                    prefixIcon: Icon(Icons.arrow_upward, color: Colors.blue[700], size: size.width * 0.04),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Introduce la presión sistólica';
                                    }
                                    final intVal = int.tryParse(value);
                                    if (intVal == null || intVal < 0 || intVal > 300) {
                                      return 'Valor inválido (0 - 300)';
                                    }
                                    return null;
                                  },
                                  style: TextStyle(fontFamily: 'Roboto', fontSize: size.width * 0.035, color: Colors.black87),
                                ),
                                SizedBox(height: size.height * 0.01),
                                TextFormField(
                                  controller: _diastolicaController,
                                  decoration: InputDecoration(
                                    labelText: 'Presión Diastólica (mmHg)',
                                    labelStyle: const TextStyle(color: Colors.black87, fontFamily: 'Roboto'),
                                    prefixIcon: Icon(Icons.arrow_downward, color: Colors.blue[700], size: size.width * 0.04),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Introduce la presión diastólica';
                                    }
                                    final intVal = int.tryParse(value);
                                    if (intVal == null || intVal < 0 || intVal > 200) {
                                      return 'Valor inválido (0 - 200)';
                                    }
                                    return null;
                                  },
                                  style: TextStyle(fontFamily: 'Roboto', fontSize: size.width * 0.035, color: Colors.black87),
                                ),
                                SizedBox(height: size.height * 0.015),
                                _isLoading
                                    ? Center(child: CircularProgressIndicator(color: Colors.blue[700]))
                                    : ElevatedButton(
                                        onPressed: _submitRegistro,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue[700],
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          padding: EdgeInsets.symmetric(
                                            vertical: size.height * 0.015,
                                            horizontal: size.width * 0.08,
                                          ),
                                          elevation: 3,
                                        ),
                                        child: Text(
                                          'Guardar Registro',
                                          style: TextStyle(
                                            fontSize: size.width * 0.035,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Roboto',
                                          ),
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: size.height * 0.02),
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: EdgeInsets.all(size.width * 0.03),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rangos de Presión Arterial',
                            style: TextStyle(
                              fontSize: size.width * 0.045,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Roboto',
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: size.height * 0.02),
                          Container(
                            padding: EdgeInsets.all(size.width * 0.02),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.white, Colors.blue[50]!],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildRangeRow(
                                  context: context,
                                  color: Colors.green[700]!,
                                  range: '<120/<80 mmHg' ,
                                  description: 'Normal',
                                ),
                                SizedBox(height: size.height * 0.01),
                                _buildRangeRow(
                                  context: context,
                                  color: Colors.yellow[700]!,
                                  range: '120–129/<80 mmHg',
                                  description: 'Elevada',
                                ),
                                SizedBox(height: size.height * 0.01),
                                _buildRangeRow(
                                  context: context,
                                  color: Colors.red[700]!,
                                  range: '≥130/≥80 mmHg',
                                  description: 'Hipertensión',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: size.height * 0.02),
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: EdgeInsets.all(size.width * 0.03),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  'Registros Existentes',
                                  style: TextStyle(
                                    fontSize: size.width * 0.045,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Roboto',
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.refresh, color: Colors.blue[700], size: size.width * 0.045),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      print('Botón de recarga presionado');
                                      setState(() {
                                        _searchDate = null;
                                        _searchDateController.clear();
                                      });
                                      _fetchRegistros();
                                    },
                                    tooltip: 'Recargar registros',
                                  ),
                                  SizedBox(width: size.width * 0.02),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => BloodPressureGraphScreen(registros: _registros),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue[700],
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: EdgeInsets.symmetric(
                                        vertical: size.height * 0.015,
                                        horizontal: size.width * 0.08,
                                      ),
                                      elevation: 3,
                                    ),
                                    child: Text(
                                      'Ver Resumen en TV',
                                      style: TextStyle(
                                        fontSize: size.width * 0.035,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Roboto',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: size.height * 0.02),
                          if (_mensaje != null)
                            Container(
                              padding: EdgeInsets.all(10),
                              margin: EdgeInsets.symmetric(horizontal: size.width * 0.015),
                              decoration: BoxDecoration(
                                color: _mensaje!.contains('exitoso') || _mensaje!.contains('editado') || _mensaje!.contains('eliminado') || _mensaje!.contains('Solicitud')
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _mensaje!,
                                style: TextStyle(
                                  color: _mensaje!.contains('exitoso') || _mensaje!.contains('editado') || _mensaje!.contains('eliminado') || _mensaje!.contains('Solicitud')
                                      ? Colors.green[800]
                                      : Colors.red[800],
                                  fontSize: size.width * 0.035,
                                  fontFamily: 'Roboto',
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          SizedBox(height: size.height * 0.02),
                          _isLoading
                              ? Center(child: CircularProgressIndicator(color: Colors.blue[700]))
                              : _registros.isEmpty
                                  ? Center(
                                      child: Text(
                                        'No hay registros de presión arterial.',
                                        style: TextStyle(
                                          fontSize: size.width * 0.04,
                                          fontFamily: 'Roboto',
                                          color: Colors.black54,
                                        ),
                                      ),
                                    )
                                  : RefreshIndicator(
                                      onRefresh: () async {
                                        setState(() {
                                          _searchDate = null;
                                          _searchDateController.clear();
                                        });
                                        await _fetchRegistros();
                                      },
                                      color: Colors.blue[700],
                                      backgroundColor: Colors.white,
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        physics: const AlwaysScrollableScrollPhysics(),
                                        itemCount: _registros.length,
                                        itemBuilder: (context, index) {
                                          final registro = _registros[index];
                                          final sistolica = (registro['sistolica'] as num).toInt();
                                          final diastolica = (registro['diastolica'] as num).toInt();
                                          final isHigh = sistolica >= 130 || diastolica >= 80;
                                          final isElevated = sistolica >= 120 && sistolica <= 129 && diastolica < 80;
                                          return FadeTransition(
                                            opacity: _fadeAnimation,
                                            child: Card(
                                              margin: EdgeInsets.symmetric(
                                                vertical: size.height * 0.005,
                                                horizontal: size.width * 0.01,
                                              ),
                                              elevation: 2,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              child: ListTile(
                                                contentPadding: EdgeInsets.symmetric(
                                                  horizontal: size.width * 0.03,
                                                  vertical: size.height * 0.005,
                                                ),
                                                title: Text(
                                                  'Fecha: ${registro['fecha']} - ${registro['hora']}',
                                                  style: TextStyle(
                                                    fontFamily: 'Roboto',
                                                    fontSize: size.width * 0.035,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black87,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                subtitle: Row(
                                                  children: [
                                                    Text(
                                                      'Presión: $sistolica/$diastolica mmHg',
                                                      style: TextStyle(
                                                        fontFamily: 'Roboto',
                                                        fontSize: size.width * 0.03,
                                                        color: isHigh
                                                            ? Colors.red[700]
                                                            : isElevated
                                                                ? Colors.yellow[700]
                                                                : Colors.green[700],
                                                      ),
                                                    ),
                                                    if (isHigh || isElevated)
                                                      Padding(
                                                        padding: EdgeInsets.only(left: size.width * 0.02),
                                                        child: Icon(
                                                          isHigh ? Icons.warning : Icons.info,
                                                          color: isHigh ? Colors.red[700] : Colors.yellow[700],
                                                          size: size.width * 0.04,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                trailing: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      icon: Icon(Icons.edit, color: Colors.blue[700], size: size.width * 0.045),
                                                      onPressed: () => _showEditDialog(registro),
                                                    ),
                                                    IconButton(
                                                      icon: Icon(Icons.delete, color: Colors.red[700], size: size.width * 0.045),
                                                      onPressed: () => _showDeleteDialog(registro),
                                                    ),
                                                  ],
                                                ),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sistolicaController.dispose();
    _diastolicaController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _searchDateController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}

class BloodPressureGraphScreen extends StatelessWidget {
  final List<dynamic> registros;

  const BloodPressureGraphScreen({super.key, required this.registros});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final maxY = registros.isNotEmpty
        ? (registros.map((r) => (r['sistolica'] as num).toDouble()).reduce((a, b) => a > b ? a : b) * 1.2).toDouble()
        : 300.0;
    final yInterval = maxY > 200 ? 50.0 : 25.0;
    print('Número de registros para el gráfico: ${registros.length}');
    print('Valores de registros: ${registros.map((r) => 'Sys: ${r['sistolica']}, Dia: ${r['diastolica']}').toList()}');
    final List<FlSpot> lowSpotsSys = [];
    final List<FlSpot> lowSpotsDia = [];
    final List<FlSpot> midSpotsSys = [];
    final List<FlSpot> midSpotsDia = [];
    final List<FlSpot> highSpotsSys = [];
    final List<FlSpot> highSpotsDia = [];
    for (var i = 0; i < registros.length; i++) {
      final sistolica = (registros[i]['sistolica'] as num).toDouble();
      final diastolica = (registros[i]['diastolica'] as num).toDouble();
      final spotSys = FlSpot(i.toDouble(), sistolica);
      final spotDia = FlSpot(i.toDouble(), diastolica);
      if (sistolica > 130 || diastolica > 80) {
        highSpotsSys.add(spotSys);
        highSpotsDia.add(spotDia);
        print('Índice $i (Sys: $sistolica, Dia: $diastolica) asignado a highSpots (rojo)');
      } else if (sistolica >= 120 && sistolica <= 129 && diastolica < 80) {
        midSpotsSys.add(spotSys);
        midSpotsDia.add(spotDia);
        print('Índice $i (Sys: $sistolica, Dia: $diastolica) asignado a midSpots (amarillo)');
      } else if (sistolica < 120 && diastolica < 80) {
        lowSpotsSys.add(spotSys);
        lowSpotsDia.add(spotDia);
        print('Índice $i (Sys: $sistolica, Dia: $diastolica) asignado a lowSpots (verde)');
      }
    }

    final Color lowColor = Colors.green[700] ?? const Color(0xFF388E3C); 
    final Color midColor = Colors.yellow[700] ?? const Color(0xFFFFCA28); 
    final Color highColor = Colors.red[700] ?? const Color(0xFFD32F2F); 

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gráfico de Presión Arterial',
          style: TextStyle(fontFamily: 'Roboto', color: Colors.white, fontSize: 20),
        ),
backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(size.width * 0.02),
          child: registros.isEmpty
              ? Center(
                  child: Text(
                    'No hay datos para mostrar en el gráfico.',
                    style: TextStyle(
                      fontSize: size.width * 0.04,
                      fontFamily: 'Roboto',
                      color: Colors.black54,
                    ),
                  ),
                )
              : SizedBox(
                  height: size.height * 0.6,
                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: registros.length.toDouble() - 1,
                      minY: 0,
                      maxY: maxY,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: yInterval,
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: size.width * 0.1,
                            interval: yInterval,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: size.width * 0.03,
                                  fontFamily: 'Roboto',
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: size.height * 0.1,
                            interval: (registros.length > 10 ? registros.length / 10 : 1).ceilToDouble(),
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() < 0 || value.toInt() >= registros.length) {
                                return const Text('');
                              }
                              final date = DateTime.parse(registros[value.toInt()]['fecha']);
                              final formattedDate = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
                              return Padding(
                                padding: EdgeInsets.only(top: size.height * 0.02),
                                child: Transform.rotate(
                                  angle: -45 * 3.1415927 / 180,
                                  child: Text(
                                    formattedDate,
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: size.width * 0.025,
                                      fontFamily: 'Roboto',
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          axisNameWidget: Text(
                            'Presión (mmHg)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Roboto',
                              color: Colors.black87,
                            ),
                          ),
                          axisNameSize: 20,
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: true, border: Border.all(color: Colors.black54)),
                      lineBarsData: [
                        // Líneas sistólicas
                        if (lowSpotsSys.isNotEmpty)
                          LineChartBarData(
                            spots: lowSpotsSys,
                            isCurved: true,
                            color: lowColor,
                            barWidth: size.width * 0.006,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                radius: size.width * 0.01,
                                color: lowColor,
                                strokeWidth: 2,
                                strokeColor: Colors.black54,
                              ),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: lowColor.withOpacity(0.3),
                            ),
                          ),
                        if (midSpotsSys.isNotEmpty)
                          LineChartBarData(
                            spots: midSpotsSys,
                            isCurved: true,
                            color: midColor,
                            barWidth: size.width * 0.006,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                radius: size.width * 0.01,
                                color: midColor,
                                strokeWidth: 2,
                                strokeColor: Colors.black54,
                              ),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: midColor.withOpacity(0.3),
                            ),
                          ),
                        if (highSpotsSys.isNotEmpty)
                          LineChartBarData(
                            spots: highSpotsSys,
                            isCurved: true,
                            color: highColor,
                            barWidth: size.width * 0.006,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                radius: size.width * 0.01,
                                color: highColor,
                                strokeWidth: 2,
                                strokeColor: Colors.black54,
                              ),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: highColor.withOpacity(0.3),
                            ),
                          ),
                        // Líneas diastólicas
                        if (lowSpotsDia.isNotEmpty)
                          LineChartBarData(
                            spots: lowSpotsDia,
                            isCurved: true,
                            color: lowColor,
                            barWidth: size.width * 0.006,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                radius: size.width * 0.01,
                                color: lowColor,
                                strokeWidth: 2,
                                strokeColor: Colors.black54,
                              ),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: lowColor.withOpacity(0.3),
                            ),
                          ),
                        if (midSpotsDia.isNotEmpty)
                          LineChartBarData(
                            spots: midSpotsDia,
                            isCurved: true,
                            color: midColor,
                            barWidth: size.width * 0.006,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                radius: size.width * 0.01,
                                color: midColor,
                                strokeWidth: 2,
                                strokeColor: Colors.black54,
                              ),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: midColor.withOpacity(0.3),
                            ),
                          ),
                        if (highSpotsDia.isNotEmpty)
                          LineChartBarData(
                            spots: highSpotsDia,
                            isCurved: true,
                            color: highColor,
                            barWidth: size.width * 0.006,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                radius: size.width * 0.01,
                                color: highColor,
                                strokeWidth: 2,
                                strokeColor: Colors.black54,
                              ),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: highColor.withOpacity(0.3),
                            ),
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