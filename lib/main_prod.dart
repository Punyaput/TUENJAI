// lib/main_prod.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart'; // Keep this
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:firebase_app_check/firebase_app_check.dart';

// Import the main app structure
import 'app.dart';
// Import the PROD Firebase options
import 'firebase_options_prod.dart';
// Import the notification service
import 'services/notification_service.dart';

void main() async {
  // MUST ensure binding is initialized FIRST
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with PROD options
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // APP CHECK INITIALIZATION
  try {
    // Activate App Check with Play Integrity provider
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity, // AndroidProider.playIntegrity
      // appleProvider: AppleProvider.appAttest, // For iOS later
    );
    print("Firebase App Check activated.");
  } catch (e) {
    print("!!!!!!!! Firebase App Check activation failed: $e !!!!!!!!");
    // Decide if app should proceed if App Check fails to activate
  }

  // Initialize notifications AFTER Firebase is initialized
  try {
    // Ensure NotificationService().init() doesn't call initializeApp internally
    await NotificationService().init();
    print("Notification Service initialized.");
  } catch (e) {
    print("Error initializing NotificationService (PROD): $e");
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

  // Run the main app widget AFTER everything else is initialized
  runApp(const TuenJaiApp());
}
