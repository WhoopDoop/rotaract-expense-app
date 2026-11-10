import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/bill.dart';
import '../providers/bill_provider.dart';
import '../providers/auth_provider.dart';
import '../services/drive_service.dart';

/// Holds the text controllers for one line item in the form.
class _ItemRow {
  final TextEditingController item;
  final TextEditingController price;
  final TextEditingController qty;

  _ItemRow({String item = '', String price = '', String qty = '1'})
      : item = TextEditingController(text: item),
        price = TextEditingController(text: price),
        qty = TextEditingController(text: qty);

  void dispose() {
    item.dispose();
    price.dispose();
    qty.dispose();
  }
}

class AddEditBillScreen extends StatefulWidget {
  final String projectId;
  final Bill? existingBill;

  const AddEditBillScreen({super.key, required this.projectId, this.existingBill});

  @override
  State<AddEditBillScreen> createState() => _AddEditBillScreenState();
}

class _AddEditBillScreenState extends State<AddEditBillScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _categoryController;
  late TextEditingController _billNoController;
  final List<_ItemRow> _itemRows = [];
  String? _imagePath;
  String? _driveFileId;
  bool _isUploading = false;

  bool get _isEditing => widget.existingBill != null;

  @override
  void initState() {
    super.initState();
    final b = widget.existingBill;
    _categoryController = TextEditingController(text: b?.category ?? '');
    _imagePath = b?.imagePath;
    _driveFileId = b?.driveFileId;

    if (b != null) {
      for (final i in b.items) {
        _itemRows.add(_ItemRow(
          item: i.item,
          price: i.price.toString(),
          qty: i.quantity.toString(),
        ));
      }
    } else {
      _itemRows.add(_ItemRow());
    }

    final nextNo = context.read<BillProvider>().nextBillNo(widget.projectId);
    _billNoController = TextEditingController(text: (b?.billNo ?? nextNo).toString());
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _billNoController.dispose();
    for (final r in _itemRows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked != null) {
      setState(() {
        _imagePath = picked.path;
        _driveFileId = null; // force re-upload of the new photo
      });
    }
  }

  void _addItemRow() => setState(() => _itemRows.add(_ItemRow()));

  void _removeItemRow(int index) {
    setState(() {
      _itemRows[index].dispose();
      _itemRows.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUploading = true);

    try {
      if (_imagePath != null && _driveFileId == null) {
        final auth = context.read<AuthProvider>();
        final driveService = DriveService(auth.signInInstance);
        final fileName =
            'bill_${_billNoController.text}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        _driveFileId = await driveService.uploadImage(
          File(_imagePath!),
          fileName: fileName,
        );
      }

      final items = _itemRows
          .map((r) => BillItem(
                item: r.item.text.trim(),
                price: double.parse(r.price.text),
                quantity: double.parse(r.qty.text),
              ))
          .toList();

      final billProvider = context.read<BillProvider>();
      final bill = Bill(
        id: widget.existingBill?.id ?? const Uuid().v4(),
        projectId: widget.projectId,
        category: _categoryController.text.trim(),
        billNo: int.parse(_billNoController.text),
        items: items,
        imagePath: _imagePath,
        driveFileId: _driveFileId,
      );

      if (_isEditing) {
        billProvider.updateBill(bill);
      } else {
        billProvider.addBill(bill);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  List<String> _existingCategories(BuildContext context) {
    final grouped = context.read<BillProvider>().groupedByCategory(widget.projectId);
    return grouped.keys.toList();
  }

  Widget _buildItemCard(int index) {
    final row = _itemRows[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Text('Item ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_itemRows.length > 1)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Remove item',
                    onPressed: () => _removeItemRow(index),
                  ),
              ],
            ),
            TextFormField(
              controller: row.item,
              decoration: const InputDecoration(labelText: 'Item'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: row.price,
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) =>
                      (v == null || double.tryParse(v) == null) ? 'Invalid' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: row.qty,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) =>
                      (v == null || double.tryParse(v) == null) ? 'Invalid' : null,
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = _existingCategories(context);

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Bill' : 'Add a Bill')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Autocomplete<String>(
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) return categories;
                return categories.where((c) =>
                    c.toLowerCase().contains(textEditingValue.text.toLowerCase()));
              },
              initialValue: TextEditingValue(text: _categoryController.text),
              onSelected: (value) => _categoryController.text = value,
              fieldViewBuilder: (ctx, controller, focusNode, onSubmit) {
                controller.text = _categoryController.text;
                controller.addListener(() => _categoryController.text = controller.text);
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    hintText: 'e.g. Decoration, Transportation',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                );
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _billNoController,
              decoration: const InputDecoration(labelText: 'Bill No.'),
              keyboardType: TextInputType.number,
              validator: (v) => (v == null || int.tryParse(v) == null) ? 'Invalid' : null,
            ),
            const SizedBox(height: 20),
            for (int i = 0; i < _itemRows.length; i++) _buildItemCard(i),
            OutlinedButton.icon(
              onPressed: _addItemRow,
              icon: const Icon(Icons.add),
              label: const Text('Add another item to this bill'),
            ),
            const SizedBox(height: 20),
            if (_imagePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(_imagePath!), height: 180, fit: BoxFit.cover),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isUploading ? null : _save,
              child: _isUploading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Bill'),
            ),
          ],
        ),
      ),
    );
  }
}