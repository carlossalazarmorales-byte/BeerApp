import 'package:flutter/material.dart';

import '../../tokens/app_colors.dart';
import '../../tokens/app_gradients.dart';

/// The always-emphasized, always-on circular action shown at the center of
/// the bottom navigation bar -- Add Beer since QA Round 1 Block 1 (formerly
/// Scan; the icon is now a caller-supplied parameter rather than the
/// hardcoded scanner icon it used to be).
///
/// Neither of Stitch's two ideas is used literally: `DESIGN.md` specifies a
/// circular `tertiary`-colored FAB that no mockup actually implements, and
/// every implemented mockup instead gives whichever tab is "active" a
/// generic gradient pill — which would make this action look emphasized
/// only when it happens to be selected. This button is deliberately a
/// third, simpler treatment: always raised and gradient-filled regardless
/// of the currently selected tab, satisfying "prominent central action".
class ScanNavButton extends StatelessWidget {
  const ScanNavButton({
    required this.onTap,
    required this.semanticLabel,
    required this.icon,
    super.key,
  });

  final VoidCallback onTap;
  final String semanticLabel;
  final IconData icon;

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
              child: Icon(icon, color: AppColors.onPrimaryGradient, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}
