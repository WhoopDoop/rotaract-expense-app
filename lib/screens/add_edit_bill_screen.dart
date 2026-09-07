import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/bill.dart';
import '../providers/bill_provider.dart';

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
  late TextEditingController _itemController;
  late TextEditingController _priceController;
  late TextEditingController _qtyController;
  late TextEditingController _billNoController;
  String? _imagePath;

  bool get _isEditing => widget.existingBill != null;

  @override
  void initState() {
    super.initState();
    final b = widget.existingBill;
    _categoryController = TextEditingController(text: b?.category ?? '');
    _itemController = TextEditingController(text: b?.item ?? '');
    _priceController = TextEditingController(text: b?.price.toString() ?? '');
    _qtyController = TextEditingController(text: b?.quantity.toString() ?? '1');
    _imagePath = b?.imagePath;

    final nextNo = context.read<BillProvider>().nextBillNo(widget.projectId);
    _billNoController = TextEditingController(text: (b?.billNo ?? nextNo).toString());
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked != null) {
      setState(() => _imagePath = picked.path);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final billProvider = context.read<BillProvider>();
    final bill = Bill(
      id: widget.existingBill?.id ?? const Uuid().v4(),
      projectId: widget.projectId,
      category: _categoryController.text.trim(),
      item: _itemController.text.trim(),
      price: double.parse(_priceController.text),
      quantity: double.parse(_qtyController.text),
      billNo: int.parse(_billNoController.text),
      imagePath: _imagePath,
    );

    if (_isEditing) {
      billProvider.updateBill(bill);
    } else {
      billProvider.addBill(bill);
    }
    Navigator.pop(context);
  }

  // Suggest previously used categories in this project for quick entry.
  List<String> _existingCategories(BuildContext context) {
    final grouped = context.read<BillProvider>().groupedByCategory(widget.projectId);
    return grouped.keys.toList();
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
              controller: _itemController,
              decoration: const InputDecoration(labelText: 'Item'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) =>
                      (v == null || double.tryParse(v) == null) ? 'Invalid' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _qtyController,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) =>
                      (v == null || double.tryParse(v) == null) ? 'Invalid' : null,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _billNoController,
              decoration: const InputDecoration(labelText: 'Bill No.'),
              keyboardType: TextInputType.number,
              validator: (v) => (v == null || int.tryParse(v) == null) ? 'Invalid' : null,
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
            FilledButton(onPressed: _save, child: const Text('Save Bill')),
          ],
        ),
      ),
    );
  }
}