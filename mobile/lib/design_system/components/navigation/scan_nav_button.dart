import 'package:flutter/material.dart';

import '../../tokens/app_colors.dart';
import '../../tokens/app_gradients.dart';

/// The always-emphasized, always-on circular Scan action shown at the
/// center of the bottom navigation bar.
///
/// Neither of Stitch's two ideas is used literally: `DESIGN.md` specifies a
/// circular `tertiary`-colored FAB that no mockup actually implements, and
/// every implemented mockup instead gives whichever tab is "active" a
/// generic gradient pill — which would make Scan look emphasized only when
/// it happens to be selected. This button is deliberately a third,
/// simpler treatment: always raised and gradient-filled regardless of the
/// currently selected tab, satisfying "prominent central Scan action".
class ScanNavButton extends StatelessWidget {
  const ScanNavButton({
    required this.onTap,
    required this.semanticLabel,
    super.key,
  });

  final VoidCallback onTap;
  final String semanticLabel;

  static const double _diameter = 60;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -12),
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: Material(
          shape: const CircleBorder(),
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: _diameter,
              height: _diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppGradients.primary,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.qr_code_scanner,
                color: AppColors.onPrimaryGradient,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
