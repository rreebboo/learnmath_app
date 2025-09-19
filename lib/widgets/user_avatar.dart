import 'package:flutter/material.dart';
import '../services/image_service.dart';

class UserAvatar extends StatelessWidget {
  final String avatar;
  final double size;
  final Color? backgroundColor;
  final List<Color>? gradientColors;
  final bool showBorder;
  final Color? borderColor;
  final double? borderWidth;

  const UserAvatar({
    super.key,
    required this.avatar,
    this.size = 40,
    this.backgroundColor,
    this.gradientColors,
    this.showBorder = false,
    this.borderColor,
    this.borderWidth,
  });

  @override
  Widget build(BuildContext context) {
    final ImageService imageService = ImageService();
    final isImageUrl = imageService.isImageUrl(avatar);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isImageUrl
            ? null
            : (gradientColors != null
                ? LinearGradient(colors: gradientColors!)
                : const LinearGradient(
                    colors: [Color(0xFF7ED321), Color(0xFF9ACD32)],
                  )),
        color: isImageUrl
            ? (backgroundColor ?? Colors.white)
            : null,
        border: showBorder
            ? Border.all(
                color: borderColor ?? const Color(0xFF7ED321),
                width: borderWidth ?? 2,
              )
            : null,
        boxShadow: showBorder
            ? null
            : [
                BoxShadow(
                  color: (borderColor ?? const Color(0xFF7ED321)).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: ClipOval(
        child: isImageUrl
            ? Container(
                width: size,
                height: size,
                color: backgroundColor ?? Colors.white,
                child: Image.network(
                  avatar,
                  fit: BoxFit.cover,
                  width: size,
                  height: size,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: gradientColors != null
                            ? LinearGradient(colors: gradientColors!)
                            : const LinearGradient(
                                colors: [Color(0xFF7ED321), Color(0xFF9ACD32)],
                              ),
                      ),
                      child: Center(
                        child: SizedBox(
                          width: size * 0.3,
                          height: size * 0.3,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: gradientColors != null
                            ? LinearGradient(colors: gradientColors!)
                            : const LinearGradient(
                                colors: [Color(0xFF7ED321), Color(0xFF9ACD32)],
                              ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.person,
                          size: size * 0.5,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              )
            : Center(
                child: Text(
                  avatar,
                  style: TextStyle(fontSize: size * 0.5),
                ),
              ),
      ),
    );
  }
}