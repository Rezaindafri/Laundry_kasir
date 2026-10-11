import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/navigation_write_guard.dart';
import '../../../../core/widgets/safe_modal_sheet.dart';
import '../../../../core/widgets/page_visibility_refresh.dart';
import '../../../transactions/presentation/widgets/payment_destination_picker.dart';
import '../../domain/entities/payment_destination.dart';
import '../providers/payment_destination_providers.dart';

class PaymentDestinationsScreen extends ConsumerWidget {
  const PaymentDestinationsScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref,
      [PaymentDestination? item]) async {
    final input = await showSafeModalBottomSheet<_DestinationInput>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _DestinationForm(item: item));
    if (input == null || !context.mounted) return;
    await _save(context, ref, input.fields,
        id: item?.id, image: input.image, imageName: input.imageName);
  }

  Future<void> _save(
      BuildContext context, WidgetRef ref, Map<String, dynamic> fields,
      {int? id, Uint8List? image, String? imageName}) async {
    try {
      await withNavigationWriteLock(
          ref,
          () => ref
              .read(paymentDestinationDataSourceProvider)
              .save(fields, id: id, image: image, imageName: imageName));
      ref.invalidate(paymentDestinationsProvider);
      if (id != null) ref.invalidate(paymentDestinationImageProvider(id));
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tujuan pembayaran tersimpan.')));
    } catch (_) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Tujuan pembayaran gagal disimpan. Periksa data/gambar dan coba lagi.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(navigationWritesProvider) > 0;
    final data = ref.watch(paymentDestinationsProvider);
    return PageVisibilityRefresh(
        onVisible: () async {
          if (busy) return;
          ref.invalidate(paymentDestinationsProvider);
          await ref.read(paymentDestinationsProvider.future);
        },
        child: NavigationWriteGuard(
            child: Scaffold(
          appBar: AppBar(title: const Text('Tujuan Pembayaran')),
          floatingActionButton: FloatingActionButton.extended(
              onPressed: busy ? null : () => _edit(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Tambah tujuan')),
          body: data.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Tujuan pembayaran belum dapat dimuat.'),
              TextButton(
                  onPressed: () => ref.invalidate(paymentDestinationsProvider),
                  child: const Text('Coba lagi'))
            ])),
            data: (items) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(paymentDestinationsProvider);
                  await ref.read(paymentDestinationsProvider.future);
                },
                child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    children: [
                      const Text(
                          'QRIS dan rekening berikut dapat digunakan Owner/Kasir dalam kelompok usaha ini. '
                          'Nomor rekening dienkripsi di server; tujuan yang dinonaktifkan tidak ditawarkan untuk pembayaran baru.'),
                      const SizedBox(height: 16),
                      if (items.isEmpty)
                        const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                                'Belum ada tujuan pembayaran. Tambahkan QRIS atau rekening transfer.')),
                      ...items.map((item) => Card(
                          child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(item.kind == 'qris'
                                            ? Icons.qr_code
                                            : Icons.account_balance_outlined),
                                        title: Text(item.label),
                                        subtitle: Text(item.isActive
                                            ? 'Aktif'
                                            : 'Nonaktif'),
                                        trailing: IconButton(
                                            tooltip: 'Ubah tujuan',
                                            icon:
                                                const Icon(Icons.edit_outlined),
                                            onPressed: busy
                                                ? null
                                                : () =>
                                                    _edit(context, ref, item))),
                                    if (item.kind == 'transfer') ...[
                                      SelectableText(item.accountNumber ?? ''),
                                      Text(
                                          'Atas nama ${item.accountHolder ?? ""}')
                                    ],
                                    if (item.kind == 'qris')
                                      TextButton(
                                          onPressed: () => showDialog<void>(
                                              context: context,
                                              builder: (_) => AlertDialog(
                                                      title: const Text(
                                                          'QRIS usaha'),
                                                      content: SizedBox(
                                                          width: 400,
                                                          child: PaymentDestinationInfo(
                                                              destination: item)),
                                                      actions: [
                                                        TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                    context),
                                                            child: const Text(
                                                                'Tutup'))
                                                      ])),
                                          child: const Text('Lihat QRIS')),
                                    SwitchListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: const Text(
                                            'Tersedia untuk pembayaran'),
                                        value: item.isActive,
                                        onChanged: busy
                                            ? null
                                            : (active) => _save(context, ref,
                                                {'is_active': active ? 1 : 0},
                                                id: item.id)),
                                  ])))),
                    ])),
          ),
        )));
  }
}

class _DestinationInput {
  const _DestinationInput(this.fields, this.image, this.imageName);
  final Map<String, dynamic> fields;
  final Uint8List? image;
  final String? imageName;
}

class _DestinationForm extends StatefulWidget {
  const _DestinationForm({this.item});
  final PaymentDestination? item;
  @override
  State<_DestinationForm> createState() => _DestinationFormState();
}

class _DestinationFormState extends State<_DestinationForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _bank, _holder, _number;
  late String _kind;
  Uint8List? _image;
  String? _imageName;
  bool _picking = false;
  String? _imageError;

  @override
  void initState() {
    super.initState();
    _kind = widget.item?.kind ?? 'transfer';
    _name = TextEditingController(text: widget.item?.name);
    _bank = TextEditingController(text: widget.item?.bankName);
    _holder = TextEditingController(text: widget.item?.accountHolder);
    _number = TextEditingController(text: widget.item?.accountNumber);
  }

  @override
  void dispose() {
    _name.dispose();
    _bank.dispose();
    _holder.dispose();
    _number.dispose();
    super.dispose();
  }

  Future<void> _chooseImage() async {
    setState(() => _picking = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
          withData: true);
      if (!mounted || picked == null) return;
      final file = picked.files.single;
      if (file.bytes == null || file.size > 2 * 1024 * 1024) {
        setState(
            () => _imageError = 'Pilih gambar PNG/JPG/WebP maksimal 2 MB.');
        return;
      }
      setState(() {
        _image = file.bytes;
        _imageName = file.name;
        _imageError = null;
      });
    } catch (_) {
      if (mounted)
        setState(() => _imageError = 'Gambar tidak dapat dipilih. Coba lagi.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
      child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
          child: Form(
              key: _form,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                        widget.item == null
                            ? 'Tambah tujuan pembayaran'
                            : 'Ubah tujuan pembayaran',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                        initialValue: _kind,
                        decoration: const InputDecoration(labelText: 'Jenis'),
                        items: const [
                          DropdownMenuItem(
                              value: 'transfer', child: Text('Transfer bank')),
                          DropdownMenuItem(value: 'qris', child: Text('QRIS'))
                        ],
                        onChanged: widget.item == null
                            ? (value) => setState(() => _kind = value!)
                            : null),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: _name,
                        maxLength: 100,
                        decoration: const InputDecoration(
                            labelText: 'Nama tujuan (mis. Rekening utama)'),
                        validator: (text) => text?.trim().isNotEmpty == true
                            ? null
                            : 'Nama wajib diisi.'),
                    if (_kind == 'transfer') ...[
                      TextFormField(
                          controller: _bank,
                          maxLength: 80,
                          decoration:
                              const InputDecoration(labelText: 'Nama bank'),
                          validator: (text) => text?.trim().isNotEmpty == true
                              ? null
                              : 'Nama bank wajib diisi.'),
                      TextFormField(
                          controller: _holder,
                          maxLength: 120,
                          decoration:
                              const InputDecoration(labelText: 'Atas nama'),
                          validator: (text) => text?.trim().isNotEmpty == true
                              ? null
                              : 'Pemilik rekening wajib diisi.'),
                      TextFormField(
                          controller: _number,
                          keyboardType: TextInputType.number,
                          maxLength: 34,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: const InputDecoration(
                              labelText: 'Nomor rekening'),
                          validator: (text) =>
                              RegExp(r'^\d{5,34}$').hasMatch(text ?? '')
                                  ? null
                                  : 'Masukkan 5–34 digit rekening.'),
                    ] else ...[
                      const Text(
                          'Gunakan gambar QRIS usaha yang sudah diterbitkan penyedia pembayaran. Maksimal 2 MB dan 2048 × 2048 piksel.'),
                      OutlinedButton.icon(
                          onPressed: _picking ? null : _chooseImage,
                          icon: const Icon(Icons.image_outlined),
                          label: Text(
                              _picking ? 'Memilih...' : 'Pilih gambar QRIS')),
                      if (_image != null)
                        Image.memory(_image!,
                            height: 160,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Text(
                                'Gambar tidak dapat dibaca. Pilih berkas QRIS yang valid.')),
                      if (_image == null && widget.item?.hasQrisImage == true)
                        const Text('Gambar yang tersimpan tetap digunakan.'),
                      if (_imageError != null)
                        Text(_imageError!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: _picking
                            ? null
                            : () {
                                if (!_form.currentState!.validate()) return;
                                if (_kind == 'qris' &&
                                    _image == null &&
                                    widget.item?.hasQrisImage != true) {
                                  setState(() => _imageError =
                                      'Gambar QRIS wajib dipilih.');
                                  return;
                                }
                                Navigator.pop(
                                    context,
                                    _DestinationInput({
                                      'kind': _kind,
                                      'name': _name.text.trim(),
                                      if (_kind == 'transfer') ...{
                                        'bank_name': _bank.text.trim(),
                                        'account_holder': _holder.text.trim(),
                                        'account_number': _number.text
                                      },
                                    }, _image, _imageName));
                              },
                        child: const Text('Simpan tujuan')),
                  ]))));
}
