import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tapaolah/home/home_page.dart';
import 'package:tapaolah/other_function_page/info_page.dart';
import 'package:tapaolah/utilis/navigation_bar.dart';

class TopUpPage extends StatefulWidget {
  final String email;
  const TopUpPage({super.key, required this.email});

  @override
  State<TopUpPage> createState() => _TopUpPageState();
}

class _TopUpPageState extends State<TopUpPage> {
  double _balance = 0.0;
  final TextEditingController _topUpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  int _selectedIndex = 0;

  String _selectedTopUpType = 'Online Top-Up';
  final List<String> _topUpTypes = ['Online Top-Up', 'Card Top-Up'];
  String? _selectedBank;

  @override
  void initState() {
    super.initState();
    _fetchBalance();
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);

    if (index == 1) return;

    if (index == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MainFoodPage(email: widget.email)),
      );
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => InfoPage(email: widget.email)),
      );
    }
  }

  Future<void> _fetchBalance() async {
    final doc =
        await FirebaseFirestore.instance
            .collection('WalletBalance')
            .doc(widget.email)
            .get();

    if (doc.exists) {
      setState(() {
        _balance = (doc.data()?['balance'] ?? 0.0).toDouble();
      });
    } else {
      await FirebaseFirestore.instance
          .collection('WalletBalance')
          .doc(widget.email)
          .set({'email': widget.email, 'balance': 0.0});
      setState(() => _balance = 0.0);
    }
  }

  Future<void> _topUp() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedBank == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Please select a bank")));
        return;
      }

      if (_selectedTopUpType == 'Online Top-Up') {
        await _onlineTopUp();
      } else {
        await _cardTopUp();
      }
    }
  }

  Future<void> _onlineTopUp() async {
    final double topUpAmount = double.parse(_topUpController.text);
    final newBalance = _balance + topUpAmount;

    await FirebaseFirestore.instance
        .collection('WalletBalance')
        .doc(widget.email)
        .update({'balance': newBalance});

    setState(() {
      _balance = newBalance;
      _topUpController.clear();
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Online Top Up successful')));
  }

  Future<void> _cardTopUp() async {
    // Replace this with your real card top up logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Card Top Up simulated (Bank: $_selectedBank)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        title: const Text("Bank Top Up"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWalletCard(),
            const SizedBox(height: 30),

            const Text(
              "Top Up Amount",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),

            Form(
              key: _formKey,
              child: TextFormField(
                controller: _topUpController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Enter amount (e.g. 50.00)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (value) {
                  final amount = double.tryParse(value ?? '');
                  if (amount == null || amount <= 0) {
                    return 'Enter a valid amount greater than 0';
                  }
                  return null;
                },
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              "Choose Top-Up Type",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedTopUpType,
              items:
                  _topUpTypes.map((type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedTopUpType = value!;
                });
              },
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),

            const SizedBox(height: 20),

            const Text(
              "Choose Bank",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildBankButton("Maybank", Icons.account_balance),
                _buildBankButton("CIMB", Icons.account_balance_wallet),
                _buildBankButton("Public Bank", Icons.account_balance_outlined),
              ],
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _topUp,
                icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
                label: const Text(
                  "Confirm Top Up",
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildWalletCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.indigo,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "My Wallet",
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Text(
            "RM ${_balance.toStringAsFixed(2)}",
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("VIRTUAL CARD", style: TextStyle(color: Colors.white)),
              Icon(Icons.credit_card, color: Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBankButton(String name, IconData icon) {
    Color bankColor;

    switch (name) {
      case "Maybank":
        bankColor = Colors.amber.shade800;
        break;
      case "CIMB":
        bankColor = Colors.red.shade700;
        break;
      case "Public Bank":
        bankColor = Colors.green.shade700;
        break;
      default:
        bankColor = Colors.indigo;
    }

    final bool isSelected = _selectedBank == name;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedBank = name;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("$name selected")));
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 110,
        height: 90,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? bankColor.withOpacity(0.2)
                  : bankColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? bankColor : Colors.grey.shade400,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: bankColor, size: 32),
            const SizedBox(height: 8),
            Text(
              name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: bankColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
