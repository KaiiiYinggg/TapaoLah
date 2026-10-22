import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ViewReviewPage extends StatelessWidget {
  final String orderId;

  const ViewReviewPage({super.key, required this.orderId});

  Future<Map<String, List<Map<String, dynamic>>>> _fetchReviews() async {
    final query =
        await FirebaseFirestore.instance
            .collection('reviews')
            .where('orderId', isEqualTo: orderId)
            .get();

    final restaurantReviews = <Map<String, dynamic>>[];
    final foodReviews = <Map<String, dynamic>>[];

    for (var doc in query.docs) {
      final data = doc.data();
      if (data['type'] == 'restaurant') {
        restaurantReviews.add(data);
      } else if (data['type'] == 'food') {
        foodReviews.add(data);
      }
    }

    return {'restaurant': restaurantReviews, 'food': foodReviews};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Ratings & Reviews')),
      body: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
        future: _fetchReviews(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No review data found."));
          }

          final restaurant = snapshot.data!['restaurant']!;
          final food = snapshot.data!['food']!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Restaurant Review',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (restaurant.isNotEmpty)
                  _buildReviewCard(restaurant.first)
                else
                  const Text('No restaurant review.'),
                const SizedBox(height: 24),
                const Text(
                  'Food Reviews',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (food.isEmpty)
                  const Text('No food reviews.')
                else
                  ...food.map(_buildReviewCard).toList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final rating = (review['rating'] ?? 0).toDouble();
    final comment = review['comment'] ?? '';
    final label =
        review['type'] == 'restaurant'
            ? review['restId'] ?? 'Restaurant'
            : review['foodName'] ?? 'Food';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Row(
              children: List.generate(
                5,
                (index) => Icon(
                  index < rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(comment.isNotEmpty ? comment : 'No comment.'),
          ],
        ),
      ),
    );
  }
}
