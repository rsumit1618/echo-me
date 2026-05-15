import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity;

  ConnectivityService([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  Stream<bool> get isOnlineStream async* {
    yield await isOnline();
    yield* _connectivity.onConnectivityChanged.map(_hasNetwork).distinct();
  }

  Future<bool> isOnline() async {
    return _hasNetwork(await _connectivity.checkConnectivity());
  }

  bool _hasNetwork(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }
}
