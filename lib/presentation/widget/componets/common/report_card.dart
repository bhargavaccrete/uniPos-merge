import 'package:flutter/material.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// A plain white report card — the container every non-table section sits in.
/// [ReportTable] and [ReportSummaryCard] carry their own; use this for the rest.
class ReportCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const ReportCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? AppResponsive.cardPadding(context),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// The report loading indicator. Six screens had drifted to a colourless
/// `CircularProgressIndicator()`; this exists so that can't recur.
class ReportLoading extends StatelessWidget {
  const ReportLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
  }
}
