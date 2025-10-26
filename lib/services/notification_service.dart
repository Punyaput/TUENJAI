// lib/services/notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timezone/timezone.dart' as tz;

// --- Define the "Completed" action for interactive notifications ---
const String kNotificationActionComplete = 'COMPLETE_TASK';
const String kNotificationChannelId = 'tuenjai_tasks';
const String kNotificationChannelName = 'Task Reminders';
const String kNotificationChannelDesc =
    'Notifications for TuenJai tasks and habits.';

/// Handles background FCM messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // We'll mostly be using local notifications,
  // but this is here if we need server-side push (e.g., "Task Completed")
  // print("Handling a background message: ${message.messageId}");
}

class NotificationService {
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  /// Private helper to get the current user ID, or null
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  /// Initializes both Local and Push notification services.
  /// Call this in main.dart
  Future<void> init() async {
    // 1. Initialize Local Notifications
    await _initLocalNotifications();

    // 2. Initialize Firebase Messaging (Push Notifications)
    await _initFirebaseMessaging();
  }

  /// Initialize all settings for flutter_local_notifications
  Future<void> _initLocalNotifications() async {
    // Android settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('notification_icon');

    // iOS settings
    final DarwinInitializationSettings darwinSettings =
        DarwinInitializationSettings(
          // We now set these defaults for foreground presentation on iOS
          defaultPresentAlert: true,
          defaultPresentBadge: true,
          defaultPresentSound: true,
          // Define actions (e.g., "Completed" button)
          notificationCategories: [
            DarwinNotificationCategory(
              'task_due_category', // An ID for this category
              actions: [
                DarwinNotificationAction.plain(
                  kNotificationActionComplete, // The ID for the action
                  'ทำเสร็จแล้ว', // The button text
                  options: {DarwinNotificationActionOption.foreground},
                ),
              ],
            ),
          ],
        );

    final InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _localNotifications.initialize(
      settings,
      // This is called when a user taps a local notification
      onDidReceiveNotificationResponse: _onNotificationTapped,
      // This is called when a user taps an *action* (e.g., "Completed")
      onDidReceiveBackgroundNotificationResponse: _onActionTapped,
    );
  }

  /// Initialize FCM listeners and request permissions
  Future<void> _initFirebaseMessaging() async {
    // 1. Request Permission
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // 2. Get the FCM token and save it to the user's Firestore doc
    // This token is how the server knows which device to send a push to.
    final token = await _fcm.getToken();
    if (token != null && _userId != null) {
      await _saveTokenToFirestore(token);
    }
    // Listen for token refreshes
    _fcm.onTokenRefresh.listen(_saveTokenToFirestore);

    // 3. Set up listeners
    // Handles messages that come in while the app is in the foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // print("Got a message whilst in the foreground!");
      // print("Message data: ${message.data}");

      final notification = message.notification;
      final android = message.notification?.android; // Android specific details

      // --- ADD THIS BLOCK ---
      // If the message contains a notification payload, show it using flutter_local_notifications
      if (notification != null && android != null) {
        // Check if notification part exists
        _localNotifications.show(
          notification
              .hashCode, // Use a hash of the notification as a unique ID
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              kNotificationChannelId, // Use the same channel ID
              kNotificationChannelName,
              channelDescription: kNotificationChannelDesc,
              // Optional: Set icon, importance, priority etc. as needed
              icon:
                  'notification_icon', // Ensure this matches your drawable name
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(
              // Basic iOS details
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          // Optional: Pass data payload if you want to handle taps on this foreground notification
          // payload: message.data['screen'] ?? '', // Example
        );
      }
      // --- END ADDED BLOCK ---
    });

    // Handles taps on push notifications
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // print("User tapped push notification: ${message.data}");
      // TODO: Handle navigation, e.g., open a specific group
    });

    // Handles background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  /// Saves the device's FCM token to their user document.
  /// Cloud Functions will read this to send them notifications.
  Future<void> _saveTokenToFirestore(String token) async {
    if (_userId == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(_userId).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
      // print("My Token: $token");
    } catch (e) {
      // print("Error saving FCM token: $e");
    }
  }

  // --- INTERACTIVE NOTIFICATION HANDLERS ---

  /// Callback for when a user taps a notification's *action button*
  /// (e.g., "Completed")
  static void _onActionTapped(NotificationResponse response) {
    // print("Action Tapped! Payload: ${response.payload}");
    if (response.actionId == kNotificationActionComplete) {
      // User tapped "Completed"!
      final String? payload =
          response.payload; // Payload should be "groupId/taskId"
      if (payload != null) {
        _handleTaskCompletion(payload);
      }
    }
  }

  /// Callback for when a user taps the *body* of a local notification
  void _onNotificationTapped(NotificationResponse response) {
    // print("Notification Tapped! Payload: ${response.payload}");
    // TODO: Handle navigation
    // The payload could be "groupId/taskId"
    // We can parse this and navigate to the GroupDetailScreen
  }

  /// This is the background logic for the "Completed" button
  static Future<void> _handleTaskCompletion(String payload) async {
    // This is running in a background isolate.
    // We must initialize Firebase.
    // await Firebase.initializeApp(); // <-- May be needed here

    final parts = payload.split('/');
    if (parts.length < 2) return;

    final String type = parts[0];
    final String groupId = parts[1];
    final String docId = parts[2];
    final String? subTaskKey = (parts.length > 3) ? parts[3] : null;

    // print("Completing task: $type, $docId, $subTaskKey");

    try {
      final db = FirebaseFirestore.instance;
      final auth = FirebaseAuth.instance;
      // We can't get current user here easily.
      // For now, just mark as completed.
      // A better way is to pass the userId in the payload.
      // For now, let's just complete it.

      if (type == 'appointment') {
        await db
            .collection('groups')
            .doc(groupId)
            .collection('tasks')
            .doc(docId)
            .update({
              'status': 'completed',
              'completedAt': FieldValue.serverTimestamp(),
              // 'completedBy': _userId, // <-- Can't get this easily
            });
      } else if (type == 'habit' && subTaskKey != null) {
        await db
            .collection('groups')
            .doc(groupId)
            .collection('tasks')
            .doc(docId)
            .update({
              'completionHistory.$subTaskKey': 'completed',
              // 'completionHistory.${subTaskKey}_by': _userId,
            });
      }
    } catch (e) {
      // print("Error completing task from background: $e");
    }
  }

  // --- PUBLIC METHODS FOR SCHEDULING ---

  /// Schedules a local notification for a task
  Future<void> scheduleTaskNotification({
    required int id, // A unique ID for this notification
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String payload, // e.g., "appointment/groupId/taskId"
    bool withActions = false,
  }) async {
    // 1. Define Android-specific details
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          kNotificationChannelId,
          kNotificationChannelName,
          channelDescription: kNotificationChannelDesc,
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
          // Add actions if requested
          actions: withActions
              ? [
                  const AndroidNotificationAction(
                    kNotificationActionComplete, // ID
                    'ทำเสร็จแล้ว', // Label
                  ),
                ]
              : null,
        );

    // 2. Define iOS-specific details
    final DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
      // Use the category ID we defined in _initLocalNotifications
      categoryIdentifier: withActions ? 'task_due_category' : null,
    );

    // 3. Put them together
    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    // 4. Schedule the notification using zonedSchedule
    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local), // <-- Use TZDateTime
      notificationDetails,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      // The uiLocalNotificationDateInterpretation parameter is removed
      // to support your package version. The default is absoluteTime, which is correct.
    );
  }

  /// Cancels a specific notification
  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  /// Cancels ALL pending notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }
}
