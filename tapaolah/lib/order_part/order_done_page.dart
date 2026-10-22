import 'package:flutter/material.dart';
import 'package:tapaolah/order_part/track_order_history_page.dart';

class OrderConfirmationPage extends StatelessWidget {
  final String orderId;
  final double total;
  final String restaurantName;

  const OrderConfirmationPage({
    super.key,
    required this.orderId,
    required this.total,
    required this.restaurantName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order Confirmation')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 80),
              const SizedBox(height: 20),
              Text(
                'Your order at $restaurantName is confirmed!',
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              Text(
                'Order #${orderId.substring(0, 8)}',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              Text(
                'RM${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderDetailsPage(orderId: orderId),
                    ),
                  );
                },
                child: const Text('View Order Details'),
              ),
              TextButton(
                onPressed: () => Navigator.popUntil(
                  context, 
                  (route) => route.isFirst, // 返回首页
                ),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}