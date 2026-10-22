import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:tapaolah/other_function_page/review_rating.dart';
import 'package:tapaolah/other_function_page/view_review.dart'; // 你需要创建这个页面

class OrderDetailsPage extends StatelessWidget {
  final String orderId;

  const OrderDetailsPage({super.key, required this.orderId});

  void _cancelOrder(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Cancellation'),
            content: const Text('Are you sure you want to cancel this order?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    DocumentSnapshot orderSnapshot =
                        await FirebaseFirestore.instance
                            .collection('orders')
                            .doc(orderId)
                            .get();

                    if (!orderSnapshot.exists) {
                      throw Exception('Order not found.');
                    }

                    final orderData =
                        orderSnapshot.data() as Map<String, dynamic>;
                    final String userEmail = orderData['userEmail'];
                    final double refundAmount =
                        (orderData['finalTotal'] ?? 0.00).toDouble();

                    await FirebaseFirestore.instance
                        .collection('orders')
                        .doc(orderId)
                        .update({'status': 'cancelled'});

                    DocumentReference walletRef = FirebaseFirestore.instance
                        .collection('WalletBalance')
                        .doc(userEmail);

                    DocumentSnapshot walletSnapshot = await walletRef.get();

                    if (walletSnapshot.exists) {
                      final double currentBalance =
                          (walletSnapshot['balance'] ?? 0.00).toDouble();

                      await walletRef.update({
                        'balance': currentBalance + refundAmount,
                      });
                    } else {
                      await walletRef.set({'balance': refundAmount});
                    }

                    Navigator.pop(context); // close dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Order cancelled & money refunded'),
                      ),
                    );
                    Navigator.pop(context); // go back
                  } catch (e) {
                    Navigator.pop(context); // close dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                },
                child: const Text('Yes'),
              ),
            ],
          ),
    );
  }

  Future<bool> _hasReviewed(String orderId) async {
    final reviewSnapshot =
        await FirebaseFirestore.instance
            .collection('reviews')
            .where('orderId', isEqualTo: orderId)
            .limit(1)
            .get();
    return reviewSnapshot.docs.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${orderId.substring(0, 8)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed:
                () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderDetailsPage(orderId: orderId),
                  ),
                ),
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future:
            FirebaseFirestore.instance.collection('orders').doc(orderId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Order not found'));
          }

          final order = snapshot.data!.data() as Map<String, dynamic>;

          return FutureBuilder<bool>(
            future: _hasReviewed(orderId),
            builder: (context, reviewSnap) {
              if (!reviewSnap.hasData) return const CircularProgressIndicator();
              final hasReviewed = reviewSnap.data!;

              return _buildOrderDetails(
                context,
                order,
                dateFormat,
                hasReviewed,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderDetails(
    BuildContext context,
    Map<String, dynamic> order,
    DateFormat dateFormat,
    bool hasReviewed,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: _getStatusColor(order['status']),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'ORDER STATUS',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order['status'].toString().toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (order['status'] == 'preparing')
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'The restaurant is preparing your order',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'ORDER SUMMARY',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const Divider(),
          _buildDetailRow(
            'Order Date',
            dateFormat.format((order['timestamp'] as Timestamp).toDate()),
          ),
          _buildDetailRow('Restaurant', order['restaurant']),
          _buildDetailRow('Order Type', order['orderType']),
          if ((order['address']?.isNotEmpty ?? false))
            _buildDetailRow('Delivery Address', order['address']),
          const SizedBox(height: 20),
          const Text('ITEMS', style: TextStyle(fontWeight: FontWeight.bold)),
          const Divider(),
          ...(order['items'] as List<dynamic>).map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      item['imageUrl'] ?? '',
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, __, ___) => Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey[200],
                            child: const Icon(Icons.fastfood),
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text('${item['quantity']} x RM${item['price']}'),
                      ],
                    ),
                  ),
                  Text('RM${(item['totalPrice'] as num).toStringAsFixed(2)}'),
                ],
              ),
            ),
          ),
          const Divider(),
          _buildDetailRow(
            'Subtotal',
            'RM${(order['finalTotal'] - (order['deliveryFee'] ?? 0)).toStringAsFixed(2)}',
          ),
          if ((order['discount'] ?? 0) > 0)
            _buildDetailRow(
              'Discount',
              '-RM${(order['discount'] ?? 0).toStringAsFixed(2)}',
            ),
          _buildDetailRow(
            'Delivery Fee',
            'RM${(order['deliveryFee'] ?? 0).toStringAsFixed(2)}',
          ),

          const Divider(),
          _buildDetailRow(
            'TOTAL',
            'RM${(order['finalTotal'] ?? 0).toStringAsFixed(2)}',
            isTotal: true,
          ),

          const SizedBox(height: 24),

          if (order['status'] == 'pending' || order['status'] == 'preparing')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[50],
                  foregroundColor: Colors.red,
                ),
                onPressed: () => _cancelOrder(context),
                child: const Text('Cancel Order'),
              ),
            ),
          if (order['status'] == 'completed')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      hasReviewed ? Colors.blue[50] : Colors.green[50],
                  foregroundColor:
                      hasReviewed ? Colors.blue : Colors.green[800],
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) =>
                              hasReviewed
                                  ? ViewReviewPage(orderId: orderId)
                                  : RatingReviewPage(orderId: orderId),
                    ),
                  );
                },
                child: Text(
                  hasReviewed ? 'View Your Review' : 'Rate & Review Order',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // ✅ 让多行文字顶部对齐
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                fontSize: isTotal ? 18 : null,
              ),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
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
}
