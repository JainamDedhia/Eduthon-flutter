import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class GyaanSetuLogo extends StatelessWidget {
  final double size;
  final bool showWordmark;

  const GyaanSetuLogo({
    super.key,
    this.size = 96,
    this.showWordmark = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: size,
          width: size,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                blurRadius: 16,
                color: Colors.black.withOpacity(0.08),
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: EdgeInsets.all(size * 0.18),
          child: SvgPicture.asset(
            'assets/images/gyaansetu_logo.svg',
            semanticsLabel: 'GyaanSetu logo',
          ),
        ),
        if (showWordmark) ...[
          const SizedBox(height: 14),
          const Text(
            'GyaanSetu',
            style: AppTextStyles.display,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'Offline-first learning bridge',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

