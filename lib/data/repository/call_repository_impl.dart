import 'package:echo_me/core/errors/app_exception.dart';
import 'package:echo_me/data/model/call_model.dart';
import 'package:echo_me/data/source/remote/firestore_service.dart';
import 'package:echo_me/domain/entity/call.dart';
import 'package:echo_me/domain/repository/auth_repository.dart';
import 'package:echo_me/domain/repository/call_repository.dart';

class CallRepositoryImpl implements CallRepository {
  final AuthRepository _auth;
  final FirestoreService _firestore;

  CallRepositoryImpl(this._auth, this._firestore);

  @override
  Stream<List<CallLogEntry>> watchCallHistory() {
    final uid = _auth.firebaseUser?.uid;
    if (uid == null) return Stream.value(const []);
    return _firestore
        .userCalls(uid)
        .orderBy('startedAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CallModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  @override
  Future<void> recordCall(CallLogEntry call) async {
    final uid = _auth.firebaseUser?.uid;
    if (uid == null) throw const AppException('Please login before calling.');
    final model = CallModel(
      id: call.id,
      peerUserId: call.peerUserId,
      peerPhoneNumber: call.peerPhoneNumber,
      direction: call.direction,
      type: call.type,
      startedAt: call.startedAt,
      duration: call.duration,
    );
    await _firestore.userCalls(uid).doc(call.id).set(model.toMap());
  }
}
