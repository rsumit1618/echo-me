class PhoneNormalizer {
  static String normalize(String raw, {String defaultCountryCode = '+91'}) {
    var value = raw.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (value.startsWith('00')) value = '+${value.substring(2)}';
    if (!value.startsWith('+')) {
      value = value.replaceFirst(RegExp(r'^0+'), '');
      value = '$defaultCountryCode$value';
    }
    return value;
  }

  /// Accepts:
  /// - "XXXXXXXXXX" (10 digits)
  /// - "+91XXXXXXXXXX" (11 digits with +91)
  /// - "911XXXXXXXXXX" (starts with 91)
  /// Returns true only for valid Indian mobile numbers (10 digits total).
  static bool isValidIndian10Digit(String raw) {
    final value = raw.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // +91XXXXXXXXXX
    if (RegExp(r'^\+91\d{10}$').hasMatch(value)) return true;

    // 91XXXXXXXXXX
    if (RegExp(r'^91\d{10}$').hasMatch(value)) return true;

    // XXXXXXXXXX
    return RegExp(r'^\d{10}$').hasMatch(value);
  }

  /// Normalizes to the Indian 10-digit form (XXXXXXXXXX) or returns null.
  static String? normalizeToIndian10DigitOrNull(String raw) {
    final value = raw.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');

    if (RegExp(r'^\+91\d{10}$').hasMatch(value)) {
      return value.substring(3); // drop +91
    }

    if (RegExp(r'^91\d{10}$').hasMatch(value)) {
      return value.substring(2); // drop 91
    }

    if (RegExp(r'^\d{10}$').hasMatch(value)) {
      return value;
    }

    return null;
  }
}
