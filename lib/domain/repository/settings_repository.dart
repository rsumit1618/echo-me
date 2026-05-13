import 'package:echo_me/core/theme/app_theme.dart';

abstract class SettingsRepository {
  Future<AppThemeMode> loadTheme();
  Future<void> saveTheme(AppThemeMode mode);
}
