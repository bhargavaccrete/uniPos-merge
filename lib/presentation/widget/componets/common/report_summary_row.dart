import 'package:flutter/material.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// A row of equal-width, equal-height [ReportSummaryCard]s.
///
/// Fixed columns are safe at any width because the card scales its own value
/// text down (`FittedBox`) rather than overflowing. [IntrinsicHeight] bounds the
/// row so a card with a subtitle doesn't sit taller than its neighbour.
class ReportSummaryRow extends StatelessWidget {
  final List<Widget> cards;

  const ReportSummaryRow({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final card in cards) {
      if (children.isNotEmpty) children.add(AppResponsive.horizontalSpace(context));
      children.add(Expanded(child: card));
    }
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}
