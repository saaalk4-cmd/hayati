import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

/// شعار «حياتي» (مصمَّم على Canva — assets/brand/logo_canva.png)
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 88});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.24),
        // حافة ذهبي عشان الشعار الغامق يبان على الخلفية الغامقة
        border: Border.all(
          color: AppColors.gold500.withValues(alpha: 0.55),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.emerald900.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset('assets/brand/brand_mark.png', fit: BoxFit.cover),
    );
  }
}
