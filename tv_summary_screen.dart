import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

class TVSummaryScreen extends StatefulWidget {
  const TVSummaryScreen({super.key});

  @override
  State<TVSummaryScreen> createState() => _TVSummaryScreenState();
}

class _TVSummaryScreenState extends State<TVSummaryScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<String, dynamic>? _dailyData;
  bool _isLoading = true;
  String? _errorMessage;
  final Map<DateTime, List<String>> _daysWithData = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchDailyData(_selectedDay!);
    _fetchDaysWithData();
  }

  Future<void> _fetchDaysWithData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) return;

    try {
      final endpoints = [
        '/api/glucosas',
        '/api/presiones_arteriales',
        '/api/oxigenaciones',
        '/api/frecuencias_cardiacas',
        '/api/medicamentos',
      ];

      for (var endpoint in endpoints) {
        final response = await http.get(
          Uri.parse('https://ec1bff1533be.ngrok-free.app$endpoint'),
          headers: {
            'Authorization': 'Bearer $token',
            'ngrok-skip-browser-warning': 'true',
          },
        ).timeout(const Duration(seconds: 10));

        if (!mounted) return;

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as List;
          for (var item in data) {
            final date = DateTime.parse(item['fecha']).toUtc();
            final dateKey = DateTime(date.year, date.month, date.day);
            _daysWithData[dateKey] = ['data']; 
          }
        }
      }
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error fetching days with data: $e');
    }
  }

  Future<void> _fetchDailyData(DateTime date) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) {
      setState(() {
        _errorMessage = 'No se encontró el token de autenticación';
        _isLoading = false;
      });
      return;
    }
    final dateStr =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    try {
      final endpoints = [
        '/api/glucosas',
        '/api/presiones_arteriales',
        '/api/oxigenaciones',
        '/api/frecuencias_cardiacas',
        '/api/medicamentos',
      ];
      final data = <String, dynamic>{};
      for (var endpoint in endpoints) {
        final response = await http.get(
          Uri.parse('https://ec1bff1533be.ngrok-free.app$endpoint?fecha=$dateStr'),
          headers: {
            'Authorization': 'Bearer $token',
            'ngrok-skip-browser-warning': 'true',
          },
        ).timeout(const Duration(seconds: 10));

        if (!mounted) return;

        if (response.statusCode == 200) {
          data[endpoint.split('/').last] = jsonDecode(response.body);
        } else {
          setState(() {
            _errorMessage = 'Error al cargar datos de $endpoint: ${response.body}';
            _isLoading = false;
          });
          return;
        }
      }

      setState(() {
        _dailyData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error de conexión: $e';
        _isLoading = false;
      });
    }
  }

  Widget _buildDataRow({
    required String title,
    required List<dynamic>? data,
    required String Function(dynamic) formatter,
    required double fontSize,
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
  }) {
    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: fontSize * 1.8),
          const SizedBox(width: 12.0),
          Expanded(
            flex: 5,
            child: Text(
              title,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto',
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data != null && data.isNotEmpty)
                  ...data.take(2).map(
                        (item) => Text(
                          formatter(item),
                          style: TextStyle(
                            fontSize: fontSize * 0.9,
                            fontFamily: 'Roboto',
                            color: Colors.black54,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                if (data == null || data.isEmpty)
                  Text(
                    'Sin datos',
                    style: TextStyle(
                      fontSize: fontSize * 0.9,
                      fontFamily: 'Roboto',
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataSection(Size size) {
    final fontSizeBase = size.width * 0.018;
    final dateFormatter = "${_selectedDay?.day}/${_selectedDay?.month}/${_selectedDay?.year}";

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Datos del $dateFormatter',
            style: TextStyle(
              fontSize: fontSizeBase * 1.3,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto',
              color: Colors.black87,
            ),
          ),
          SizedBox(height: size.height * 0.015),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Container(
                width: double.infinity,
                child: Table(
                  columnWidths: const {
                    0: IntrinsicColumnWidth(),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    TableRow(children: [
                      _buildDataRow(
                        title: 'Glucosa',
                        data: _dailyData?['glucosas'],
                        formatter: (g) => '${g['valor']} mg/dL, ${g['hora'] ?? 'N/A'}',
                        fontSize: fontSizeBase,
                        icon: Icons.bloodtype,
                        iconColor: const Color(0xFFB71C1C),
                        backgroundColor: Colors.white,
                      ),
                    ]),
                    TableRow(children: [
                      _buildDataRow(
                        title: 'Presión Arterial',
                        data: _dailyData?['presiones_arteriales'],
                        formatter: (p) =>
                            '${p['sistolica']}/${p['diastolica']} mmHg, ${p['hora'] ?? 'N/A'}',
                        fontSize: fontSizeBase,
                        icon: Icons.favorite,
                        iconColor: const Color(0xFFB71C1C),
                        backgroundColor: Colors.grey[100]!,
                      ),
                    ]),
                    TableRow(children: [
                      _buildDataRow(
                        title: 'Oxigenación',
                        data: _dailyData?['oxigenaciones'],
                        formatter: (o) => '${o['valor']}%, ${o['hora'] ?? 'N/A'}',
                        fontSize: fontSizeBase,
                        icon: Icons.air,
                        iconColor: const Color(0xFF0D47A1),
                        backgroundColor: Colors.white,
                      ),
                    ]),
                    TableRow(children: [
                      _buildDataRow(
                        title: 'Frecuencia Cardíaca',
                        data: _dailyData?['frecuencias_cardiacas'],
                        formatter: (f) => '${f['valor']} bpm, ${f['hora'] ?? 'N/A'}',
                        fontSize: fontSizeBase,
                        icon: Icons.monitor_heart,
                        iconColor: const Color(0xFFB71C1C),
                        backgroundColor: Colors.grey[100]!,
                      ),
                    ]),
                    TableRow(children: [
                      _buildDataRow(
                        title: 'Medicamentos',
                        data: _dailyData?['medicamentos'],
                        formatter: (m) =>
                            '${m['nombre']} (${m['dosis']}), ${m['hora_toma'] ?? 'N/A'}',
                        fontSize: fontSizeBase,
                        icon: Icons.medical_services,
                        iconColor: const Color(0xFF0D47A1),
                        backgroundColor: Colors.white,
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Resumen en TV',
          style: TextStyle(fontFamily: 'Roboto', color: Colors.white, fontSize: 26),
        ),
backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        elevation: 3,
        shadowColor: const Color(0xFF0D47A1).withOpacity(0.2),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: size.width * 0.06,
            vertical: size.height * 0.04,
          ),
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF0D47A1),
                    strokeWidth: 6,
                  ),
                )
              : _errorMessage != null
                  ? Center(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: const Color(0xFFB71C1C),
                          fontSize: size.width * 0.025,
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        bool isMobile = constraints.maxWidth < 800;

                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.white, Colors.blue[50]!],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: isMobile
                              ? Column(
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12.0),
                                      child: TableCalendar(
                                        firstDay: DateTime.utc(2020, 1, 1),
                                        lastDay: DateTime.utc(2030, 12, 31),
                                        focusedDay: _focusedDay,
                                        selectedDayPredicate: (day) =>
                                            isSameDay(_selectedDay, day),
                                        onDaySelected: (selectedDay, focusedDay) {
                                          setState(() {
                                            _selectedDay = selectedDay;
                                            _focusedDay = focusedDay;
                                          });
                                          _fetchDailyData(selectedDay);
                                        },
                                        calendarFormat: CalendarFormat.month,
                                        calendarStyle: CalendarStyle(
                                          defaultTextStyle: TextStyle(
                                            fontFamily: 'Roboto',
                                            fontSize: size.width * 0.035,
                                            color: Colors.black87,
                                          ),
                                          weekendTextStyle: TextStyle(
                                            fontFamily: 'Roboto',
                                            fontSize: size.width * 0.035,
                                            color: Colors.black87,
                                          ),
                                          selectedDecoration: const BoxDecoration(
                                            color: Color(0xFF0D47A1),
                                            shape: BoxShape.circle,
                                          ),
                                          todayDecoration: BoxDecoration(
                                            color: Colors.blue[200],
                                            shape: BoxShape.circle,
                                          ),
                                          markersMaxCount: 1,
                                          markerDecoration: const BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        headerStyle: HeaderStyle(
                                          titleTextStyle: TextStyle(
                                            fontFamily: 'Roboto',
                                            fontSize: size.width * 0.045,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                          formatButtonVisible: false,
                                        ),
                                        eventLoader: (day) {
                                          final dateKey =
                                              DateTime(day.year, day.month, day.day);
                                          return _daysWithData[dateKey] ?? [];
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Expanded(child: _buildDataSection(size)),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: size.width * 0.35,
                                      padding: const EdgeInsets.all(12.0),
                                      child: TableCalendar(
                                        firstDay: DateTime.utc(2020, 1, 1),
                                        lastDay: DateTime.utc(2030, 12, 31),
                                        focusedDay: _focusedDay,
                                        selectedDayPredicate: (day) =>
                                            isSameDay(_selectedDay, day),
                                        onDaySelected: (selectedDay, focusedDay) {
                                          setState(() {
                                            _selectedDay = selectedDay;
                                            _focusedDay = focusedDay;
                                          });
                                          _fetchDailyData(selectedDay);
                                        },
                                        calendarFormat: CalendarFormat.month,
                                        calendarStyle: CalendarStyle(
                                          defaultTextStyle: TextStyle(
                                            fontFamily: 'Roboto',
                                            fontSize: size.width * 0.018,
                                            color: Colors.black87,
                                          ),
                                          weekendTextStyle: TextStyle(
                                            fontFamily: 'Roboto',
                                            fontSize: size.width * 0.018,
                                            color: Colors.black87,
                                          ),
                                          selectedDecoration: const BoxDecoration(
                                            color: Color(0xFF0D47A1),
                                            shape: BoxShape.circle,
                                          ),
                                          todayDecoration: BoxDecoration(
                                            color: Colors.blue[200],
                                            shape: BoxShape.circle,
                                          ),
                                          markersMaxCount: 1,
                                          markerDecoration: const BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        headerStyle: HeaderStyle(
                                          titleTextStyle: TextStyle(
                                            fontFamily: 'Roboto',
                                            fontSize: size.width * 0.022,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                          formatButtonVisible: false,
                                        ),
                                        eventLoader: (day) {
                                          final dateKey =
                                              DateTime(day.year, day.month, day.day);
                                          return _daysWithData[dateKey] ?? [];
                                        },
                                      ),
                                    ),
                                    Expanded(child: _buildDataSection(size)),
                                  ],
                                ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}