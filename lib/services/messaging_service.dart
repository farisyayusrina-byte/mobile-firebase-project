import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';
import 'firestore_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

class MessagingService {
  MessagingService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _local = localNotifications ?? FlutterLocalNotificationsPlugin();

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _local;
  final FirestoreService _firestore = FirestoreService();

  static const _channel = AndroidNotificationChannel(
    'split_notifications',
    'Split Notifications',
    description: 'Notifikasi bil dan perbelanjaan Split',
    importance: Importance.high,
  );

  Future<void> initialize({required String userId}) async {
    await _requestPermission();
    await _initLocalNotifications();

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final token = await _messaging.getToken();
    if (token != null) {
      await _firestore.saveFcmToken(userId, token);
    }

    _messaging.onTokenRefresh.listen((newToken) {
      _firestore.saveFcmToken(userId, newToken);
    });

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
  }

  Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    );
    await _local.initialize(settings: initSettings);

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await showLocal(
      id: notification.hashCode,
      title: notification.title ?? 'Split',
      body: notification.body ?? '',
    );
  }

  /// Show a notification while the app is open (also used by [NotificationService]).
  Future<void> showLocal({
    required int id,
    required String title,
    required String body,
  }) async {
    await _local.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  Future<String?> getToken() => _messaging.getToken();
}
