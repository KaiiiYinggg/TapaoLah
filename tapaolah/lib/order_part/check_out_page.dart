import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tapaolah/home/topup.dart';
import 'package:tapaolah/order_part/order_done_page.dart';
import 'package:tapaolah/order_part/edit_order_info.dart';

class CheckoutPage extends StatefulWidget {
  final String restaurantName;
  final List<DocumentSnapshot> items;
  final String restaurantId;
  final double totalPrice;
  final String userEmail;

  const CheckoutPage({
    super.key,
    required this.restaurantName,
    required this.restaurantId,
    required this.items,
    required this.totalPrice,
    required this.userEmail,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  String orderType = 'Pickup';
  double discount = 0.0;
  double deliveryFee = 0.0;
  double walletBalance = 0.0;
  bool isBalanceLoading = true;
  bool isProcessing = false;
  Map<String, dynamic> orderInfo = {'name': '', 'phone': '', 'address': ''};
  DateTime? _lastPressTime;
  String remark = '';
  TimeOfDay? pickupTime;
  DateTime? deliveryDateTime;
  List<DocumentSnapshot> _cartItems = [];
  double discountAmount = 0.0;
  String appliedPromoCode = '';
  String discountMessage = '';
  bool isPromoApplied = false;

  final promoController = TextEditingController();
  final remarkController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cartItems = widget.items;
    fetchOrderInfo();
    fetchWalletBalance();
    pickupTime = TimeOfDay.fromDateTime(
      DateTime.now().add(Duration(minutes: 30)),
    );
    deliveryDateTime = DateTime.now().add(Duration(hours: 1));
  }

  double get currentSubtotal {
    return _cartItems.fold(0.0, (sum, item) {
      final data = item.data() as Map<String, dynamic>;
      return sum + (data['totalPrice'] ?? 0.0);
    });
  }

  double get finalTotal {
    double base = currentSubtotal + deliveryFee - discountAmount;
    return base < 0 ? 0 : base;
  }

  // 自动刷新的数量修改方法
  Future<void> _updateCartItemQuantity(String docId, int newQuantity) async {
    if (newQuantity < 1) return;

    setState(() => isProcessing = true);

    try {
      final cartRef = FirebaseFirestore.instance.collection('cart').doc(docId);
      final doc = await cartRef.get();

      if (doc.exists) {
        final unitPrice = doc['price'];
        await cartRef.update({
          'quantity': newQuantity,
          'totalPrice': newQuantity * unitPrice,
        });

        // 获取最新购物车数据
        final updatedCart = await _fetchCartItems();
        setState(() => _cartItems = updatedCart);
      }
    } catch (e) {
      debugPrint("Error updating quantity: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新失败: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  // 自动刷新的删除方法
  // 在 _removeCartItem 方法中添加导航返回
  Future<void> _removeCartItem(String docId) async {
    setState(() => isProcessing = true);

    try {
      await FirebaseFirestore.instance.collection('cart').doc(docId).delete();

      // 获取更新后的购物车
      final updatedCart = await _fetchCartItems();

      if (updatedCart.isEmpty) {
        // 如果购物车为空，返回上一页
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          setState(() {
            _cartItems = updatedCart;
            isProcessing = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error removing item: $e");
      if (mounted) {
        setState(() => isProcessing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  Future<List<DocumentSnapshot>> _fetchCartItems() async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('cart')
            .where('userEmail', isEqualTo: widget.userEmail)
            .where('restId', isEqualTo: widget.restaurantId)
            .get();
    return snapshot.docs;
  }

  Future<void> fetchOrderInfo() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('orderDetails')
              .doc(widget.userEmail.trim())
              .get();

      if (doc.exists && mounted) {
        setState(() {
          orderInfo = {
            'name': doc.data()?['name'] ?? '',
            'phone': doc.data()?['phone'] ?? '',
            'address': doc.data()?['address'] ?? '',
          };
        });
      }
    } catch (e) {
      debugPrint("Error fetching order info: $e");
      if (mounted) {
        setState(() {
          orderInfo = {'name': '', 'phone': '', 'address': ''};
        });
      }
    }
  }

  Future<void> fetchWalletBalance() async {
    if (!mounted) return;

    setState(() => isBalanceLoading = true);
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('WalletBalance')
              .doc(widget.userEmail.trim())
              .get();

      if (!mounted) return;

      if (doc.exists) {
        final data = doc.data();
        final balance = data?['balance'] ?? 0.0;

        setState(() {
          walletBalance =
              balance is int
                  ? balance.toDouble()
                  : balance is double
                  ? balance
                  : double.tryParse(balance.toString()) ?? 0.0;
        });
      } else {
        await FirebaseFirestore.instance
            .collection('WalletBalance')
            .doc(widget.userEmail.trim())
            .set({'balance': 0.0});
        if (mounted) setState(() => walletBalance = 0.0);
      }
    } catch (e) {
      debugPrint("Error fetching wallet: $e");
      if (mounted) setState(() => walletBalance = 0.0);
    } finally {
      if (mounted) setState(() => isBalanceLoading = false);
    }
  }

  Future<void> _selectPickupTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: pickupTime ?? TimeOfDay.now(),
    );
    if (picked != null && mounted) {
      setState(() => pickupTime = picked);
    }
  }

  Future<void> _selectDeliveryDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: deliveryDateTime ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 7)),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
          deliveryDateTime ?? DateTime.now().add(Duration(hours: 1)),
        ),
      );
      if (pickedTime != null && mounted) {
        setState(() {
          deliveryDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> applyPromo(String code) async {
    if (code.isEmpty) {
      setState(() {
        discountAmount = 0.0;
        isPromoApplied = false;
        discountMessage = 'Please enter a promo code';
      });
      return;
    }

    setState(() => isProcessing = true);

    final result = await applyPromoCode(code, widget.userEmail);

    if (!mounted) return;

    setState(() {
      isProcessing = false;
      if (result?['success'] == true) {
        appliedPromoCode = code.toUpperCase();
        isPromoApplied = true;
        discountMessage = result!['message'];

        // Calculate discount based on type
        if (result['discountType'] == 'percentage') {
          discountAmount = currentSubtotal * (result['discountValue'] / 100);
        } else {
          // Assume fixed amount if not percentage
          discountAmount = result['discountValue'].toDouble();
        }
      } else {
        discountAmount = 0.0;
        isPromoApplied = false;
        discountMessage = result?['message'] ?? 'Failed to apply promo code';
      }
    });

    // Show result message
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(discountMessage)));
  }

  Future<Map<String, dynamic>?> applyPromoCode(
    String code,
    String userEmail,
  ) async {
    try {
      // 1. Check if promo code exists and is valid
      final promoSnapshot =
          await FirebaseFirestore.instance
              .collection('promoCodes')
              .where('code', isEqualTo: code.trim().toUpperCase())
              .limit(1)
              .get();

      if (promoSnapshot.docs.isEmpty) {
        return {'success': false, 'message': 'Promo code not found'};
      }

      final promoData = promoSnapshot.docs.first.data();
      final now = DateTime.now();
      final validUntil = (promoData['validUntil'] as Timestamp).toDate();

      // 2. Check expiration
      if (now.isAfter(validUntil)) {
        return {'success': false, 'message': 'Promo code has expired'};
      }

      // 3. Check user eligibility (you can expand this based on targetUsers)
      if (promoData['targetUsers'] != 'all') {
        // Add additional user checks here if needed
        return {
          'success': false,
          'message': 'Promo code not available for your account',
        };
      }

      // 4. Return discount details
      return {
        'success': true,
        'discountType': promoData['discountType'],
        'discountValue': promoData['discountValue'],
        'message': 'Promo code applied successfully!',
      };
    } catch (e) {
      debugPrint('Error applying promo code: $e');
      return {'success': false, 'message': 'Error applying promo code'};
    }
  }

  Future<void> _handleTopUpFlow() async {
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TopUpPage(email: widget.userEmail)),
      );

      if (mounted) {
        await fetchWalletBalance();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Wallet balance updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ Failed to top up: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> processPayment() async {
    if (_lastPressTime != null &&
        DateTime.now().difference(_lastPressTime!) <
            Duration(milliseconds: 500)) {
      return;
    }
    _lastPressTime = DateTime.now();

    if (!mounted || isProcessing) return;

    // 验证必填字段
    if (orderInfo['name']?.isEmpty ?? true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Please enter your name')));
      return;
    }

    if (orderInfo['phone']?.isEmpty ?? true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Please enter your phone number')),
      );
      return;
    }

    if (orderType == 'Delivery' && (orderInfo['address']?.isEmpty ?? true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Please enter your address for delivery')),
      );
      return;
    }

    setState(() => isProcessing = true);
    try {
      String? newOrderId;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final walletDoc = FirebaseFirestore.instance
            .collection('WalletBalance')
            .doc(widget.userEmail.trim());

        final walletSnapshot = await transaction.get(walletDoc);
        final currentBalance = walletSnapshot.data()?['balance'] ?? 0.0;

        if (currentBalance < finalTotal) {
          throw Exception('Insufficient balance');
        }

        transaction.update(walletDoc, {
          'balance': currentBalance - finalTotal,
          'lastUpdated': FieldValue.serverTimestamp(),
          'lastTransaction': {
            'amount': -finalTotal,
            'type': 'order_payment',
            'timestamp': FieldValue.serverTimestamp(),
          },
        });

        final orderDoc = FirebaseFirestore.instance.collection('orders').doc();
        newOrderId = orderDoc.id;

        final now = DateTime.now();
        final pickupDateTime = DateTime(
          now.year,
          now.month,
          now.day,
          pickupTime!.hour,
          pickupTime!.minute,
        );

        transaction.set(orderDoc, {
          'restaurant': widget.restaurantName,
          'restaurantId': widget.restaurantId,
          'userEmail': widget.userEmail,
          'items':
              _cartItems.map((e) {
                final data = e.data() as Map<String, dynamic>;
                return {
                  'name': data['name'] ?? 'Unknown',
                  'quantity': data['quantity'] ?? 1,
                  'price': data['price'] ?? 0.0,
                  'totalPrice': data['totalPrice'] ?? 0.0,
                  'imageUrl': data['imageUrl'],
                  'foodId': data['foodId'] ?? '',
                };
              }).toList(),
          'customerName': orderInfo['name'] ?? '',
          'address': orderInfo['address'] ?? '',
          'phone': orderInfo['phone'] ?? '',
          'orderType': orderType,
          'deliveryFee': deliveryFee,
          'discount': discount,
          'finalTotal': finalTotal,
          'status': 'pending',
          'remark': remarkController.text,
          'pickupTime': orderType == 'Pickup' ? pickupDateTime : null,
          'deliveryTime': orderType == 'Delivery' ? deliveryDateTime : null,
          'timestamp': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;

      // 清空购物车
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in _cartItems) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => OrderConfirmationPage(
                orderId: newOrderId!,
                total: finalTotal,
                restaurantName: widget.restaurantName,
              ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      debugPrint('Payment error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ ${e.toString()}')));

      if (e.toString().contains('Insufficient')) {
        await _handleTopUpFlow();
      }
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Checkout - ${widget.restaurantName}")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  // Shopping cart items list
                  ..._cartItems.map((item) {
                    final data = item.data() as Map<String, dynamic>;
                    final int quantity = data['quantity'] ?? 1;
                    final double totalPrice = data['totalPrice'] ?? 0.0;

                    return ListTile(
                      leading: Image.network(
                        data['imageUrl'],
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                      title: Text(data['name']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("RM${totalPrice.toStringAsFixed(2)}"),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.remove),
                                onPressed:
                                    isProcessing
                                        ? null
                                        : () => _updateCartItemQuantity(
                                          item.id,
                                          quantity - 1,
                                        ),
                              ),
                              Text('$quantity'),
                              IconButton(
                                icon: Icon(Icons.add),
                                onPressed:
                                    isProcessing
                                        ? null
                                        : () => _updateCartItemQuantity(
                                          item.id,
                                          quantity + 1,
                                        ),
                              ),
                              Spacer(),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed:
                                    isProcessing
                                        ? null
                                        : () => _removeCartItem(item.id),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                  Divider(),

                  // Order type selection
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Order Type:"),
                      DropdownButton<String>(
                        value: orderType,
                        items:
                            ['Pickup', 'Delivery'].map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              );
                            }).toList(),
                        onChanged: (value) {
                          if (mounted) {
                            setState(() {
                              orderType = value!;
                              deliveryFee = value == 'Delivery' ? 5.0 : 0.0;
                            });
                          }
                        },
                      ),
                    ],
                  ),

                  // Time selection
                  if (orderType == 'Pickup')
                    ListTile(
                      title: Text('Pickup Time'),
                      subtitle: Text(
                        pickupTime != null
                            ? DateFormat.jm().format(
                              DateTime(
                                DateTime.now().year,
                                DateTime.now().month,
                                DateTime.now().day,
                                pickupTime!.hour,
                                pickupTime!.minute,
                              ),
                            )
                            : 'Not selected',
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.access_time),
                        onPressed: _selectPickupTime,
                      ),
                    )
                  else
                    ListTile(
                      title: Text('Delivery Time'),
                      subtitle: Text(
                        deliveryDateTime != null
                            ? DateFormat.yMMMd().add_jm().format(
                              deliveryDateTime!,
                            )
                            : 'Not selected',
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.access_time),
                        onPressed: _selectDeliveryDateTime,
                      ),
                    ),

                  // Promo code input
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: promoController,
                          decoration: InputDecoration(
                            labelText: 'Promo Code',
                            hintText: 'e.g. PRO123',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                        ),
                        onPressed:
                            isProcessing
                                ? null
                                : () => applyPromo(promoController.text),
                        child: Text('APPLY'),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),

                  // Applied promo display
                  if (isPromoApplied)
                    Container(
                      margin: EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                        leading: Icon(Icons.discount, color: Colors.green),
                        title: Text(
                          'Promo Applied: $appliedPromoCode',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(discountMessage),
                        trailing: IconButton(
                          icon: Icon(Icons.close, size: 20),
                          onPressed: () {
                            setState(() {
                              discountAmount = 0.0;
                              isPromoApplied = false;
                              appliedPromoCode = '';
                              discountMessage = '';
                            });
                          },
                        ),
                      ),
                    ),

                  // Order remarks
                  TextField(
                    controller: remarkController,
                    decoration: InputDecoration(
                      labelText: 'Remarks (Optional)',
                      hintText: 'Special instructions, allergies, etc.',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  SizedBox(height: 16),

                  // Wallet balance
                  ListTile(
                    title: Text('Wallet Balance'),
                    trailing:
                        isBalanceLoading
                            ? CircularProgressIndicator()
                            : Text(
                              "RM${walletBalance.toStringAsFixed(2)}",
                              style: TextStyle(
                                color:
                                    walletBalance >= finalTotal
                                        ? Colors.green
                                        : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                  ),

                  // Order information
                  ListTile(
                    title: Text('Order Information'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Name: ${orderInfo['name']?.isNotEmpty == true ? orderInfo['name'] : 'Not set'}',
                        ),
                        if (orderType == 'Delivery') ...[
                          Text(
                            'Phone: ${orderInfo['phone']?.isNotEmpty == true ? orderInfo['phone'] : 'Not set'}',
                          ),
                          Text(
                            'Address: ${orderInfo['address']?.isNotEmpty == true ? orderInfo['address'] : 'Not set'}',
                          ),
                        ],
                      ],
                    ),
                    trailing: TextButton(
                      child: Text(
                        "Edit",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        final updatedInfo = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => OrderInfoPage(
                                  email: widget.userEmail,
                                  deliveryMethod: orderType, // 这里继续传 orderType
                                ),
                          ),
                        );
                        if (mounted && updatedInfo != null) {
                          setState(() => orderInfo = updatedInfo);
                        } else if (mounted) {
                          await fetchOrderInfo();
                        }
                      },
                    ),
                  ),

                  Divider(thickness: 1.5),

                  // Payment summary
                  _buildAmountRow("Subtotal", currentSubtotal),
                  _buildAmountRow("Delivery Fee", deliveryFee),
                  _buildAmountRow(
                    "Discount${appliedPromoCode.isNotEmpty ? ' ($appliedPromoCode)' : ''}",
                    -discountAmount,
                  ),
                  Divider(thickness: 1.5),
                  _buildAmountRow("TOTAL PAYMENT", finalTotal, isTotal: true),
                  SizedBox(height: 20),
                ],
              ),
            ),

            // Payment button
            ElevatedButton.icon(
              icon:
                  isProcessing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Icon(Icons.payment),
              label: Text(isProcessing ? "Processing..." : "Confirm & Pay"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Colors.green,
                disabledBackgroundColor: Colors.grey,
              ),
              onPressed: isProcessing ? null : processPayment,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            "RM${amount.toStringAsFixed(2)}",
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: amount < 0 ? Colors.red : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
