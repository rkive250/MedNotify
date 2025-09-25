import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// Clase base para pantallas de métricas
abstract class MetricScreen extends StatefulWidget {
  final String title;
  final String metricType;

  const MetricScreen({required this.title, required this.metricType, super.key});
}

abstract class MetricScreenState<T extends MetricScreen> extends State<T> {
  List<dynamic> _registros = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchRegistros();
  }

  Future<void> _fetchRegistros() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token == null) {
      setState(() {
        _errorMessage = 'No estás autenticado.';
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(
            'https://ec1bff1533be.ngrok-free.app/api/registros_salud?tipo=${widget.metricType}'),
        headers: {
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _registros = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = jsonDecode(response.body)['msg'] ?? 'Error al obtener registros';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error de conexión: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'assets/mednotify.jpg',
            fit: BoxFit.contain,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.grey],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.black87))
              : _errorMessage != null
                  ? Center(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                          fontFamily: 'Kalam',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : _registros.isEmpty
                      ? Center(
                          child: Text(
                            'No hay registros de ${widget.title.toLowerCase()}.',
                            style: const TextStyle(
                              fontSize: 18,
                              fontFamily: 'Kalam',
                              color: Colors.black54,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _registros.length,
                          itemBuilder: (context, index) {
                            final registro = _registros[index];
                            return Card(
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                title: Text(
                                  _getMetricDisplay(registro),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Kalam',
                                  ),
                                ),
                                subtitle: Text(
                                  '${registro['fecha']} ${registro['hora']}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontFamily: 'Kalam',
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ),
    );
  }

  String _getMetricDisplay(dynamic registro);
}

class GlucoseScreen extends MetricScreen {
  const GlucoseScreen({super.key})
      : super(title: 'Glucosa', metricType: 'glucosa');

  @override
  State<GlucoseScreen> createState() => _GlucoseScreenState();
}

class _GlucoseScreenState extends MetricScreenState<GlucoseScreen> {
  @override
  String _getMetricDisplay(dynamic registro) {
    return 'Nivel: ${registro['valor']} mg/dL';
  }
}

class SystolicPressureScreen extends MetricScreen {
  const SystolicPressureScreen({super.key})
      : super(title: 'Presión Sistólica', metricType: 'presion_arterial');

  @override
  State<SystolicPressureScreen> createState() => _SystolicPressureScreenState();
}

class _SystolicPressureScreenState extends MetricScreenState<SystolicPressureScreen> {
  @override
  String _getMetricDisplay(dynamic registro) {
    return 'Sistólica: ${registro['sistolica']} mmHg';
  }
}

class DiastolicPressureScreen extends MetricScreen {
  const DiastolicPressureScreen({super.key})
      : super(title: 'Presión Diastólica', metricType: 'presion_arterial');

  @override
  State<DiastolicPressureScreen> createState() => _DiastolicPressureScreenState();
}

class _DiastolicPressureScreenState extends MetricScreenState<DiastolicPressureScreen> {
  @override
  String _getMetricDisplay(dynamic registro) {
    return 'Diastólica: ${registro['diastolica']} mmHg';
  }
}

class OxygenationScreen extends MetricScreen {
  const OxygenationScreen({super.key})
      : super(title: 'Oxigenación', metricType: 'oxigenacion');

  @override
  State<OxygenationScreen> createState() => _OxygenationScreenState();
}

class _OxygenationScreenState extends MetricScreenState<OxygenationScreen> {
  @override
  String _getMetricDisplay(dynamic registro) {
    return 'Nivel: ${registro['valor']} %';
  }
}

class HeartRateScreen extends MetricScreen {
  const HeartRateScreen({super.key})
      : super(title: 'Frecuencia Cardíaca', metricType: 'frecuencia_cardiaca');

  @override
  State<HeartRateScreen> createState() => _HeartRateScreenState();
}

class _HeartRateScreenState extends MetricScreenState<HeartRateScreen> {
  @override
  String _getMetricDisplay(dynamic registro) {
    return 'Frecuencia: ${registro['valor']} lpm';
  }
}

class MedicalRecordsScreen extends StatelessWidget {
  final VoidCallback onLogout;

  const MedicalRecordsScreen({required this.onLogout, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Registros'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'assets/mednotify.jpg',
            fit: BoxFit.contain,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: onLogout,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.grey],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: ListView(
            children: [
              Text(
                'Registros Médicos',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontFamily: 'Kalam',
                      color: Colors.black87,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _buildRecordButton(
                context,
                icon: Icons.bloodtype,
                label: 'Glucosa',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GlucoseScreen()),
                ),
              ),
              const SizedBox(height: 16),
              _buildRecordButton(
                context,
                icon: Icons.arrow_upward,
                label: 'Presión Sistólica',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SystolicPressureScreen()),
                ),
              ),
              const SizedBox(height: 16),
              _buildRecordButton(
                context,
                icon: Icons.arrow_downward,
                label: 'Presión Diastólica',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DiastolicPressureScreen()),
                ),
              ),
              const SizedBox(height: 16),
              _buildRecordButton(
                context,
                icon: Icons.air,
                label: 'Oxigenación',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OxygenationScreen()),
                ),
              ),
              const SizedBox(height: 16),
              _buildRecordButton(
                context,
                icon: Icons.monitor_heart,
                label: 'Frecuencia Cardíaca',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HeartRateScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 24, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontFamily: 'Kalam',
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        alignment: Alignment.centerLeft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 5,
      ),
    );
  }
}