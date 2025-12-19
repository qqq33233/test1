import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Traffic Dashboard',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const TrafficDashboard(),
    );
  }
}

class TrafficDashboard extends StatefulWidget {
  final String? staffId;

  const TrafficDashboard({
    Key? key,
    this.staffId,
  }) : super(key: key);

  @override
  State<TrafficDashboard> createState() => _TrafficDashboardState();
}

class _TrafficDashboardState extends State<TrafficDashboard> {
  late WeatherService _weatherService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  WeatherData? _currentWeather;
  List<HourlyForecast>? _hourlyForecast;
  String _trafficStatus = '';
  List<TrafficAlert> _activeAlerts = [];
  bool _isLoading = true;
  List<RainPeriod> _rainPeriods = [];

  late Timer _updateTimer;

  @override
  void initState() {
    super.initState();
    _weatherService = WeatherService();
    _loadInitialData();
    _startMonitoring();
  }

  Future<void> _loadInitialData() async {
    final weather = await _weatherService.getWeatherData();
    final hourly = await _weatherService.getHourlyForecast();

    setState(() {
      _currentWeather = weather;
      _hourlyForecast = hourly;
      _isLoading = false;
    });

    _calculateRainPeriods();
    await _analyzeAndAlert();
  }

  void _calculateRainPeriods() {
    if (_hourlyForecast == null || _hourlyForecast!.isEmpty) return;

    _rainPeriods = [];
    int? rainStartHour;
    int? rainEndHour;

    for (int i = 0; i < _hourlyForecast!.length; i++) {
      final forecast = _hourlyForecast![i];
      final isRaining = forecast.weatherCode >= 51 && forecast.weatherCode <= 67;

      if (isRaining) {
        if (rainStartHour == null) {
          rainStartHour = forecast.hour;
        }
        rainEndHour = forecast.hour;
      } else {
        if (rainStartHour != null && rainEndHour != null) {
          _rainPeriods.add(RainPeriod(rainStartHour, rainEndHour));
          rainStartHour = null;
          rainEndHour = null;
        }
      }
    }

    if (rainStartHour != null && rainEndHour != null) {
      _rainPeriods.add(RainPeriod(rainStartHour, rainEndHour));
    }
  }

  void _startMonitoring() {
    _updateTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      _loadInitialData();
    });
  }

  Future<void> _analyzeAndAlert() async {
    if (_currentWeather == null) return;

    final alerts = <TrafficAlert>[];
    final now = DateTime.now();
    final currentHour = now.hour;

    final isPeakHour = currentHour >= 17 && currentHour <= 18;
    final isRaining = _currentWeather!.isRaining;
    final isCloudy = _currentWeather!.isCloudy;

    if (isRaining) {
      alerts.add(
        TrafficAlert(
          id: 'rain_${DateTime.now().millisecondsSinceEpoch}',
          type: AlertType.weather,
          title: '🌧️ Rain Alert',
          message: 'Traffic may increase due to rain. Drive carefully!',
          color: Colors.blue,
          timestamp: DateTime.now(),
          severity: 2,
        ),
      );
    }

    if (isPeakHour) {
      alerts.add(
        TrafficAlert(
          id: 'peak_${DateTime.now().millisecondsSinceEpoch}',
          type: AlertType.peakHour,
          title: '🚗 Peak Hour Alert',
          message: 'Heavy traffic expected (5-6 PM). Please plan accordingly.',
          color: Colors.orange,
          timestamp: DateTime.now(),
          severity: 1,
        ),
      );
    }

    if (isRaining && isPeakHour) {
      alerts.add(
        TrafficAlert(
          id: 'critical_${DateTime.now().millisecondsSinceEpoch}',
          type: AlertType.critical,
          title: '🚨 CRITICAL: Rain + Peak Hour',
          message: 'Heavy traffic expected! Rain during peak hours (5-6 PM). EXTREME congestion likely.',
          color: Colors.red,
          timestamp: DateTime.now(),
          severity: 3,
        ),
      );
    }

    if (isCloudy && !isRaining) {
      alerts.add(
        TrafficAlert(
          id: 'cloudy_${DateTime.now().millisecondsSinceEpoch}',
          type: AlertType.weather,
          title: '☁️ Cloudy Weather',
          message: 'May rain soon. Monitor weather.',
          color: Colors.grey,
          timestamp: DateTime.now(),
          severity: 1,
        ),
      );
    }

    String status = 'Light Traffic 🟢';
    if (isRaining && isPeakHour) {
      status = 'Heavy Traffic 🚨 (Rain + Peak Hour)';
    } else if (isPeakHour) {
      status = 'Heavy Traffic 🚨 (Peak Hour 5-6 PM)';
    } else if (isRaining) {
      status = 'Heavy Traffic 🔴 (Rain)';
    } else {
      status = 'Light Traffic 🟢';
    }

    for (var alert in alerts) {
      await _firestore.collection('traffic_alerts').add({
        'type': alert.type.toString(),
        'title': alert.title,
        'message': alert.message,
        'timestamp': alert.timestamp,
        'severity': alert.severity,
        'read': false,
      });
    }

    if (mounted) {
      setState(() {
        _activeAlerts = alerts;
        _trafficStatus = status;
      });
    }
  }

  Future<void> _broadcastAlert(TrafficAlert alert) async {
    await _firestore.collection('notifications').add({
      'type': 'traffic_alert',
      'title': alert.title,
      'message': alert.message,
      'severity': alert.severity,
      'timestamp': DateTime.now(),
      'read': false,
      'priority': alert.severity >= 3 ? 'high' : 'normal',
      'broadcastedBy': widget.staffId ?? 'system',
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alert broadcasted to users'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Traffic Dashboard',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF8B4F52),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadInitialData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _buildTrafficTab(),
      ),
    );
  }

  Widget _buildTrafficTab() {
    Color statusColor = Colors.green;
    if (_trafficStatus.contains('Heavy')) {
      statusColor = Colors.red;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Current Traffic Status',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(4)),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _trafficStatus,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: statusColor),
              ),
              const SizedBox(height: 16),
              _buildStatRow('🕐 Current Time', '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}'),
              _buildStatRow('📍 Location', 'TAR UMT Campus'),
              _buildStatRow('🌡️ Temperature', '${_currentWeather?.temperature.toStringAsFixed(1)}°C'),
              _buildStatRow('☁️ Weather', _currentWeather?.condition ?? 'Unknown'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (_rainPeriods.isNotEmpty) ...[
          const Text('⚠️ Future Rain & Traffic Warning', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
          const SizedBox(height: 12),
          ..._rainPeriods.map((period) {
            final startHour = period.startHour;
            final endHour = period.endHour;
            final isPeakHourRain = (startHour >= 17 && startHour <= 18) || (endHour >= 17 && endHour <= 18);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isPeakHourRain ? Colors.red.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isPeakHourRain ? Colors.red.withOpacity(0.5) : Colors.orange.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🌧️ $startHour:00 - $endHour:00',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isPeakHourRain ? Colors.red : Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isPeakHourRain
                          ? '🚨 Heavy rain during PEAK HOUR! May cause EXTREME traffic jam. Please take alert!'
                          : '⚠️ Heavy rain expected. May cause traffic jam. Please take alert!',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
          const SizedBox(height: 24),
        ],
        const Text('Peak Hours & Traffic Times', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🚨 HEAVY Traffic: 5:00 PM - 6:00 PM',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13),
              ),
              SizedBox(height: 6),
              Text(
                'Peak departure time - Students & staff leaving campus',
                style: TextStyle(fontSize: 11, color: Colors.black87),
              ),
            ],
          ),
        ),

      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _updateTimer.cancel();
    super.dispose();
  }
}

class WeatherService {
  final String baseUrl = 'https://api.open-meteo.com/v1/forecast';
  final double latitude = 3.1957;
  final double longitude = 101.5245;

  Future<WeatherData> getWeatherData() async {
    final url = '$baseUrl'
        '?latitude=$latitude'
        '&longitude=$longitude'
        '&current=temperature_2m,relative_humidity_2m,weather_code,cloud_cover,wind_speed_10m'
        '&timezone=Asia/Kuala_Lumpur';

    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    final data = jsonDecode(response.body);

    return WeatherData.fromJson(data);
  }

  Future<List<HourlyForecast>> getHourlyForecast() async {
    final url = '$baseUrl'
        '?latitude=$latitude'
        '&longitude=$longitude'
        '&hourly=weather_code,cloud_cover'
        '&forecast_days=1'
        '&timezone=Asia/Kuala_Lumpur';

    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    final data = jsonDecode(response.body);

    final hourly = data['hourly'] as Map<String, dynamic>;
    final times = (hourly['time'] as List).cast<String>();
    final codes = (hourly['weather_code'] as List).cast<int>();
    final clouds = (hourly['cloud_cover'] as List).cast<int>();

    final forecasts = <HourlyForecast>[];
    for (int i = 0; i < times.length; i++) {
      final hour = int.parse(times[i].split('T')[1].split(':')[0]);
      forecasts.add(HourlyForecast(
        hour: hour,
        weatherCode: codes[i],
        cloudCover: clouds[i],
      ));
    }

    return forecasts;
  }
}

class WeatherData {
  final double temperature;
  final int humidity;
  final int weatherCode;
  final int cloudCover;
  final double windSpeed;

  WeatherData({
    required this.temperature,
    required this.humidity,
    required this.weatherCode,
    required this.cloudCover,
    required this.windSpeed,
  });

  bool get isRaining => weatherCode >= 51 && weatherCode <= 67;
  bool get isCloudy => cloudCover > 50;

  String get condition {
    if (isRaining) return '🌧️ Rainy';
    if (isCloudy) return '☁️ Cloudy';
    return '☀️ Clear';
  }

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final current = json['current'] ?? {};

    return WeatherData(
      temperature: ((current['temperature_2m'] ?? 0) as num).toDouble(),
      humidity: (current['relative_humidity_2m'] ?? 0) as int,
      weatherCode: (current['weather_code'] ?? 0) as int,
      cloudCover: (current['cloud_cover'] ?? 0) as int,
      windSpeed: ((current['wind_speed_10m'] ?? 0) as num).toDouble(),
    );
  }
}

class HourlyForecast {
  final int hour;
  final int weatherCode;
  final int cloudCover;

  HourlyForecast({
    required this.hour,
    required this.weatherCode,
    required this.cloudCover,
  });
}

class RainPeriod {
  final int startHour;
  final int endHour;

  RainPeriod(this.startHour, this.endHour);
}

enum AlertType { weather, peakHour, critical }

class TrafficAlert {
  final String id;
  final AlertType type;
  final String title;
  final String message;
  final Color color;
  final DateTime timestamp;
  final int severity;

  TrafficAlert({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.color,
    required this.timestamp,
    required this.severity,
  });
}