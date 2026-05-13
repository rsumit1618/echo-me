import 'package:echo_me/domain/entity/call.dart';

abstract class CallRepository {
  Stream<List<CallLogEntry>> watchCallHistory();
  Future<void> recordCall(CallLogEntry call);
}
