import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AppImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const AppImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _buildPlaceholder();
    }

    final absoluteUrl = _ensureAbsoluteUrl(imageUrl);
    final isGif = absoluteUrl.toLowerCase().endsWith('.gif');

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: isGif
          ? Image.network(
              absoluteUrl,
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (context, error, stackTrace) =>
                  errorWidget ?? _buildPlaceholder(),
            )
          : CachedNetworkImage(
              imageUrl: absoluteUrl,
              width: width,
              height: height,
              fit: fit,
              placeholder: (context, url) => placeholder ?? _buildPlaceholder(),
              errorWidget: (context, url, error) {
                debugPrint("AppImage Error Log: $url -> $error");
                return errorWidget ?? _buildPlaceholder();
              },
            ),
    );
  }

  String _ensureAbsoluteUrl(String url) {
    if (url.isEmpty) return url;
    // Handle cases where the URL might be relative to the ourworld systems
    if (url.startsWith('/')) {
      // Assuming a default base if it's a relative path from our server
      return "https://admin.almadar-tech.com$url";
    }
    return url;
  }

  Widget _buildPlaceholder() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        'assets/images/placeholder.png',
        width: width,
        height: height,
        fit: fit,
      ),
    );
  }
}
