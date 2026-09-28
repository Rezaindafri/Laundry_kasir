import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../printing/domain/entities/printer_device.dart';
import '../../../printing/presentation/providers/printing_providers.dart';
import '../../domain/entities/laundry_settings.dart';
import '../providers/settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(laundrySettingsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
        automaticallyImplyLeading: false,
      ),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Pengaturan gagal dimuat: $error')),
        data: (value) => _SettingsForm(value: value),
      ),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  final LaundrySettings value;
  const _SettingsForm({required this.value});

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late String _paper;
  String? _printerMac;
  String? _printerName;
  bool _loadingPrinters = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.value.businessName);
    _phone = TextEditingController(text: widget.value.phone);
    _address = TextEditingController(text: widget.value.address);
    _paper = widget.value.paperSize;
    _printerMac = widget.value.defaultPrinter;
    _printerName = widget.value.defaultPrinterName;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _choosePrinter() async {
    setState(() => _loadingPrinters = true);
    try {
      final devices =
          await ref.read(printerDeviceServiceProvider).getPairedDevices();
      if (!mounted) return;
      if (devices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Tidak ada printer Bluetooth yang telah dipasangkan di perangkat ini.')));
        return;
      }
      final selected = await showModalBottomSheet<PrinterDevice>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text('Pilih printer Bluetooth')),
              ...devices.map((device) => ListTile(
                    leading: const Icon(Icons.print_outlined),
                    title: Text(device.name.isEmpty
                        ? 'Printer tanpa nama'
                        : device.name),
                    subtitle: Text(device.macAddress),
                    trailing: device.macAddress == _printerMac
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                    onTap: () => Navigator.pop(sheetContext, device),
                  )),
            ],
          ),
        ),
      );
      if (selected != null) {
        setState(() {
          _printerMac = selected.macAddress;
          _printerName = selected.name;
        });
      }
    } on PrinterException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _loadingPrinters = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(laundrySettingsProvider.notifier).save(widget.value.copyWith(
          businessName: _name.text.trim(),
          phone: _phone.text.trim(),
          address: _address.text.trim(),
          paperSize: _paper,
          defaultPrinter: _printerMac,
          defaultPrinterName: _printerName,
        ));
    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Pengaturan tersimpan.')));
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Profil Pengguna',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                    controller: _name,
                    decoration:
                        const InputDecoration(labelText: 'Nama pengguna'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Nama pengguna wajib diisi'
                        : null),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration:
                        const InputDecoration(labelText: 'Nomor telepon')),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _address,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Alamat')),
                const SizedBox(height: 24),
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Printer',
                        style: Theme.of(context).textTheme.titleMedium)),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.bluetooth_connected),
                    title: Text(_printerMac == null || _printerMac!.isEmpty
                        ? 'Belum ada printer aplikasi'
                        : (_printerName?.isNotEmpty ?? false)
                            ? _printerName!
                            : 'Printer Bluetooth'),
                    subtitle: Text(_printerMac == null || _printerMac!.isEmpty
                        ? 'Pilih printer untuk digunakan aplikasi ini'
                        : 'Dipilih untuk aplikasi ini • $_printerMac'),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _loadingPrinters ? null : _choosePrinter,
                    icon: _loadingPrinters
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.bluetooth_searching),
                    label: Text(_printerMac == null || _printerMac!.isEmpty
                        ? 'Pilih printer'
                        : 'Ganti printer'),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _paper,
                  decoration: const InputDecoration(labelText: 'Ukuran kertas'),
                  items: const [
                    DropdownMenuItem(value: '58 mm', child: Text('58 mm')),
                    DropdownMenuItem(value: '80 mm', child: Text('80 mm')),
                  ],
                  onChanged: (value) => setState(() => _paper = value!),
                ),
                const SizedBox(height: 24),
                FilledButton(
                    onPressed: _save, child: const Text('Simpan pengaturan')),
              ],
            ),
          ),
        ],
      );
}
