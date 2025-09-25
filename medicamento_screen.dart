import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class MedicamentoScreen extends StatefulWidget {
  const MedicamentoScreen({super.key});

  @override
  State<MedicamentoScreen> createState() => _MedicamentoScreenState();
}

class _MedicamentoScreenState extends State<MedicamentoScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  DateTime? _searchDate;
  final _nombreController = TextEditingController();
  final _dosisController = TextEditingController();
  final _sintomasController = TextEditingController();
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
      _mensaje = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    print('Token usado: $token');

    if (token == null) {
      setState(() {
        _mensaje = 'No estás autenticado.';
        _isLoading = false;
      });
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    try {
      final fechaParam = fecha ?? DateTime.now().toIso8601String().split('T')[0];
      final uri = Uri.parse('$_baseUrl/api/medicamentos').replace(queryParameters: {'fecha': fechaParam});
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      print('Respuesta del servidor: ${response.statusCode} - ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        if (response.headers['content-type']?.contains('application/json') ?? false) {
          setState(() {
            _registros = jsonDecode(response.body);
            _isLoading = false;
            _animationController.reset();
            _animationController.forward();
          });
          print('Registros recargados exitosamente: ${_registros.length} registros');
        } else {
          setState(() {
            _mensaje = 'Respuesta inesperada del servidor (no es JSON)';
            _isLoading = false;
          });
          print('Respuesta no es JSON: ${response.body}');
        }
      } else {
        String errorMsg = 'Error al obtener registros: ${response.statusCode}';
        if (response.headers['content-type']?.contains('application/json') ?? false) {
          try {
            errorMsg = jsonDecode(response.body)['msg'] ?? errorMsg;
          } catch (e) {
            print('Error al parsear mensaje de error: $e');
          }
        }
        setState(() {
          _mensaje = errorMsg;
          _isLoading = false;
        });
        print('Error al recargar registros: ${response.statusCode} - ${response.body}');
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
        _mensaje = 'Por favor, completa todos los campos obligatorios.';
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
    final String nombre = _nombreController.text.trim();
    final String dosis = _dosisController.text.trim();
    final String? sintomas = _sintomasController.text.trim().isEmpty ? null : _sintomasController.text.trim();
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/medicamentos'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'nombre': nombre,
          'dosis': dosis,
          'hora_toma': hora,
          'fecha': fecha,
          'sintomas': sintomas,
        }),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 201) {
        setState(() {
          _mensaje = 'Registro exitoso ✅';
          _nombreController.clear();
          _dosisController.clear();
          _sintomasController.clear();
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

  Future<void> _updateRegistro(int id, DateTime fecha, TimeOfDay hora, String nombre, String dosis, String? sintomas) async {
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
        Uri.parse('$_baseUrl/api/medicamentos/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'nombre': nombre,
          'dosis': dosis,
          'hora_toma': horaStr,
          'fecha': fechaStr,
          'sintomas': sintomas,
        }),
      ).timeout(const Duration(seconds: 10));

      print('Respuesta del backend (PUT /api/medicamentos/$id): ${response.statusCode} - ${response.body}');

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

  Future<void> _deleteMedicamento(int id, String fecha, String hora) async {
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
        Uri.parse('$_baseUrl/api/medicamentos/$id'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      print('Respuesta del backend (DELETE /api/medicamentos/$id): ${response.statusCode} - ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _mensaje = 'Solicitud de eliminación enviada. Confirma desde la notificación.';
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
                'Solicitud de eliminación enviada. Confirma desde la notificación.',
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
      print('Error en _deleteMedicamento: $e');
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
    final editTimeController = TextEditingController(text: registro['hora_toma'].substring(0, 5));
    final editNombreController = TextEditingController(text: registro['nombre']);
    final editDosisController = TextEditingController(text: registro['dosis']);
    final editSintomasController = TextEditingController(text: registro['sintomas'] ?? '');
    DateTime? editDate = DateTime.parse(registro['fecha']);
    TimeOfDay editTime = TimeOfDay(
      hour: int.parse(registro['hora_toma'].split(':')[0]),
      minute: int.parse(registro['hora_toma'].split(':')[1]),
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
                  controller: editNombreController,
                  decoration: InputDecoration(
                    labelText: 'Nombre del Medicamento',
                    prefixIcon: Icon(Icons.medical_services, color: Colors.blue[700]),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Introduce el nombre del medicamento';
                    }
                    return null;
                  },
                  style: const TextStyle(fontFamily: 'Roboto', color: Colors.black87),
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: editDosisController,
                  decoration: InputDecoration(
                    labelText: 'Dosis (ej. 500 mg)',
                    prefixIcon: Icon(Icons.medication, color: Colors.blue[700]),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Introduce la dosis';
                    }
                    return null;
                  },
                  style: const TextStyle(fontFamily: 'Roboto', color: Colors.black87),
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: editSintomasController,
                  decoration: InputDecoration(
                    labelText: 'Síntomas (opcional)',
                    prefixIcon: Icon(Icons.sick, color: Colors.blue[700]),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  maxLines: 3,
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
                if (editNombreController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Introduce el nombre del medicamento')),
                  );
                  return;
                }
                if (editDosisController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Introduce la dosis')),
                  );
                  return;
                }
                Navigator.pop(context);
                _updateRegistro(
                  registro['id'],
                  editDate!,
                  editTime,
                  editNombreController.text.trim(),
                  editDosisController.text.trim(),
                  editSintomasController.text.trim().isEmpty ? null : editSintomasController.text.trim(),
                );
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
    final size = MediaQuery.of(context).size;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          content: Text(
            'Confirma la eliminación del registro de medicamento del ${registro['fecha']} a las ${registro['hora_toma'].substring(0, 5)} (ID: ${registro['id']})',
            style: TextStyle(
              fontFamily: 'Roboto',
              color: Colors.black87,
              fontSize: size.width * 0.035,
            ),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: Colors.grey,
                  fontSize: size.width * 0.035,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteMedicamento(registro['id'], registro['fecha'], registro['hora_toma']);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.symmetric(
                  horizontal: size.width * 0.04,
                  vertical: size.height * 0.01,
                ),
              ),
              child: Text(
                'Eliminar',
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

  Widget _buildWarningRow({
    required BuildContext context,
    required Color color,
    required String message,
  }) {
    final size = MediaQuery.of(context).size;
    return Row(
      children: [
        Icon(Icons.warning, color: color, size: size.width * 0.05),
        SizedBox(width: size.width * 0.02),
        Flexible(
          child: Text(
            message,
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
        title: const Text('Registrar Medicamento', style: TextStyle(fontFamily: 'Roboto', color: Colors.white, fontSize: 18)),
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
                                  controller: _nombreController,
                                  decoration: InputDecoration(
                                    labelText: 'Nombre del Medicamento',
                                    labelStyle: const TextStyle(color: Colors.black87, fontFamily: 'Roboto'),
                                    prefixIcon: Icon(Icons.medical_services, color: Colors.blue[700], size: size.width * 0.04),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Introduce el nombre del medicamento';
                                    }
                                    return null;
                                  },
                                  style: TextStyle(fontFamily: 'Roboto', fontSize: size.width * 0.035, color: Colors.black87),
                                ),
                                SizedBox(height: size.height * 0.01),
                                TextFormField(
                                  controller: _dosisController,
                                  decoration: InputDecoration(
                                    labelText: 'Dosis (ej. 500 mg)',
                                    labelStyle: const TextStyle(color: Colors.black87, fontFamily: 'Roboto'),
                                    prefixIcon: Icon(Icons.medication, color: Colors.blue[700], size: size.width * 0.04),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Introduce la dosis';
                                    }
                                    return null;
                                  },
                                  style: TextStyle(fontFamily: 'Roboto', fontSize: size.width * 0.035, color: Colors.black87),
                                ),
                                SizedBox(height: size.height * 0.01),
                                TextFormField(
                                  controller: _sintomasController,
                                  decoration: InputDecoration(
                                    labelText: 'Síntomas (opcional)',
                                    labelStyle: const TextStyle(color: Colors.black87, fontFamily: 'Roboto'),
                                    prefixIcon: Icon(Icons.sick, color: Colors.blue[700], size: size.width * 0.04),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                  ),
                                  maxLines: 3,
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
                            'Advertencias Importantes',
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
                                colors: [Colors.white, Colors.red[50]!],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildWarningRow(
                                  context: context,
                                  color: Colors.red[700]!,
                                  message: 'No olvides verificar si eres alérgico al medicamento antes de tomarlo.',
                                ),
                                SizedBox(height: size.height * 0.01),
                                _buildWarningRow(
                                  context: context,
                                  color: Colors.yellow[700]!,
                                  message: 'Consulta con tu médico si experimentas efectos secundarios.',
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
                            ],
                          ),
                          SizedBox(height: size.height * 0.02),
                          if (_mensaje != null)
                            Container(
                              padding: EdgeInsets.all(10),
                              margin: EdgeInsets.symmetric(horizontal: size.width * 0.015),
                              decoration: BoxDecoration(
                                color: _mensaje!.contains('exitoso') || _mensaje!.contains('editado') || _mensaje!.contains('eliminado')
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _mensaje!,
                                style: TextStyle(
                                  color: _mensaje!.contains('exitoso') || _mensaje!.contains('editado') || _mensaje!.contains('eliminado')
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
                                        'No hay registros de medicamentos.',
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
                                                  '${registro['nombre']} - ${registro['dosis']}',
                                                  style: TextStyle(
                                                    fontFamily: 'Roboto',
                                                    fontSize: size.width * 0.035,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black87,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                subtitle: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Fecha: ${registro['fecha']} - ${registro['hora_toma']}',
                                                      style: TextStyle(
                                                        fontFamily: 'Roboto',
                                                        fontSize: size.width * 0.03,
                                                        color: Colors.black54,
                                                      ),
                                                    ),
                                                    if (registro['sintomas'] != null && registro['sintomas'].isNotEmpty)
                                                      Text(
                                                        'Síntomas: ${registro['sintomas']}',
                                                        style: TextStyle(
                                                          fontFamily: 'Roboto',
                                                          fontSize: size.width * 0.03,
                                                          color: Colors.black54,
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
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
    _nombreController.dispose();
    _dosisController.dispose();
    _sintomasController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _searchDateController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}

class MedicamentoSankeyScreen extends StatelessWidget {
  final List<dynamic> registros;

  const MedicamentoSankeyScreen({super.key, required this.registros});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final Map<String, Map<String, int>> symptomToMedication = {};
    for (var registro in registros) {
      final String? sintomas = registro['sintomas'];
      final String nombre = registro['nombre'];
      if (sintomas != null && sintomas.isNotEmpty) {
        if (!symptomToMedication.containsKey(sintomas)) {
          symptomToMedication[sintomas] = {};
        }
        symptomToMedication[sintomas]![nombre] = (symptomToMedication[sintomas]![nombre] ?? 0) + 1;
      }
    }

    final List<String> symptoms = symptomToMedication.keys.toList();
    final List<String> medications = symptomToMedication.values
        .expand((map) => map.keys)
        .toSet()
        .toList();
    final List<Map<String, dynamic>> links = [];
    for (var symptom in symptomToMedication.keys) {
      for (var medication in symptomToMedication[symptom]!.keys) {
        links.add({
          'source': symptoms.indexOf(symptom),
          'target': symptoms.length + medications.indexOf(medication),
          'value': symptomToMedication[symptom]![medication]!,
        });
      }
    }
    final List<String> nodes = [...symptoms, ...medications];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Relación Síntomas-Medicamentos',
          style: TextStyle(fontFamily: 'Roboto', color: Colors.white, fontSize: 20),
        ),
backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(size.width * 0.02),
          child: nodes.isEmpty || links.isEmpty
              ? Center(
                  child: Text(
                    'No hay datos suficientes para mostrar el gráfico. Registra síntomas y medicamentos.',
                    style: TextStyle(
                      fontSize: size.width * 0.04,
                      fontFamily: 'Roboto',
                      color: Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : CustomPaint(
                  size: Size(size.width * 0.9, size.height * 0.6),
                  painter: BarChartPainter(
                    nodes: nodes,
                    links: links,
                    symptomsLength: symptoms.length,
                    medications: medications,
                  ),
                ),
        ),
      ),
    );
  }
}

class BarChartPainter extends CustomPainter {
  final List<String> nodes;
  final List<Map<String, dynamic>> links;
  final int symptomsLength;
  final List<String> medications;

  BarChartPainter({
    required this.nodes,
    required this.links,
    required this.symptomsLength,
    required this.medications,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 1.0;

    final textStyle = TextStyle(
      color: Colors.black87,
      fontSize: size.width * 0.03,
      fontFamily: 'Roboto',
    );

    // Calcular el valor máximo para el eje Y
    final Map<int, int> symptomTotals = {};
    for (var link in links) {
      final sourceIndex = link['source'] as int;
      final value = link['value'] as int;
      symptomTotals[sourceIndex] = (symptomTotals[sourceIndex] ?? 0) + value;
    }
    final maxValue = symptomTotals.values.isNotEmpty ? symptomTotals.values.reduce(max) : 1;

    // Dimensiones del gráfico
    final chartHeight = size.height * 0.7;
    final chartWidth = size.width * 0.9;
    final barSpacing = size.width * 0.05;
    final barWidth = (chartWidth - (nodes.length ~/ 2 - 1) * barSpacing) / (nodes.length ~/ 2);
    final leftMargin = size.width * 0.1;
    final bottomMargin = size.height * 0.2;

    // Generar colores aleatorios para medicamentos
    final random = Random();
    final Map<String, Color> medicationColors = {
      for (var med in medications)
        med: Color.fromRGBO(
          random.nextInt(200) + 55,
          random.nextInt(200) + 55,
          random.nextInt(200) + 55,
          0.8,
        ),
    };

    // Dibujar barras apiladas
    for (int i = 0; i < symptomsLength; i++) {
      double currentHeight = 0;
      final x = leftMargin + i * (barWidth + barSpacing);

      // Dibujar cada segmento de la barra (medicamento)
      for (var med in medications) {
        final link = links.firstWhere(
          (link) => link['source'] == i && nodes[link['target'] as int] == med,
          orElse: () => {'value': 0},
        );
        final value = link['value'] as int;
        if (value > 0) {
          final barHeight = (value / maxValue) * chartHeight;
          paint.color = medicationColors[med]!;
          canvas.drawRect(
            Rect.fromLTWH(
              x,
              chartHeight - currentHeight - barHeight,
              barWidth,
              barHeight,
            ),
            paint,
          );
          currentHeight += barHeight;

          // Etiqueta con el valor dentro del segmento
          final span = TextSpan(text: value.toString(), style: textStyle);
          final textPainter = TextPainter(
            text: span,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
          );
          textPainter.layout(maxWidth: barWidth);
          textPainter.paint(
            canvas,
            Offset(
              x + barWidth / 2 - textPainter.width / 2,
              chartHeight - currentHeight + barHeight / 2 - textPainter.height / 2,
            ),
          );
        }
      }

      // Dibujar nombre del síntoma (eje X)
      final symptom = nodes[i];
      final span = TextSpan(text: symptom, style: textStyle);
      final textPainter = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      );
      textPainter.layout(maxWidth: barWidth);
      textPainter.paint(
        canvas,
        Offset(
          x + barWidth / 2 - textPainter.width / 2,
          chartHeight + bottomMargin * 0.2,
        ),
      );
    }

    // Dibujar eje Y
    paint.color = Colors.black87;
    paint.style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(leftMargin, 0),
      Offset(leftMargin, chartHeight),
      paint,
    );

    // Etiquetas del eje Y
    for (int i = 0; i <= 5; i++) {
      final value = (maxValue * i / 5).round();
      final y = chartHeight - (i / 5) * chartHeight;
      final span = TextSpan(text: value.toString(), style: textStyle);
      final textPainter = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(leftMargin - textPainter.width - 5, y - textPainter.height / 2),
      );
    }

    // Dibujar eje X
    canvas.drawLine(
      Offset(leftMargin, chartHeight),
      Offset(leftMargin + chartWidth, chartHeight),
      paint,
    );

    // Dibujar leyenda
    double legendY = chartHeight + bottomMargin * 0.5;
    for (int i = 0; i < medications.length; i++) {
      final med = medications[i];
      paint.color = medicationColors[med]!;
      paint.style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTWH(
          leftMargin + i * (size.width * 0.2),
          legendY,
          size.width * 0.05,
          size.width * 0.03,
        ),
        paint,
      );

      final span = TextSpan(text: med, style: textStyle);
      final textPainter = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      );
      textPainter.layout(maxWidth: size.width * 0.15);
      textPainter.paint(
        canvas,
        Offset(
          leftMargin + i * (size.width * 0.2) + size.width * 0.06,
          legendY - textPainter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}