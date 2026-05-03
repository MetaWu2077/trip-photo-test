import 'package:flutter/material.dart';
import '../models/photo.dart';

class PhotoGridItem extends StatelessWidget {
  final Photo photo;
  final VoidCallback onTap;

  const PhotoGridItem({super.key, required this.photo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          photo.thumbnailUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              color: Colors.grey[200],
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
          errorBuilder: (context, error, stack) => Container(
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}
