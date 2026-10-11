import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keeps bill changes in sync only until the cashier edits the amount.
/// The page/sheet owns and disposes this controller, just like a normal one.
class PaymentAmountController extends TextEditingController {
  PaymentAmountController({required int defaultAmount, String? initialText})
      : _automatic = initialText == null,
        super(text: initialText ?? defaultAmount.toString());

  bool _automatic;
  bool get isAutomatic => _automatic;

  void updateDefaultAmount(int amount) {
    if (_automatic && text != amount.toString()) _fill(amount);
  }

  void resetToDefault(int amount) {
    _automatic = true;
    _fill(amount);
  }

  void markEdited() => _automatic = false;

  void selectAutomaticAmount() {
    if (_automatic) {
      selection = TextSelection(baseOffset: 0, extentOffset: text.length);
    }
  }

  void _fill(int amount) {
    final text = amount.toString();
    value = TextEditingValue(
        text: text,
        selection: TextSelection(baseOffset: 0, extentOffset: text.length));
  }
}

/// A first tap selects the automatic bill; typing replaces it instead of
/// appending digits. After a manual edit, ordinary cursor editing is preserved.
class PaymentAmountField extends StatefulWidget {
  const PaymentAmountField({
    required this.controller,
    required this.validator,
    this.onChanged,
    this.readOnly = false,
    this.helperText,
    super.key,
  });

  final PaymentAmountController controller;
  final FormFieldValidator<String> validator;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final String? helperText;

  @override
  State<PaymentAmountField> createState() => _PaymentAmountFieldState();
}

class _PaymentAmountFieldState extends State<PaymentAmountField> {
  @override
  Widget build(BuildContext context) => TextFormField(
        controller: widget.controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        selectAllOnFocus: widget.controller.isAutomatic,
        onTap: widget.controller.selectAutomaticAmount,
        readOnly: widget.readOnly,
        decoration: InputDecoration(
            labelText: 'Pembayaran masuk (Rp)',
            helperText: widget.helperText,
            helperMaxLines: 3),
        validator: widget.validator,
        onChanged: (value) {
          setState(widget.controller.markEdited);
          widget.onChanged?.call(value);
        },
      );
}
