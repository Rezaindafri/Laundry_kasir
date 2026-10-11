import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/transaction_entity.dart';

class PaymentEntry {
  const PaymentEntry(
      {required this.amount,
      required this.method,
      required this.requestId,
      this.note});
  final int amount;
  final PaymentMethod method;
  final String requestId;
  final String? note;
}

/// The sheet owns its controllers through the route's closing animation.
/// Failed requests can reuse the SAME request ID, preventing double payments.
class PaymentEntrySheet extends StatefulWidget {
  const PaymentEntrySheet(
      {required this.minimum,
      required this.maximum,
      required this.method,
      this.previous,
      this.forCollection = false,
      super.key});
  final int minimum;
  final int maximum;
  final PaymentMethod method;
  final PaymentEntry? previous;
  final bool forCollection;

  @override
  State<PaymentEntrySheet> createState() => _PaymentEntrySheetState();
}

class _PaymentEntrySheetState extends State<PaymentEntrySheet> {
  static final _currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late PaymentMethod _method;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
        text: widget.previous?.amount.toString() ??
            (widget.forCollection ? widget.minimum.toString() : ''));
    _note = TextEditingController(text: widget.previous?.note);
    _method = widget.previous?.method ?? widget.method;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
          child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
        child: Form(
            key: _formKey,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                      widget.forCollection
                          ? 'Bayar & ambil layanan terpilih'
                          : 'Bayar Saja',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Text(widget.forCollection
                      ? 'DP yang sudah masuk diperhitungkan. Pembayaran minimum ${_currency.format(widget.minimum)}; sisa seluruh tagihan ${_currency.format(widget.maximum)}.'
                      : 'Catat uang yang diterima sekarang, bukan total pembayaran sebelumnya. Barang tidak otomatis diambil.'),
                  const SizedBox(height: 16),
                  TextFormField(
                      controller: _amount,
                      keyboardType: TextInputType.number,
                      readOnly: widget.maximum == 0,
                      decoration: const InputDecoration(
                          labelText: 'Pembayaran masuk (Rp)'),
                      validator: (value) {
                        final amount = int.tryParse(value?.trim() ?? '');
                        return amount == null ||
                                amount < widget.minimum ||
                                amount > widget.maximum
                            ? 'Masukkan nominal ${widget.minimum}–${widget.maximum}.'
                            : null;
                      }),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<PaymentMethod>(
                      initialValue: _method,
                      decoration:
                          const InputDecoration(labelText: 'Metode pembayaran'),
                      items: PaymentMethod.values
                          .map((value) => DropdownMenuItem(
                              value: value, child: Text(value.label)))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _method = value ?? _method)),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: _note,
                      maxLength: 1000,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          labelText: 'Catatan pembayaran (opsional)')),
                  const SizedBox(height: 16),
                  FilledButton(
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;
                        final amount = int.parse(_amount.text.trim());
                        final note = _note.text.trim().isEmpty
                            ? null
                            : _note.text.trim();
                        final old = widget.previous;
                        final retry = old != null &&
                            old.amount == amount &&
                            old.method == _method &&
                            old.note == note;
                        Navigator.of(context).pop(PaymentEntry(
                            amount: amount,
                            method: _method,
                            note: note,
                            requestId:
                                retry ? old.requestId : const Uuid().v4()));
                      },
                      child: Text(widget.forCollection
                          ? 'Konfirmasi Pengambilan'
                          : 'Catat Pembayaran')),
                ])),
      ));
}
