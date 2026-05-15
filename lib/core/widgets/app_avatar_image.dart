import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AppAvatarImage extends StatefulWidget {
  final String? imageUrl;
  final double radius;
  final Color backgroundColor;
  final Color foregroundColor;
  final Widget fallback;

  const AppAvatarImage({
    super.key,
    required this.imageUrl,
    required this.radius,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.fallback,
  });

  @override
  State<AppAvatarImage> createState() => _AppAvatarImageState();
}

class _AppAvatarImageState extends State<AppAvatarImage> {
  ImageProvider? _image;
  String? _imageKey;

  @override
  void initState() {
    super.initState();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant AppAvatarImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _resolveImage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dimension = widget.radius * 2;
    return ClipOval(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: dimension,
        height: dimension,
        color: widget.backgroundColor,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: IconTheme.merge(
                data: IconThemeData(color: widget.foregroundColor),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: widget.foregroundColor),
                  child: widget.fallback,
                ),
              ),
            ),
            if (_image != null)
              Image(
                key: ValueKey(_imageKey),
                image: _image!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }

  void _resolveImage() {
    final image = widget.imageUrl?.trim();
    if (image == null || image.isEmpty) {
      _image = null;
      _imageKey = null;
      return;
    }

    try {
      ImageProvider resolvedImage;
      if (image.startsWith('data:image')) {
        final commaIndex = image.indexOf(',');
        if (commaIndex == -1) {
          _image = null;
          _imageKey = null;
          return;
        }
        resolvedImage = MemoryImage(
          base64Decode(image.substring(commaIndex + 1)),
        );
      } else {
        resolvedImage = CachedNetworkImageProvider(image);
      }
      _image = resolvedImage;
      _imageKey = image;
    } catch (_) {
      _image = null;
      _imageKey = null;
    }
  }
}
