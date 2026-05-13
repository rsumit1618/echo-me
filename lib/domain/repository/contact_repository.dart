import 'package:echo_me/domain/entity/contact.dart';

abstract class ContactRepository {
  Future<List<AppContact>> syncDeviceContacts();
  Stream<List<AppContact>> watchContacts();
}
