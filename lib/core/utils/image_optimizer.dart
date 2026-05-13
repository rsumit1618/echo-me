import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageOptimizer {
  static const int maxBytes = 100 * 1024;

  Future<File> compressToUnder100Kb(File input) async {
    final tempDir = await getTemporaryDirectory();
    var quality = 78;
    File? lastOutput;

    while (quality >= 28) {
      final target = p.join(
        tempDir.path,
        'echo_${DateTime.now().microsecondsSinceEpoch}_$quality.jpg',
      );
      final result = await FlutterImageCompress.compressAndGetFile(
        input.path,
        target,
        quality: quality,
        minWidth: 1280,
        minHeight: 1280,
        format: CompressFormat.jpeg,
        keepExif: false,
      );
      if (result == null) break;
      lastOutput = File(result.path);
      if (await lastOutput.length() <= maxBytes) return lastOutput;
      quality -= 10;
    }

    return lastOutput ?? input;
  }
}
