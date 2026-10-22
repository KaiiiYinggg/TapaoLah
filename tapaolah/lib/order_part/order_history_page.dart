import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tapaolah/order_part/track_order_history_page.dart';

class OrderHistoryPage extends StatefulWidget {
  final String userEmail;

  const OrderHistoryPage({super.key, required this.userEmail});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  String _filterStatus = 'all';
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        actions: [_buildStatusFilterDropdown()],
      ),
      body: _buildOrderList(),
    );
  }

  Future<void> _refundToWallet(
    String orderId,
    Map<String, dynamic> orderData,
  ) async {
    final userEmail = orderData['userEmail'];
    final refundAmount = orderData['finalTotal'];

    final walletRef = FirebaseFirestore.instance
        .collection('WalletBalance')
        .doc(userEmail);

    final orderRef = FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId);

    try {
      // Run in transaction
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final walletSnapshot = await transaction.get(walletRef);

        double currentBalance = 0;
        if (walletSnapshot.exists &&
            walletSnapshot.data()!.containsKey('balance')) {
          currentBalance = walletSnapshot['balance']?.toDouble() ?? 0;
        }

        // update balance
        transaction.set(walletRef, {
          'email': userEmail,
          'balance': currentBalance + refundAmount,
        }, SetOptions(merge: true));

        // update order as refunded
        transaction.update(orderRef, {'isRefunded': true});
      });

      debugPrint('✅ Refund RM$refundAmount to $userEmail');
    } catch (e) {
      debugPrint('❌ Refund failed: $e');
    }
  }

  // 状态筛选下拉菜单
  Widget _buildStatusFilterDropdown() {
    return DropdownButton<String>(
      value: _filterStatus,
      items: const [
        DropdownMenuItem(value: 'all', child: Text('All Orders')),
        DropdownMenuItem(value: 'pending', child: Text('Pending')),
        DropdownMenuItem(value: 'preparing', child: Text('Preparing')),
        DropdownMenuItem(value: 'completed', child: Text('Completed')),
        DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
      ],
      onChanged: (value) {
        if (value != null) {
          setState(() => _filterStatus = value);
        }
      },
    );
  }

  // 订单列表构建
  Widget _buildOrderList() {
    Query query = FirebaseFirestore.instance
        .collection('orders')
        .where('userEmail', isEqualTo: widget.userEmail)
        .orderBy('timestamp', descending: true);

    if (_filterStatus != 'all') {
      query = query.where('status', isEqualTo: _filterStatus);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No orders found'));
        }

        final docs = snapshot.data!.docs;

        // ✅ 退款检查
        for (var doc in docs) {
          final orderData = doc.data() as Map<String, dynamic>;
          if (orderData['status'] == 'cancelled' &&
              orderData['isRefunded'] != true) {
            _refundToWallet(doc.id, orderData);
          }
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final order = docs[index];
            final data = order.data() as Map<String, dynamic>;
            return _buildOrderCard(order.id, data);
          },
        );
      },
    );
  }

  Widget _buildOrderCard(String orderId, Map<String, dynamic> orderData) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToOrderDetails(orderId),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order ID + status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #${orderId.substring(0, 8)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Chip(
                    label: Text(
                      orderData['status'].toString().toUpperCase(),
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: _getStatusColor(orderData['status']),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Restaurant
              Text(
                orderData['restaurant'],
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),

              const SizedBox(height: 4),

              // Customer name
              if (orderData['customerName'] != null)
                Text('Name: ${orderData['customerName']}'),

              // Phone
              if (orderData['phone'] != null)
                Text('Phone: ${orderData['phone']}'),

              // Address
              if (orderData['address'] != null)
                Text('Address: ${orderData['address']}'),

              const SizedBox(height: 8),

              // Timestamp & total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _dateFormat.format(
                      (orderData['timestamp'] as Timestamp).toDate(),
                    ),
                    style: const TextStyle(color: Colors.grey),
                  ),
                  Text(
                    'RM${orderData['finalTotal'].toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Item preview
              if (orderData['items'] != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    ...(orderData['items'] as List<dynamic>)
                        .take(2)
                        .map(
                          (item) => Text(
                            '• ${item['name']} x${item['quantity']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                        .toList(),
                    if ((orderData['items'] as List).length > 2)
                      const Text('• ...more items'),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.blue;
      case 'preparing':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // 跳转到订单详情
  void _navigateToOrderDetails(String orderId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OrderDetailsPage(orderId: orderId)),
    );
  }
}
