import 'dart:typed_data';

import 'package:flutter/material.dart';

class AgentProfileAvatar extends StatelessWidget {
  final Uint8List? photoBytes;
  final double size;
  final double borderRadius;
  final Widget placeholder;

  const AgentProfileAvatar({
    super.key,
    required this.photoBytes,
    required this.size,
    required this.placeholder,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: photoBytes == null
          ? Center(child: placeholder)
          : Image.memory(
              photoBytes!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Center(child: placeholder),
            ),
    );
  }
}
