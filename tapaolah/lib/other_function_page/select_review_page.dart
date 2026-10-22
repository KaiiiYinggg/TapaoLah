import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:tapaolah/other_function_page/review_rating.dart';

class SelectOrderToReviewPage extends StatelessWidget {
  final String userEmail;

  const SelectOrderToReviewPage({super.key, required this.userEmail});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Choose Order to Review")),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('orders')
                .where('userEmail', isEqualTo: userEmail)
                .where('status', isEqualTo: 'successful')
                .orderBy('timestamp', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Loading your completed orders...'),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No completed orders to review."));
          }

          final orders = snapshot.data!.docs;

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final data = order.data() as Map<String, dynamic>;

              return ListTile(
                title: Text(data['restaurant']),
                subtitle: Text(
                  DateFormat(
                    'yyyy-MM-dd HH:mm',
                  ).format((data['timestamp'] as Timestamp).toDate()),
                ),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  print('Selected orderId: ${order.id}');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RatingReviewPage(orderId: order.id),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
