import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

import '../../../../../data/models/restaurant/db/ordermodel_309.dart';
import '../../../../../util/common/app_responsive.dart';
import '../../../../../util/color.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';

/// Whether opening [showOrderItemsDialog] would actually tell the user
/// anything.
///
/// A single-item order is already fully visible on the card, so popping a
/// dialog to repeat it is pure noise — callers that open the dialog as a
/// fallback (e.g. tapping a paid order) should check this first. The "+N more"
/// chip doesn't need it: it only exists when something IS hidden.
bool orderHasMoreToShow(OrderModel order) => order.items.length > 1;

/// Read-only list of every item on [order].
///
/// Opened from the "+N more" chip when the desktop card truncates its item
/// summary, and from tapping a fully-paid active order — which previously did
/// nothing at all, since the card's own tap is gated on `!order.isFullyPaid`.
Future<void> showOrderItemsDialog(BuildContext context, OrderModel order) {
  final count = order.items.length;
  return showDialog(
    context: context,
    // Nearest navigator, so on desktop this opens inside the content pane
    // rather than covering the sidebar.
    useRootNavigator: false,
    builder: (ctx) => AppDialogShell(
      title: order.orderNumber != null
          ? 'Order #${order.orderNumber}'
          : 'Order items',
      subtitle: '$count item${count == 1 ? '' : 's'}',
      accent: AppColors.primary,
      icon: Icons.receipt_long_rounded,
      body: ConstrainedBox(
        // Long orders scroll instead of pushing the dialog off-screen.
        constraints: BoxConstraints(
          maxHeight: AppResponsive.screenHeight(context) * 0.45,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: order.items.map((item) {
              final extras = <String>[
                if (item.variantName != null && item.variantName!.isNotEmpty)
                  'Size: ${item.variantName}',
                if (item.choiceNames != null && item.choiceNames!.isNotEmpty)
                  item.choiceNames!.join(', '),
              ];
              return Padding(
                padding: EdgeInsets.symmetric(
                  vertical: AppResponsive.smallSpacing(context) / 2,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${item.quantity}X',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.bodyFontSize(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.bodyFontSize(context),
                            ),
                          ),
                          for (final line in extras)
                            Text(
                              line,
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.smallFontSize(context),
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
      actions: [
        appDialogPrimaryButton(
          label: 'Close',
          onPressed: () => Navigator.pop(ctx),
        ),
      ],
    ),
  );
}

class OrderCard extends StatelessWidget {
  final OrderModel order;
  final Function(String) onDelete;
  final VoidCallback? ontap;
  final VoidCallback? ontapcooking;
  final VoidCallback? onPrintKot;
  final VoidCallback? onPrintBill;
  final Color? color;
  const OrderCard({
    super.key,
    required this.order,
    required this.onDelete,
    this.ontap,
    this.ontapcooking,
    this.onPrintKot,
    this.onPrintBill,
    this.color,
  });

  /// Separator between item names on the summary line.
  static const String _itemSep = '   ·   ';

  /// Single-line item summary shown on desktop, e.g.
  /// `2X Tandoori Chicken · 1X Fresh Lime Soda        +2 more`.
  ///
  /// How many names appear is decided by MEASUREMENT, not a fixed count: the
  /// line packs in as many whole names as actually fit at this card's width,
  /// so a wide card doesn't sit half empty while items are hidden behind the
  /// chip. Only whole names are shown — a half-rendered name would be worse
  /// than counting it as hidden, and would make the "+N" wrong.
  ///
  /// Variants, choices and extras are omitted here on purpose — they're what
  /// made the card tall — and stay visible in the items dialog behind the
  /// "+N more" chip.
  Widget _compactItems(BuildContext context) {
    final labels = order.items.map((i) => '${i.quantity}X ${i.title}').toList();

    final textStyle = GoogleFonts.poppins(
      fontSize: AppResponsive.bodyFontSize(context),
    );
    final chipStyle = GoogleFonts.poppins(
      fontSize: AppResponsive.smallFontSize(context),
      fontWeight: FontWeight.w600,
      color: AppColors.primary,
    );

    // The items block is the ONLY variable-height part of the card — header,
    // guest row, table row and button are all fixed — so pinning this to ONE
    // row of constant height makes every card in the 2-column grid end at the
    // same point, with no reserved blank space on short orders.
    final rowHeight = AppResponsive.bodyFontSize(context) * 1.5;
    final direction = Directionality.of(context);

    double widthOf(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: 1,
        textDirection: direction,
      )..layout();
      return painter.width;
    }

    return SizedBox(
      height: rowHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final full = labels.join(_itemSep);

          // Everything fits — no chip, no truncation.
          if (widthOf(full, textStyle) <= constraints.maxWidth) {
            return Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(full, maxLines: 1, style: textStyle),
            );
          }

          // Reserve the chip using the WORST-CASE count, so the line doesn't
          // reflow as the number changes, then fit as many whole names as the
          // remaining width allows.
          final chipWidth =
              widthOf('+${labels.length} more', chipStyle) +
              AppResponsive.smallSpacing(context);
          final available = constraints.maxWidth - chipWidth;

          var shown = 1;
          for (var i = labels.length; i >= 1; i--) {
            if (widthOf(labels.take(i).join(_itemSep), textStyle) <=
                available) {
              shown = i;
              break;
            }
          }
          final hidden = labels.length - shown;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  labels.take(shown).join(_itemSep),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle,
                ),
              ),
              InkWell(
                onTap: () => showOrderItemsDialog(context, order),
                borderRadius: BorderRadius.circular(
                  AppResponsive.smallBorderRadius(context),
                ),
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: AppResponsive.smallSpacing(context),
                  ),
                  child: Text('+$hidden more', style: chipStyle),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Helper function to create an icon+text pair
    Widget buildHeaderItem(IconData icon, String title) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: AppResponsive.iconSize(context),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: AppResponsive.smallFontSize(context),
            ),
          ),
        ],
      );
    }

    // Determine the icon for the order type
    IconData orderTypeIcon() {
      switch (order.orderType) {
        case "Dine In":
          return Icons.restaurant_menu;
        case "Delivery":
          return Icons.delivery_dining;
        default:
          return Icons.takeout_dining; // Take Away
      }
    }

    return InkWell(
      onTap: ontap,
      child: Card(
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.08),
        margin: EdgeInsets.symmetric(
          vertical: AppResponsive.smallSpacing(context),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            AppResponsive.borderRadius(context),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // 1. Header Row
            Container(
              padding: EdgeInsets.symmetric(
                vertical: AppResponsive.smallSpacing(context),
              ),
              color: color,
              // Color(0xffc52b33),
              child: Row(
                children: [
                  // Order Type
                  Expanded(
                    child: buildHeaderItem(orderTypeIcon(), order.orderType),
                  ),

                  // Order Number (if available)
                  if (order.orderNumber != null)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '#${order.orderNumber}',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: AppResponsive.getValue(
                                context,
                                mobile: 24.0,
                                tablet: 26.0,
                                desktop: 28.0,
                              ),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Order No.',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: AppResponsive.getValue(
                                context,
                                mobile: 10.0,
                                tablet: 11.0,
                                desktop: 12.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // KOT Numbers
                  Expanded(
                    child: Column(
                      children: [
                        // Display all KOT numbers
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 4,
                          runSpacing: 4,
                          children: order.getKotNumbers().map((kotNum) {
                            return Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '$kotNum',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: AppResponsive.getValue(
                                    context,
                                    mobile: 10.0,
                                    tablet: 12.0,
                                    desktop: 13.0,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'KOT',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: AppResponsive.getValue(
                              context,
                              mobile: 10.0,
                              tablet: 11.0,
                              desktop: 12.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Time
                  Expanded(
                    child: Center(
                      child: Text(
                        DateFormat.jm().format(order.timeStamp),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: AppResponsive.smallFontSize(context),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Customer & Status Row
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppResponsive.mediumSpacing(context),
                vertical: AppResponsive.smallSpacing(context),
              ),
              color: Colors.grey.shade100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.customerName.isEmpty ? 'Guest' : order.customerName,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      Text(
                        order.paymentStatus ?? 'unPaid',
                        style: GoogleFonts.poppins(
                          color: order.isFullyPaid
                              ? AppColors.success
                              : (order.hasPartialPayment
                                    ? Colors.orange.shade700
                                    : AppColors.danger),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: AppResponsive.smallSpacing(context)),

                      InkWell(
                        onTap: () => onDelete(order.id),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.danger,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.delete,
                            color: Colors.white,
                            size: AppResponsive.smallIconSize(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 3. Table label + PAID badge + KOT/Bill print buttons
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppResponsive.mediumSpacing(context),
                vertical: AppResponsive.smallSpacing(context),
              ),
              color: Colors.white,
              child: Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    color: AppColors.secondary,
                    size: AppResponsive.iconSize(context),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    (order.tableNo != null && order.tableNo!.isNotEmpty)
                        ? 'Table ${order.tableNo}'
                        : order.orderType,
                    style: GoogleFonts.poppins(),
                  ),
                  // PAID / PARTIAL badge when payment recorded but order still active
                  if (order.isFullyPaid || order.hasPartialPayment) ...[
                    SizedBox(width: AppResponsive.smallSpacing(context)),
                    Builder(
                      builder: (_) {
                        final bool paid = order.isFullyPaid;
                        final Color c = paid
                            ? AppColors.success
                            : Colors.orange.shade700;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: c.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: c.withOpacity(0.4)),
                          ),
                          child: Text(
                            paid ? 'PAID' : 'PARTIAL',
                            style: GoogleFonts.poppins(
                              color: c,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  const Spacer(),
                  // Print Bill button
                  if (onPrintBill != null)
                    InkWell(
                      onTap: onPrintBill,
                      borderRadius: BorderRadius.circular(
                        AppResponsive.smallBorderRadius(context),
                      ),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppResponsive.smallSpacing(context),
                          vertical: 6,
                        ),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: AppColors.info,
                          borderRadius: BorderRadius.circular(
                            AppResponsive.smallBorderRadius(context),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.receipt,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Bill',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: AppResponsive.smallFontSize(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // KOT print button
                  InkWell(
                    onTap: onPrintKot,
                    borderRadius: BorderRadius.circular(
                      AppResponsive.smallBorderRadius(context),
                    ),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppResponsive.smallSpacing(context),
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(
                          AppResponsive.smallBorderRadius(context),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.print,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'KOT',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: AppResponsive.smallFontSize(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 4. Items Header Row
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppResponsive.mediumSpacing(context),
                vertical: AppResponsive.smallSpacing(context),
              ),
              color: Colors.grey.shade100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'QTY   Items',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  // Removed redundant POS ID string
                ],
              ),
            ),

            // 5. Items List and Final Button
            Container(
              padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
              color: Colors.white,
              child: Column(
                children: [
                  // Desktop lays two cards per row, where a full per-item list
                  // makes a 4-item order tower over a 1-item one and the row
                  // ends up ragged. Collapse to a two-line summary there —
                  // tapping the card still opens the complete order.
                  if (AppResponsive.isDesktop(context))
                    _compactItems(context)
                  else
                    ...order.items
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                Text(
                                  '${item.quantity}X',
                                  style: GoogleFonts.poppins(
                                    fontSize: AppResponsive.bodyFontSize(
                                      context,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: AppResponsive.largeSpacing(context),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: GoogleFonts.poppins(
                                          fontSize: AppResponsive.bodyFontSize(
                                            context,
                                          ),
                                        ),
                                      ),
                                      if (item.variantName != null &&
                                          item.variantName!.isNotEmpty)
                                        Text(
                                          'Size: ${item.variantName}',
                                          style: GoogleFonts.poppins(
                                            fontSize:
                                                AppResponsive.smallFontSize(
                                                  context,
                                                ),
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      if (item.choiceNames != null &&
                                          item.choiceNames!.isNotEmpty)
                                        Text(
                                          'Choices: ${item.choiceNames!.join(', ')}',
                                          style: GoogleFonts.poppins(
                                            fontSize:
                                                AppResponsive.smallFontSize(
                                                  context,
                                                ),
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      if (item.extras != null &&
                                          item.extras!.isNotEmpty)
                                        Builder(
                                          builder: (context) {
                                            // Group extras by name and count quantities
                                            Map<String, Map<String, dynamic>>
                                            groupedExtras = {};

                                            for (var extra in item.extras!) {
                                              final displayName =
                                                  extra['displayName'] ??
                                                  extra['name'] ??
                                                  'Unknown';
                                              final price =
                                                  extra['price']?.toDouble() ??
                                                  0.0;
                                              final quantity =
                                                  extra['quantity']?.toInt() ??
                                                  1;

                                              String key =
                                                  '$displayName-${price.toStringAsFixed(2)}';

                                              if (groupedExtras.containsKey(
                                                key,
                                              )) {
                                                groupedExtras[key]!['quantity'] =
                                                    (groupedExtras[key]!['quantity']
                                                        as int) +
                                                    quantity;
                                              } else {
                                                groupedExtras[key] = {
                                                  'displayName': displayName,
                                                  'price': price,
                                                  'quantity': quantity,
                                                };
                                              }
                                            }

                                            // Build display string
                                            final extrasDisplay = groupedExtras
                                                .entries
                                                .map((entry) {
                                                  final data = entry.value;
                                                  final int qty =
                                                      data['quantity'] as int;
                                                  final String name =
                                                      data['displayName']
                                                          as String;
                                                  final double price =
                                                      data['price'] as double;

                                                  if (qty > 1) {
                                                    return '${qty}x $name(${CurrencyHelper.currentSymbol}${price.toStringAsFixed(2)})';
                                                  } else {
                                                    return '$name(${CurrencyHelper.currentSymbol}${price.toStringAsFixed(2)})';
                                                  }
                                                })
                                                .join(', ');

                                            return Text(
                                              'Extras: $extrasDisplay',
                                              style: GoogleFonts.poppins(
                                                fontSize:
                                                    AppResponsive.smallFontSize(
                                                      context,
                                                    ),
                                                color: AppColors.orange,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  SizedBox(height: AppResponsive.mediumSpacing(context)),
                  ElevatedButton(
                    onPressed: ontapcooking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      // buttonHeight starts at 48, which would jump mobile
                      // 40 → 48 inside an already-dense card; raw ladder keeps
                      // mobile and tablet exact.
                      minimumSize: Size(
                        double.infinity,
                        AppResponsive.getValue(
                          context,
                          mobile: 40.0,
                          tablet: 46.0,
                          desktop: 52.0,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      order.status,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: AppResponsive.bodyFontSize(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//
//
// Card(
// elevation: 2,
// child: Container(
// decoration: BoxDecoration(
// // borderRadius: BorderRadius.only(topLeft: Radius.circular(15),topRight: Radius.circular(15)),
// borderRadius: BorderRadius.circular(15),
// color: Colors.green,
//
// ),
// // width: width * 0.8,
// // height: height * 0.4,
// child: Column(
// children: [
// Container(
// decoration: BoxDecoration(
// borderRadius: BorderRadius.only(topLeft: Radius.circular(15),topRight: Radius.circular(15)),
//
// color: Colors.red,
//
// ),
// child: Row(
// mainAxisAlignment: MainAxisAlignment.spaceBetween,
// children: [
// Container(
//
// padding: EdgeInsets.symmetric(horizontal: 5,vertical: 5),
// alignment: Alignment.center,
// child: Column(
// children: [
// Icon(Icons.delivery_dining_outlined,color: Colors.white,),
// Text('Home Delivery',style: GoogleFonts.poppins(color: Colors.white,fontSize: 12),)
// ],
// ),
// ),
// SizedBox(
// width: 5,
// ),
// Container(
// child: Column(
// children: [
// Text('AU-8',style: GoogleFonts.poppins(color: Colors.white,fontSize: 12)),
// Text('KOT NO.',style: GoogleFonts.poppins(color: Colors.white,fontSize: 12)),
// ],
// ),
// ),
// SizedBox(
// width: 5,
// ),
// Container(
// child: Column(
// children: [
// Text('11:30 AM',style: GoogleFonts.poppins(color: Colors.white,fontSize: 12))
// ],
// ),
// ),
// SizedBox(
// width: 5,
// ),
// ],
// ),
// ),
//
// // Test
// Container(
// padding: EdgeInsets.symmetric(horizontal: 10,vertical: 5),
// color: Colors.blue.shade50,
// child: Row(
// mainAxisAlignment: MainAxisAlignment.spaceBetween,
// children: [
//
// Text('test',style: GoogleFonts.poppins(fontSize: 12)),
// Row(
// children: [
// Text('UNPAID',style: GoogleFonts.poppins(color: Colors.red,fontWeight: FontWeight.w600,fontSize: 12)),
// SizedBox(width: 10,),
// Container(
// // padding: EdgeInsets.all(5),
// // width: width * 0.2,
// // height: height * 0.05,
// decoration: BoxDecoration(
// borderRadius: BorderRadius.circular(2),
// color: Colors.red,
// shape: BoxShape.rectangle
//
// ),
// child: Icon(Icons.delete,color: Colors.white,size: 20,)
// )
// ],
// )
//
// ],
// ),
// ),
// Container(
// padding: EdgeInsets.symmetric(horizontal: 5,vertical: 5),
// color: Colors.white,
// child: Row(
// mainAxisAlignment: MainAxisAlignment.spaceBetween,
// children: [
//
// Row(
// children: [
// Icon(Icons.person_outline_outlined,color: AppColors.primary,),
// Text('#Admin',style: GoogleFonts.poppins(fontSize: 12)),
// ],
// ),
// Container(
// padding: EdgeInsets.all(5),
// decoration: BoxDecoration(
// color: AppColors.primary,
// borderRadius: BorderRadius.circular(
// 5
// )
// ),
// child: Row(
// children: [
// Icon(Icons.print,size: 15,color: Colors.white,),
// SizedBox(width: 5,),
// Text('Kot',style: GoogleFonts.poppins(fontSize: 12,color: Colors.white),),
//
// ],
// ),
// )
//
// ],
// ),
// ),
// Container(
// padding: EdgeInsets.symmetric(horizontal: 5),
// color: Colors.blue.shade50,
// child: Row(
// mainAxisAlignment: MainAxisAlignment.spaceBetween,
// children: [
//
// Row(
// children: [
// Text('QTY',style: GoogleFonts.poppins(fontSize: 12)),
// SizedBox(width: 10,),
// Text('Items',style: GoogleFonts.poppins(fontSize: 12)),
// ],
// ),
// Text('#POS01-006',style: GoogleFonts.poppins(fontSize: 10))
//
// ],
// ),
// ),
// // cooking
// Container(
// decoration: BoxDecoration(
// borderRadius: BorderRadius.only(bottomLeft: Radius.circular(15),bottomRight: Radius.circular(15)),
// color: Colors.white,
// ),
// padding: EdgeInsets.symmetric(horizontal: 5,vertical: 5),
//
// child: Column(
// children: [
// Row(
// mainAxisAlignment: MainAxisAlignment.spaceBetween,
// children: [
//
// Text('1X'),
// Text('Almonds Carnival Ice Cream',style: GoogleFonts.poppins(fontSize: 12),),
// Container(
// // padding: EdgeInsets.all(5),
// // width: width * 0.2,
// // height: height * 0.05,
// decoration: BoxDecoration(
// borderRadius: BorderRadius.circular(2),
// color: Colors.red,
// shape: BoxShape.rectangle
//
// ),
// child: Icon(Icons.delete,color: Colors.white,size: 20,)
// )
//
// ],
// ),
// SizedBox(height: 10,),
// CommonButton(
// bordercolor: Colors.red,
// bordercircular: 5,
// bgcolor: Colors.red,
// width: width * 0.7,
// height: height *0.04,
// onTap: (){}, child: Text('Cooking',style: GoogleFonts.poppins(color: Colors.white),))
// ],
// ),
// )
//
// ],
// ),
// ),
// ),
