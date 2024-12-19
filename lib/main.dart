import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enable background execution
  final androidConfig = FlutterBackgroundAndroidConfig(
    notificationTitle: "Emergency Alert Service",
    notificationText: "Running in the background to monitor shake events.",
    notificationImportance: AndroidNotificationImportance.high,
    enableWifiLock: true,
  );

  bool success = await FlutterBackground.initialize(androidConfig: androidConfig);
  if (success) {
    await FlutterBackground.enableBackgroundExecution();
  }

  // Request necessary permissions
  await requestPermissions();

  runApp(const MyApp());
}

Future<void> requestPermissions() async {
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
  if (await Permission.sensors.isDenied) {
    await Permission.sensors.request();
  }
}

// Root Widget
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ShakeCounterState(),
      child: MaterialApp(
        title: 'Shake Counter',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromARGB(255, 255, 108, 63),
          ),
        ),
        home: const ShakeCounterHomePage(),
      ),
    );
  }
}

// State Management with Provider
class ShakeCounterState extends ChangeNotifier {
  int _shakeCount = 0;
  final _shakeThreshold = 15.0;
  AccelerometerEvent? _previousEvent;

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  int get shakeCount => _shakeCount;
  double get shakeThreshold => _shakeThreshold;

  ShakeCounterState() {
    _initializeNotifications();
    _startListening();
  }

  void _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);
    await _notificationsPlugin.initialize(initializationSettings);
  }

  void _showEmergencyNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'emergency_channel',
      'Emergency Alerts',
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails notificationDetails =
    NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      0,
      'Emergency Alert',
      'Shake count reached 75!',
      notificationDetails,
    );
  }

  void _startListening() {
    accelerometerEventStream().listen((AccelerometerEvent event) {
      if (_previousEvent != null) {
        double deltaX = (event.x - _previousEvent!.x).abs();
        double deltaY = (event.y - _previousEvent!.y).abs();
        double deltaZ = (event.z - _previousEvent!.z).abs();

        double shakeIntensity = sqrt(deltaX * deltaX +
            deltaY * deltaY +
            deltaZ * deltaZ);

        if (shakeIntensity > _shakeThreshold) {
          _shakeCount++;
          notifyListeners();

          // Trigger emergency alert when shake count reaches 75
          if (_shakeCount == 75) {
            _showEmergencyNotification();
          }
        }
      }
      _previousEvent = event;
    });
  }

  void resetShakeCount() {
    _shakeCount = 0;
    notifyListeners(); // Reset UI.
  }
}

// Home Page
class ShakeCounterHomePage extends StatelessWidget {
  const ShakeCounterHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    var shakeState = context.watch<ShakeCounterState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shake Counter'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Shake Count:',
              style: TextStyle(fontSize: 20),
            ),
            Text(
              '${shakeState.shakeCount}',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 20),
            if (shakeState.shakeCount >= 75) // Show text message for alert
              const Text(
                'Emergency Alert! Shake count reached 75!',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: shakeState.resetShakeCount,
              child: const Text('Reset Counter'),
            ),
          ],
        ),
      ),
    );
  }
}

