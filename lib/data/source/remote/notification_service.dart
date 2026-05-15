import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  final FirebaseMessaging messaging;

  NotificationService({FirebaseMessaging? messaging})
    : messaging = messaging ?? FirebaseMessaging.instance;

  Future<String?> prepareDeviceToken() async {
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    return messaging.getToken();
  }
}
