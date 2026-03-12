import 'package:flutter/material.dart';
import 'package:unipos/util/color.dart';

class CommonButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget? child;
  final Color? bgcolor;
  final Color? bordercolor;
  final double? width;
  final double? borderwidth;
  final double? height;
  final double? bordercircular;

  /// When true, shows a [CircularProgressIndicator] and disables tap.
  final bool isLoading;

  const CommonButton({
    super.key,
    required this.onTap,
    required this.child,
    this.bgcolor,
    this.width = double.infinity,
    this.height = 50,
    this.bordercolor,
    this.bordercircular,
    this.borderwidth,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = bordercircular ?? 12;
    final isDisabled = onTap == null || isLoading;

    final effectiveColor = isDisabled
        ? (bgcolor ?? AppColors.primary).withValues(alpha: 0.5)
        : (bgcolor ?? AppColors.primary);

    final effectiveBorderColor = isDisabled
        ? (bordercolor ?? effectiveColor).withValues(alpha: 0.5)
        : (bordercolor ?? effectiveColor);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: effectiveColor,
        border: Border.all(
          color: effectiveBorderColor,
          width: borderwidth ?? 1.5,
        ),
        borderRadius: BorderRadius.circular(effectiveRadius),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(effectiveRadius),
        child: InkWell(
          onTap: isDisabled ? null : onTap,
          borderRadius: BorderRadius.circular(effectiveRadius),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        (bgcolor == Colors.white || bgcolor == AppColors.white)
                            ? AppColors.primary
                            : Colors.white,
                      ),
                    ),
                  )
                : child,
          ),
        ),
      ),
    );
  }
}
