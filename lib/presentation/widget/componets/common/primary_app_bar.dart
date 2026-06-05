import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';

/// App-wide AppBar. Every screen uses this so the top bar is identical:
/// flat [AppColors.primary] background, white title/icons, light status-bar
/// icons, no elevation, no gradient.
///
/// Pass [title] for the common case, or [titleWidget] for a custom title
/// (e.g. a title + subtitle column). Action icons inherit white automatically
/// via [iconTheme]/[actionsIconTheme] — don't set explicit dark colors on them.
AppBar buildPrimaryAppBar({
  String? title,
  Widget? titleWidget,
  List<Widget>? actions,
  Widget? leading,
  PreferredSizeWidget? bottom,
  bool centerTitle = false,
  double titleFontSize = 20,
  bool automaticallyImplyLeading = true,
}) {
  return AppBar(
    backgroundColor: AppColors.primary,
    surfaceTintColor: AppColors.primary,
    elevation: 0,
    systemOverlayStyle: SystemUiOverlayStyle.light,
    iconTheme: const IconThemeData(color: Colors.white),
    actionsIconTheme: const IconThemeData(color: Colors.white),
    centerTitle: centerTitle,
    automaticallyImplyLeading: automaticallyImplyLeading,
    leading: leading,
    title: titleWidget ??
        (title == null
            ? null
            : Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: titleFontSize,
                ),
              )),
    actions: actions,
    bottom: bottom,
  );
}
