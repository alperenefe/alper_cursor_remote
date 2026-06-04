import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// Uygulama logosu (launcher ile aynı görsel).
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 72,
    this.showLabel = false,
  });

  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.22),
          child: Image.asset(
            'assets/branding/app_icon.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
        if (showLabel) ...[
          SizedBox(height: size * 0.14),
          Text(
            'Cursor Uzaktan',
            style: TextStyle(
              fontSize: size * 0.22,
              fontWeight: FontWeight.w700,
              color: DesignTokens.slate200,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ],
    );
  }
}
