import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';

class AgentProfilePhoto extends StatefulWidget {
  const AgentProfilePhoto({
    super.key,
    required this.photoBytes,
    required this.size,
    required this.placeholder,
    this.borderRadius = 14,
    this.circleThumbnail = false,
    this.heroTag,
    this.semanticLabel = 'Perbesar foto profil agen',
  });

  final Uint8List? photoBytes;
  final double size;
  final Widget placeholder;
  final double borderRadius;
  final bool circleThumbnail;
  final Object? heroTag;
  final String semanticLabel;

  @override
  State<AgentProfilePhoto> createState() => _AgentProfilePhotoState();
}

class _AgentProfilePhotoState extends State<AgentProfilePhoto> {
  final Object _defaultHeroTag = Object();

  Object get _heroTag => widget.heroTag ?? _defaultHeroTag;

  Widget _photo(double size, {required BoxFit fit}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: SizedBox(
        width: size,
        height: size,
        child: Image.memory(
          widget.photoBytes!,
          fit: fit,
          errorBuilder: (_, _, _) => Center(child: widget.placeholder),
        ),
      ),
    );
  }

  Future<void> _showPhoto() {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final screenSize = MediaQuery.sizeOf(dialogContext);
        final photoSize = (screenSize.width * 0.9).clamp(
          0.0,
          screenSize.height * 0.78,
        );

        return AnimatedBuilder(
          animation: animation,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            child: Hero(
              tag: _heroTag,
              child: _photo(photoSize, fit: BoxFit.contain),
            ),
          ),
          builder: (context, photo) {
            final progress = Curves.easeOutCubic.transform(animation.value);
            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(dialogContext).pop(),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 9 * progress,
                        sigmaY: 9 * progress,
                      ),
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.52 * progress),
                      ),
                    ),
                  ),
                ),
                Center(child: photo),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final photoBytes = widget.photoBytes;
    if (photoBytes == null) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: widget.circleThumbnail
              ? null
              : BorderRadius.circular(widget.borderRadius),
          shape: widget.circleThumbnail ? BoxShape.circle : BoxShape.rectangle,
          border: widget.circleThumbnail
              ? Border.all(color: Colors.white.withValues(alpha: 0.28))
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        child: widget.placeholder,
      );
    }

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTap: _showPhoto,
        child: Hero(
          tag: _heroTag,
          child: widget.circleThumbnail
              ? Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ClipOval(
                    child: Image.memory(
                      photoBytes,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          Center(child: widget.placeholder),
                    ),
                  ),
                )
              : _photo(widget.size, fit: BoxFit.cover),
        ),
      ),
    );
  }
}
