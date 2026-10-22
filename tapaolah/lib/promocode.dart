// file: admin_add_promocode_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AddPromoCodePage extends StatefulWidget {
  const AddPromoCodePage({super.key});

  @override
  State<AddPromoCodePage> createState() => _AddPromoCodePageState();
}

class _AddPromoCodePageState extends State<AddPromoCodePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();

  String _discountType = 'percentage';
  DateTime? _validUntil;

  Future<void> _submitPromo() async {
    if (!_formKey.currentState!.validate() || _validUntil == null) return;

    final promo = {
      'code': _codeController.text.trim().toUpperCase(),
      'description': _descController.text.trim(),
      'discountType': _discountType,
      'discountValue': double.parse(_discountController.text.trim()),
      'createdAt': Timestamp.now(),
      'validUntil': Timestamp.fromDate(_validUntil!),
      'targetUsers': 'all',
    };

    await FirebaseFirestore.instance.collection('promoCodes').add(promo);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("✅ Promo code added")));
    _formKey.currentState!.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Promo Code")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: 'Promo Code'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              DropdownButtonFormField(
                value: _discountType,
                decoration: const InputDecoration(labelText: 'Discount Type'),
                items: const [
                  DropdownMenuItem(
                    value: 'percentage',
                    child: Text('Percentage'),
                  ),
                  DropdownMenuItem(value: 'flat', child: Text('Flat RM')),
                ],
                onChanged: (val) {
                  setState(() => _discountType = val.toString());
                },
              ),
              TextFormField(
                controller: _discountController,
                decoration: const InputDecoration(labelText: 'Discount Value'),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(
                  _validUntil == null
                      ? "Choose valid until date"
                      : "Valid until: ${DateFormat.yMd().format(_validUntil!)}",
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() => _validUntil = picked);
                  }
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submitPromo,
                child: const Text("Add Promo Code"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
