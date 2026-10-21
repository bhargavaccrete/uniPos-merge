import 'package:flutter/material.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Scrolling report body: standard padding, width-capped on large screens.
/// Wrap the whole content column in this — never the individual sections.
class ReportBody extends StatelessWidget {
  final Widget child;

  const ReportBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AppResponsive.padding(context),
      child: AppResponsive.constrainedContent(context: context, child: child),
    );
  }
}
