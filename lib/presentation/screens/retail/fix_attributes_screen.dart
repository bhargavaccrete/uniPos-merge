import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Temporary screen to fix "bad element" attribute errors
/// Navigate here if you're getting "bad state bad element" errors
class FixAttributesScreen extends StatefulWidget {
  const FixAttributesScreen({Key? key}) : super(key: key);

  @override
  State<FixAttributesScreen> createState() => _FixAttributesScreenState();
}

class _FixAttributesScreenState extends State<FixAttributesScreen> {
  bool _isResetting = false;
  String? _message;
  bool _success = false;

  Future<void> _resetAttributes() async {
    setState(() {
      _isResetting = true;
      _message = null;
      _success = false;
    });

    try {
      await HiveInit.resetAttributeBoxes();

      setState(() {
        _success = true;
        _message =
            'Attribute boxes reset successfully!\n\nPlease restart the app completely for changes to take effect.';
      });

      // Show success dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: AppResponsive.smallSpacing(context)),
                Text('Success!'),
              ],
            ),
            content: const Text(
              'Attribute boxes have been reset.\n\n'
              'IMPORTANT: Close and restart the app completely now.\n\n'
              'After restart, you can:\n'
              '1. Import your Excel file again\n'
              '2. Create attributes normally\n'
              '3. Use attributes in Add Product screen',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _success = false;
        _message = 'Error resetting boxes: $e';
      });
    } finally {
      setState(() {
        _isResetting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Fix Attribute Errors'),
        backgroundColor: Colors.orange,
      ),
      body: AppResponsive.constrainedContent(
        context: context,
        alignment: Alignment.topCenter,
        maxWidth: AppResponsive.maxFormWidth(context),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orange),
              SizedBox(height: AppResponsive.extraLargeSpacing(context)),
              Text(
                'Fix "Bad Element" Error',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.getValue(
                    context,
                    mobile: 24.0,
                    tablet: 28.0,
                    desktop: 32.0,
                  ),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: AppResponsive.largeSpacing(context)),
              Text(
                'If you\'re seeing "bad state bad element" errors when creating or viewing attributes, use this tool to reset the attribute database.',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.subheadingFontSize(context),
                ),
              ),
              SizedBox(height: AppResponsive.extraLargeSpacing(context)),
              Container(
                padding: AppResponsive.cardPadding(context),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(
                    AppResponsive.smallBorderRadius(context),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red, size: 20),
                        SizedBox(width: AppResponsive.smallSpacing(context)),
                        Text(
                          'WARNING',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppResponsive.smallSpacing(context)),
                    Text(
                      'This will delete ALL attribute data including:\n'
                      '• All global attributes (Size, Color, etc.)\n'
                      '• All attribute values\n'
                      '• Product-attribute assignments\n\n'
                      'Your products and variants will NOT be deleted,\n'
                      'but you will need to re-import or recreate attributes.',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 32),
              if (_message != null) ...[
                Container(
                  padding: AppResponsive.cardPadding(context),
                  decoration: BoxDecoration(
                    color: _success ? Colors.green.shade50 : Colors.red.shade50,
                    border: Border.all(
                      color: _success
                          ? Colors.green.shade200
                          : Colors.red.shade200,
                    ),
                    borderRadius: BorderRadius.circular(
                      AppResponsive.smallBorderRadius(context),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _success ? Icons.check_circle : Icons.error,
                        color: _success ? Colors.green : Colors.red,
                      ),
                      SizedBox(width: AppResponsive.mediumSpacing(context)),
                      Expanded(
                        child: Text(
                          _message!,
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.bodyFontSize(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppResponsive.largeSpacing(context)),
              ],
              ElevatedButton(
                onPressed: _isResetting ? null : _resetAttributes,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _isResetting
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(width: AppResponsive.largeSpacing(context)),
                          Text('Resetting...'),
                        ],
                      )
                    : Text(
                        'Reset Attribute Boxes',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.subheadingFontSize(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              SizedBox(height: AppResponsive.largeSpacing(context)),
              Text(
                'After resetting:\n'
                '1. Restart the app completely\n'
                '2. Re-import your product Excel file\n'
                '3. Attributes will be recreated automatically',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
