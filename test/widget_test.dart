import 'package:echo_me/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app themes are buildable', () {
    expect(AppTheme.light().useMaterial3, isTrue);
    expect(AppTheme.dark().brightness, equals(AppTheme.dark().colorScheme.brightness));
    expect(AppTheme.elite().colorScheme.primary, isNotNull);
  });
}
