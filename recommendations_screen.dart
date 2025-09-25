import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

void main() {
  runApp(const HealthMonitorApp());
}

class HealthMonitorApp extends StatelessWidget {
  const HealthMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monitoreo de Salud',
      debugShowCheckedModeBanner: false,
      home: const HealthDashboard(),
    );
  }
}

class HealthDashboard extends StatelessWidget {
  const HealthDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTV = size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoreo de Salud'),
        centerTitle: true,
        backgroundColor: Colors.teal,
      ),
      body: ListView(
        padding: EdgeInsets.all(isTV ? 40 : 16),
        children: [
          _buildParameterSection(
            title: "Glucosa",
            unidad: "mg/dL",
            frecuencia: "Antes y después de cada comida o si hay síntomas.",
            chart: _buildDonutChartWithRanges(
              verde: 40,
              amarillo: 30,
              rojo: 30,
              rangeLabels: ["70-110", "111-125", "+126"],
              colors: [Colors.green, Colors.orange, Colors.red],
            ),
            consejos: [
              ["Rango bajo (-70)", "Consume jugos o frutas dulces. Mide en 15 min nuevamente."],
              ["Rango normal (70-110)", "Mantén una dieta balanceada y ejercicio regular."],
              ["Rango alto (+126)", "Hidrátate, camina y consulta a tu médico."],
            ],
            rangosEdad: [
              ["0-14", "80-120"],
              ["15-45", "70-110"],
              ["46+", "80-130"],
            ],
            medicamentos: [
              ["Insulina", "Usada para diabetes tipo 1 y a veces tipo 2."],
              ["Metformina", "Medicamento oral para diabetes tipo 2."],
            ],
            isTV: isTV,
          ),
          _buildParameterSection(
            title: "Presión Arterial",
            unidad: "mmHg",
            frecuencia: "Por la mañana y noche, o si sientes mareo/dolor de cabeza.",
            chart: _buildDonutChartWithRanges(
              verde: 50,
              amarillo: 30,
              rojo: 20,
              rangeLabels: ["90-120", "121-139", "+140"],
              colors: [Colors.green, Colors.orange, Colors.red],
            ),
            consejos: [
              ["Rango bajo (-90)", "Hidrátate, evita cambios bruscos de posición."],
              ["Rango normal (90-120)", "Mantén una dieta baja en sal y ejercicio."],
              ["Rango alto (+140)", "Reduce consumo de sal, relájate y consulta a tu médico."],
            ],
            rangosEdad: [
              ["18-40", "90-120"],
              ["41-60", "90-130"],
              ["61+", "90-140"],
            ],
            medicamentos: [
              ["Diuréticos", "Ayudan a reducir la presión eliminando exceso de agua."],
              ["Betabloqueantes", "Reducen la frecuencia cardíaca y presión arterial."],
            ],
            isTV: isTV,
          ),
          _buildParameterSection(
            title: "Oxigenación",
            unidad: "%",
            frecuencia: "Cada vez que sientas dificultad para respirar o cansancio.",
            chart: _buildDonutChartWithRanges(
              verde: 60,
              amarillo: 25,
              rojo: 15,
              rangeLabels: ["95-100", "90-94", "-90"],
              colors: [Colors.green, Colors.orange, Colors.red],
            ),
            consejos: [
              ["Normal (95-100)", "Mantén ambientes limpios y evita fumar."],
              ["Moderado (90-94)", "Haz respiración profunda y descansa."],
              ["Bajo (-90)", "Consulta a un médico urgentemente."],
            ],
            rangosEdad: [
              ["Todas las edades", "95-100"],
            ],
            medicamentos: [
              ["Oxígeno suplementario", "Uso en pacientes con bajos niveles."],
            ],
            isTV: isTV,
          ),
          _buildParameterSection(
            title: "Frecuencia Cardíaca",
            unidad: "bpm",
            frecuencia: "En reposo y después de ejercicio para control.",
            chart: _buildDonutChartWithRanges(
              verde: 50,
              amarillo: 30,
              rojo: 20,
              rangeLabels: ["60-100", "101-110", "+110"],
              colors: [Colors.green, Colors.orange, Colors.red],
            ),
            consejos: [
              ["Normal (60-100)", "Ejercicio moderado y descanso adecuado."],
              ["Elevada (101-110)", "Controla la ansiedad y evita estimulantes."],
              ["Alta (+110)", "Consulta al médico si persiste."],
            ],
            rangosEdad: [
              ["Adultos", "60-100"],
              ["Atletas", "40-60 (puede ser normal)"],
            ],
            medicamentos: [
              ["Betabloqueantes", "Para controlar la frecuencia cardiaca alta."],
            ],
            isTV: isTV,
          ),
        ],
      ),
    );
  }

  Widget _buildParameterSection({
    required String title,
    required String unidad,
    required String frecuencia,
    required Widget chart,
    required List<List<String>> consejos,
    required List<List<String>> rangosEdad,
    required List<List<String>> medicamentos,
    required bool isTV,
  }) {
    return Card(
      color: Colors.grey[50],
      margin: const EdgeInsets.symmetric(vertical: 20),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: EdgeInsets.all(isTV ? 32 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: isTV ? 48 : 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[800])),
            const SizedBox(height: 10),
            SizedBox(height: isTV ? 400 : 200, child: chart),
            const SizedBox(height: 30),
            Text("Frecuencia recomendada:",
                style: TextStyle(
                    fontSize: isTV ? 24 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal)),
            const SizedBox(height: 8),
            Text(frecuencia,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: isTV ? 22 : 16)),
            const SizedBox(height: 30),
            Text("Recomendaciones:",
                style: TextStyle(
                    fontSize: isTV ? 28 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal)),
            const SizedBox(height: 12),
            _buildTable(consejos, ["Condición", "Recomendación"], Colors.teal, isTV),
            const SizedBox(height: 30),
            Text("Rangos por edad:",
                style: TextStyle(
                    fontSize: isTV ? 28 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal)),
            const SizedBox(height: 12),
            _buildTable(rangosEdad, ["Edad", "Rango"], Colors.blueGrey, isTV),
            const SizedBox(height: 30),
            Text("Medicamentos comunes:",
                style: TextStyle(
                    fontSize: isTV ? 28 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal)),
            const SizedBox(height: 12),
            _buildTable(medicamentos, ["Medicamento", "Uso"], Colors.deepPurple, isTV),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(List<List<String>> data, List<String> headers, MaterialColor color, bool isTV) {
    return Table(
      border: TableBorder.all(color: color.shade300, width: 2),
      columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(5)},
      children: [
        TableRow(
          decoration: BoxDecoration(color: color.shade100),
          children: headers
              .map((h) => Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(h,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isTV ? 22 : 16,
                            color: color[900])),
                  ))
              .toList(),
        ),
        for (var row in data)
          TableRow(children: [
            for (var cell in row)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(cell,
                    style: TextStyle(fontSize: isTV ? 20 : 14, fontWeight: FontWeight.w500)),
              ),
          ])
      ],
    );
  }

  /// Gráfica de dona con rangos y colores
  Widget _buildDonutChartWithRanges({
    required double verde,
    required double amarillo,
    required double rojo,
    required List<String> rangeLabels,
    required List<Color> colors,
  }) {
    final sections = [
      PieChartSectionData(
        value: verde,
        color: colors[0],
        title: '${rangeLabels[0]}',
        radius: 70,
        titleStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        value: amarillo,
        color: colors[1],
        title: '${rangeLabels[1]}',
        radius: 70,
        titleStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        value: rojo,
        color: colors[2],
        title: '${rangeLabels[2]}',
        radius: 70,
        titleStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    ];
    return PieChart(
      PieChartData(
        sections: sections,
        centerSpaceRadius: 40,
        sectionsSpace: 2,
        borderData: FlBorderData(show: false),
        pieTouchData: PieTouchData(enabled: false),
      ),
    );
  }
}
