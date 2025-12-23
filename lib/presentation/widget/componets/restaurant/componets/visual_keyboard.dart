import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../constants/restaurant/color.dart';

enum KeyboardType {
  text, // Full QWERTY keyboard
  numeric, // Numbers and decimal only
}

class VisualKeyboard extends StatefulWidget {
  final TextEditingController controller;
  final KeyboardType keyboardType;
  final VoidCallback? onDone;

  const VisualKeyboard({
    Key? key,
    required this.controller,
    this.keyboardType = KeyboardType.text,
    this.onDone,
  }) : super(key: key);

  @override
  State<VisualKeyboard> createState() => _VisualKeyboardState();
}

class _VisualKeyboardState extends State<VisualKeyboard> {
  late KeyboardType _currentMode;
  bool _isShiftEnabled = false;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.keyboardType;
  }

  void _toggleMode() {
    setState(() {
      _currentMode = _currentMode == KeyboardType.text
          ? KeyboardType.numeric
          : KeyboardType.text;
    });
  }

  void _toggleShift() {
    setState(() {
      _isShiftEnabled = !_isShiftEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Keyboard content
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _currentMode == KeyboardType.numeric
                ? _buildNumericKeyboard()
                : _buildTextKeyboard(),
          ),
        ],
      ),
    );
  }

  Widget _buildNumericKeyboard() {
    return Column(
      children: [
        Row(
          children: [
            _buildKey('1'),
            _buildKey('2'),
            _buildKey('3'),
          ],
        ),
        SizedBox(height: 8),
        Row(
          children: [
            _buildKey('4'),
            _buildKey('5'),
            _buildKey('6'),
          ],
        ),
        SizedBox(height: 8),
        Row(
          children: [
            _buildKey('7'),
            _buildKey('8'),
            _buildKey('9'),
          ],
        ),
        SizedBox(height: 8),
        Row(
          children: [
            _buildKey('.'),
            _buildKey('0'),
            _buildKey('⌫', isBackspace: true),
          ],
        ),
        SizedBox(height: 8),
        Row(
          children: [
            _buildActionKey('ABC', onPressed: _toggleMode),
            SizedBox(width: 8),
            _buildActionKey('Clear', onPressed: () {
              widget.controller.clear();
              widget.controller.selection = TextSelection.fromPosition(
                TextPosition(offset: 0),
              );
            }),
            SizedBox(width: 8),
            _buildActionKey('Done', onPressed: widget.onDone ?? () {}),
          ],
        ),
      ],
    );
  }

  Widget _buildTextKeyboard() {
    final row1 = ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'];
    final row2 = ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'];
    final row3 = ['z', 'x', 'c', 'v', 'b', 'n', 'm'];

    return Column(
      children: [
        // Row 1
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row1.map((key) => _buildKey(
            _isShiftEnabled ? key.toUpperCase() : key,
            flex: 1,
          )).toList(),
        ),
        SizedBox(height: 8),

        // Row 2
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row2.map((key) => _buildKey(
            _isShiftEnabled ? key.toUpperCase() : key,
            flex: 1,
          )).toList(),
        ),
        SizedBox(height: 8),

        // Row 3
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildShiftKey(),
            ...row3.map((key) => _buildKey(
              _isShiftEnabled ? key.toUpperCase() : key,
              flex: 1,
            )).toList(),
            _buildKey('⌫', isBackspace: true, flex: 2),
          ],
        ),
        SizedBox(height: 8),

        // Row 4 - Space and special characters
        Row(
          children: [
            _buildKey('123', isSpecial: true, flex: 2, onTap: _toggleMode),
            SizedBox(width: 4),
            _buildKey('Space', flex: 5, displayText: ' '),
            SizedBox(width: 4),
            _buildActionKey('Done', onPressed: widget.onDone ?? () {}, flex: 2),
          ],
        ),
      ],
    );
  }

  Widget _buildShiftKey() {
    return Expanded(
      flex: 2,
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: Material(
          color: _isShiftEnabled ? primarycolor : Colors.grey[400],
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            onTap: _toggleShift,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 45,
              alignment: Alignment.center,
              child: Text(
                '⇧',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _isShiftEnabled ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKey(
    String key, {
    bool isBackspace = false,
    bool isSpecial = false,
    int flex = 1,
    String? displayText,
    VoidCallback? onTap,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: Material(
          color: isSpecial ? Colors.grey[400] : Colors.white,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            onTap: onTap ?? () => _handleKeyPress(key, isBackspace: isBackspace),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 45,
              alignment: Alignment.center,
              child: Text(
                displayText ?? key,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionKey(
    String label, {
    required VoidCallback onPressed,
    int flex = 1,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: Material(
          color: primarycolor,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 45,
              alignment: Alignment.center,
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleKeyPress(String key, {bool isBackspace = false}) {
    if (isBackspace) {
      if (widget.controller.text.isNotEmpty) {
        final currentText = widget.controller.text;
        final selection = widget.controller.selection;

        if (selection.start > 0) {
          final newText = currentText.replaceRange(
            selection.start - 1,
            selection.end,
            '',
          );
          widget.controller.text = newText;
          widget.controller.selection = TextSelection.fromPosition(
            TextPosition(offset: selection.start - 1),
          );
        }
      }
      return;
    }

    if (key == 'Space') {
      key = ' ';
    } else if (key == '⇧' || key == '123' || key == 'ABC') {
      // These are handled by onTap callbacks
      return;
    }

    // Auto-disable shift after one key press (letters are already uppercase/lowercase from _buildTextKeyboard)
    if (_isShiftEnabled && _currentMode == KeyboardType.text) {
      setState(() {
        _isShiftEnabled = false;
      });
    }

    // Insert text at cursor position
    final currentText = widget.controller.text;
    final selection = widget.controller.selection;
    final newText = currentText.replaceRange(
      selection.start,
      selection.end,
      key,
    );

    widget.controller.text = newText;
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: selection.start + key.length),
    );
  }
}

/// Helper widget to show visual keyboard in a bottom sheet
class VisualKeyboardHelper {
  static void show({
    required BuildContext context,
    required TextEditingController controller,
    KeyboardType keyboardType = KeyboardType.text,
    VoidCallback? onDone,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VisualKeyboard(
        controller: controller,
        keyboardType: keyboardType,
        onDone: () {
          Navigator.pop(context);
          onDone?.call();
        },
      ),
    );
  }
}