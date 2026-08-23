import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:billberrylite/domain/store/retail/cart_store.dart'
    show kMaxCartLineQuantity;
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/util/color.dart';

/// Whole-number quantity input, capped at four digits.
///
/// The length limit is a typo guard that mirrors [kMaxCartLineQuantity]; stock
/// is the real ceiling and is enforced in the store.
final _cartQtyFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(4),
];

/// How long to wait after the last keystroke before applying.
///
/// Short enough to feel immediate, long enough that typing "125" is one cart
/// write instead of three — each write is a Hive save plus a tab-snapshot save.
const Duration _kApplyDebounce = Duration(milliseconds: 300);

/// Editable quantity for one POS cart line, sized to sit between the − and +
/// buttons.
///
/// **Applies as you type**, debounced by [_kApplyDebounce] — no Done, no tapping
/// away. A cashier typing `12` sees the line total update on its own.
///
/// **Two values are deliberately NOT applied live**, because both destroy the
/// line and both occur on the way to a perfectly ordinary number:
///   * empty — you must clear the field before typing a new value
///   * `0` — a keystroke away from `10`
///
/// Those wait for an explicit confirmation (keyboard Done, on-screen-keypad
/// Done, or leaving the field), where the caller can prompt. So clearing the
/// field can never silently delete the item.
///
/// Built on [AppTextField] so the on-screen [VisualKeyboard] works when the
/// store has it enabled. That mode makes the field `readOnly` — hence both the
/// `onVisualKeyboardDone` hook and the fact that live typing arrives through
/// AppTextField's controller listener rather than the field's own `onChanged`.
class CartQuantityField extends StatefulWidget {
  /// The quantity the STORE currently holds. Treated as the truth: the display
  /// resets to it whenever a value is rejected or abandoned.
  final int qty;

  /// Called with a parsed, non-negative integer. `0` means the user asked for
  /// the line to be removed, and only ever arrives on explicit confirmation.
  ///
  /// Returns whether the value was actually applied, so a rejection (over
  /// stock) can snap the display back to the truth instead of leaving the field
  /// showing a quantity the cart does not have.
  final Future<bool> Function(int) onSubmitted;

  const CartQuantityField({
    super.key,
    required this.qty,
    required this.onSubmitted,
  });

  @override
  State<CartQuantityField> createState() => _CartQuantityFieldState();
}

class _CartQuantityFieldState extends State<CartQuantityField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  Timer? _debounce;

  /// True from the first keystroke until the value settles. Suppresses the
  /// external-change mirror in [didUpdateWidget]: our own live apply changes
  /// `widget.qty`, and re-writing the controller from it would fight the
  /// cashier's typing (and in visual-keyboard mode the field never takes focus,
  /// so `hasFocus` alone is not enough to detect editing).
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    // Created once and owned by this State. The cart list is dynamic, so a
    // controller shared or rebuilt per frame is how "used after being disposed"
    // crashes happen — the caller keys this widget by cart line for the same
    // reason.
    _controller = TextEditingController(text: widget.qty.toString());
    _focusNode = FocusNode()..addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(CartQuantityField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The −/+ buttons and a re-scan change the quantity from outside. Mirror it,
    // unless the user is mid-edit, where overwriting what they are typing would
    // be hostile.
    if (widget.qty != oldWidget.qty && !_focusNode.hasFocus && !_editing) {
      _resetText();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _resetText() {
    final text = widget.qty.toString();
    if (_controller.text != text) _controller.text = text;
  }

  void _onFocusChanged() {
    // Leaving the field settles whatever is in it — including the empty and
    // zero cases that live typing deliberately skips.
    if (!_focusNode.hasFocus) _commit();
  }

  /// Live path: apply while typing.
  ///
  /// Handles ONLY values that are safe to apply without asking — a real
  /// quantity of 1 or more. Empty and `0` fall through to [_commit].
  void _onChanged(String raw) {
    _editing = true;
    _debounce?.cancel();

    final parsed = int.tryParse(raw.trim());
    if (parsed == null || parsed == 0) return; // destructive — wait for commit
    if (parsed == widget.qty) return;

    _debounce = Timer(_kApplyDebounce, () => _apply(parsed));
  }

  /// Settle path: keyboard Done, keypad Done, or focus loss.
  ///
  /// Cancels any pending live apply so a value is never applied twice, then
  /// deals with the two cases live typing skips.
  void _commit() {
    _debounce?.cancel();
    _editing = false;

    final parsed = int.tryParse(_controller.text.trim());

    // Empty or unparseable: the user cleared the field but never named a
    // number. Do NOT touch the cart — this is the case that must not delete
    // the line.
    if (parsed == null || parsed == widget.qty) {
      _resetText();
      return;
    }

    _apply(parsed);
  }

  Future<void> _apply(int qty) async {
    final applied = await widget.onSubmitted(qty);
    if (!mounted) return;

    // Rejected (over stock, or a 0-removal the user cancelled): show the truth
    // rather than leaving a quantity on screen that the cart does not hold.
    if (!applied) {
      _editing = false;
      _resetText();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Tight on purpose: the cart row also carries a name, a price line that
      // may show an override AND a discount, a line total and the actions menu.
      // 52 still fits four digits at the field's 14px font.
      width: 52,
      child: AppTextField(
        controller: _controller,
        focusNode: _focusNode,
        keyboardType: TextInputType.number,
        inputFormatters: _cartQtyFormatters,
        textAlign: TextAlign.center,
        textInputAction: TextInputAction.done,
        // Tight enough to sit inline; the roomy default would not fit between
        // the stepper buttons.
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
        // Live apply. In visual-keyboard mode AppTextField routes this through
        // a controller listener instead of the field, so typing on the on-screen
        // pad updates the cart too.
        onChanged: _onChanged,
        // Unfocusing runs the commit through the focus listener, so there is
        // exactly one settle path for the system keyboard.
        onFieldSubmitted: (_) => _focusNode.unfocus(),
        // The on-screen keypad leaves the field readOnly, so its Done button is
        // the only settle signal available there.
        onVisualKeyboardDone: _commit,
        autovalidateMode: AutovalidateMode.disabled,
      ),
    );
  }
}

/// Compact −/+ button matching the quantity field's height.
class CartQuantityStepperButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const CartQuantityStepperButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 38,
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }
}
