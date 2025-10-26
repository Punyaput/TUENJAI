// lib/main_dev.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz;

// Import the main app structure
import 'app.dart';
// Import the DEV Firebase options
import 'firebase_options_dev.dart';
// Import the notification service if you use it globally
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with DEV options
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize notifications if needed
  try {
    await NotificationService().init();
  } catch (e) {
    // print("Error initializing NotificationService (DEV): $e");
  }

  // Initialize timezone data
  tz.initializeTimeZones();

  // Initialize localization
  await initializeDateFormatting('th', null);

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Run the main app widget
  runApp(const TuenJaiApp());
}
