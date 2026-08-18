import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';

/// What the dialog returns on Save.
typedef SavePrinterResult = ({String name, int paperSize});

/// Shared "Save Printer" dialog for the USB & Bluetooth add flows.
///
/// Owns its [TextEditingController] as State, so it is disposed on unmount
/// (after the dialog's exit animation completes) — NOT synchronously right after
/// `await showDialog`, which crashed with "TextEditingController used after
/// disposed" when the dialog was dismissed with the back button (the field was
/// still mounted during the exit transition). Pops a [SavePrinterResult] on Save,
/// or null on cancel.
class SavePrinterDialog extends StatefulWidget {
  final String title;
  final IconData icon;
  final String subtitle;
  final String initialName;

  const SavePrinterDialog({
    super.key,
    required this.title,
    required this.icon,
    required this.subtitle,
    required this.initialName,
  });

  @override
  State<SavePrinterDialog> createState() => _SavePrinterDialogState();
}

class _SavePrinterDialogState extends State<SavePrinterDialog> {
  late final TextEditingController _nameController;
  int _paperSize = 80;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      title: widget.title,
      accent: AppColors.primary,
      icon: widget.icon,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.subtitle,
            style: GoogleFonts.poppins(
                fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _nameController,
            label: 'Printer Name',
            hint: 'e.g., Counter Printer',
            icon: Icons.label_outline,
          ),
          const SizedBox(height: 16),
          Text('Paper Size',
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w500)),
          Row(
            children: [
              Radio<int>(
                value: 58,
                groupValue: _paperSize,
                onChanged: (v) => setState(() => _paperSize = v!),
                activeColor: AppColors.primary,
              ),
              Text('58mm', style: GoogleFonts.poppins(fontSize: 13)),
              const SizedBox(width: 16),
              Radio<int>(
                value: 80,
                groupValue: _paperSize,
                onChanged: (v) => setState(() => _paperSize = v!),
                activeColor: AppColors.primary,
              ),
              Text('80mm', style: GoogleFonts.poppins(fontSize: 13)),
            ],
          ),
        ],
      ),
      actions: [
        appDialogCancelButton(context),
        const SizedBox(width: 12),
        appDialogPrimaryButton(
          label: 'Save',
          onPressed: () {
            final name = _nameController.text.trim();
            Navigator.pop(
              context,
              (
                name: name.isEmpty ? widget.initialName : name,
                paperSize: _paperSize,
              ),
            );
          },
        ),
      ],
    );
  }
}
