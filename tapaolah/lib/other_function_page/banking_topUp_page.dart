import 'package:flutter/material.dart';

class BankingTopUpPage extends StatefulWidget {
  final String email;
  final Function(double) onTopUpSuccess;

  const BankingTopUpPage({
    super.key,
    required this.email,
    required this.onTopUpSuccess,
  });

  @override
  State<BankingTopUpPage> createState() => _BankingTopUpPageState();
}

class _BankingTopUpPageState extends State<BankingTopUpPage> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedBank;
  final TextEditingController _accountNumberController =
      TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  final List<String> _bankList = [
    'Maybank',
    'CIMB',
    'RHB',
    'Public Bank',
    'Hong Leong Bank',
  ];

  void _simulateBankTransfer() {
    if (_formKey.currentState!.validate()) {
      final amount = double.parse(_amountController.text);

      // 模拟转账成功
      widget.onTopUpSuccess(amount);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Transfer Successful")));

      Navigator.pop(context); // 返回钱包页面
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Link Banking Transfer"),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedBank,
                hint: const Text("Select Bank"),
                items:
                    _bankList.map((bank) {
                      return DropdownMenuItem(value: bank, child: Text(bank));
                    }).toList(),
                onChanged: (value) => setState(() => _selectedBank = value),
                validator:
                    (value) => value == null ? 'Please select a bank' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _accountNumberController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Bank Account Number',
                  border: OutlineInputBorder(),
                ),
                validator:
                    (value) =>
                        (value == null || value.isEmpty || value.length < 8)
                            ? 'Enter valid account number'
                            : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount to Transfer (RM)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final amount = double.tryParse(value ?? '');
                  if (amount == null || amount <= 0) {
                    return 'Enter a valid amount > 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _simulateBankTransfer,
                  child: const Text("Confirm Transfer"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
