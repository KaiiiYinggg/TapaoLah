import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:tapaolah/order_part/order_history_page.dart';

class RatingReviewPage extends StatefulWidget {
  final String orderId;

  const RatingReviewPage({super.key, required this.orderId});

  @override
  State<RatingReviewPage> createState() => _RatingReviewPageState();
}

class _RatingReviewPageState extends State<RatingReviewPage> {
  bool isLoading = true;
  Map<String, dynamic>? orderData;
  List<String> uniqueFoodNames = [];
  Map<String, dynamic>? userData;

  double restaurantRating = 0;
  String restaurantComment = '';
  final Map<String, double> foodRatings = {};
  final Map<String, String> foodComments = {};

  String restaurantId = '';
  String userEmail = '';
  String userId = '';
  String userName = '';
  String username = '';
  String userProfileImage = 'userPlaceholder';

  List<Map<String, dynamic>> orderedItems = []; // ✅ 新增：包含 foodName 和 foodId

  @override
  void initState() {
    super.initState();
    _fetchOrderData();
  }

  Future<void> _fetchOrderData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .get()
          .timeout(const Duration(seconds: 10));

      if (!doc.exists || doc.data() == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Order not found')));
          Navigator.pop(context);
        }
        return;
      }

      orderData = doc.data();
      restaurantId = orderData?['restaurantId']?.toString() ?? '';
      userEmail = orderData?['userEmail']?.toString() ?? '';

      if (userEmail.isNotEmpty) {
        await _fetchUserData(userEmail);
      }

      final rawItems = orderData?['items'] as List<dynamic>?;

      if (rawItems == null || rawItems.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No items found in this order')),
          );
          Navigator.pop(context);
        }
        return;
      }

      final Set<String> foodNames = {};
      for (var item in rawItems) {
        final name = item['name']?.toString();
        final id = item['foodId']?.toString();
        if (name != null && name.isNotEmpty) {
          foodNames.add(name);
          orderedItems.add({'name': name, 'id': id}); // ✅ 存储 foodName 和 foodId
        }
      }

      uniqueFoodNames = foodNames.toList();

      if (mounted) setState(() => isLoading = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading order: $e')));
        Navigator.pop(context);
      }
    }
  }

  Future<void> _fetchUserData(String email) async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        userData = querySnapshot.docs.first.data();
        userId = userData?['userID'] ?? '';
        userName = userData?['fullName'] ?? '';
        username = userData?['username'] ?? '';
        userProfileImage = userData?['profileImage'] ?? 'userPlaceholder';

        if (mounted) setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading user data: $e')));
      }
    }
  }

  Future<void> _submitReviews() async {
    if (restaurantRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please rate the restaurant before submitting.'),
        ),
      );
      return;
    }

    final restName = orderData?['restaurant']?.toString() ?? 'unknown';

    try {
      final batch = FirebaseFirestore.instance.batch();

      // ✅ Restaurant Review
      final restReviewRef =
          FirebaseFirestore.instance.collection('reviews').doc();
      batch.set(restReviewRef, {
        'type': 'restaurant',
        'restId': restName,
        'restaurantId': restaurantId,
        'userEmail': userEmail,
        'userId': userId,
        'userName': userName,
        'username': username,
        'orderId': widget.orderId,
        'rating': restaurantRating,
        'comment': restaurantComment,
        'timestamp': Timestamp.now(),
        'userProfileImage': userProfileImage,
      });

      // ✅ Food Reviews
      for (var item in orderedItems) {
        final foodName = item['name'];
        final foodId = item['id'];
        final rating = foodRatings[foodName] ?? 0;
        final comment = foodComments[foodName] ?? '';

        if (rating > 0) {
          final foodReviewRef =
              FirebaseFirestore.instance.collection('reviews').doc();
          batch.set(foodReviewRef, {
            'type': 'food',
            'foodName': foodName,
            'foodId': foodId, // ✅ 正确 foodId
            'restId': restName,
            'restaurantId': restaurantId,
            'userEmail': userEmail,
            'userId': userId,
            'userName': userName,
            'username': username,
            'orderId': widget.orderId,
            'rating': rating,
            'comment': comment,
            'timestamp': Timestamp.now(),
            'userProfileImage': userProfileImage,
          });
        }
      }

      await batch.commit();

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({'isReviewed': true});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reviews submitted successfully.')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OrderHistoryPage(userEmail: userEmail),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error submitting reviews: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text("Loading your order... please wait"),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Your Order'),
        actions: [
          if (username.isNotEmpty || userName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text(
                  'Reviewing as: ${username.isNotEmpty ? username : userName}',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Restaurant Review',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              orderData?['restaurant']?.toString() ?? 'Unknown Restaurant',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              'Restaurant ID: $restaurantId',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            RatingBar.builder(
              initialRating: 0,
              minRating: 1,
              allowHalfRating: false,
              itemCount: 5,
              itemBuilder:
                  (context, _) => const Icon(Icons.star, color: Colors.amber),
              onRatingUpdate:
                  (rating) => setState(() => restaurantRating = rating),
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Comment (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              onChanged: (value) => restaurantComment = value,
            ),
            const SizedBox(height: 24),
            const Text(
              'Food Reviews',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (uniqueFoodNames.isEmpty)
              const Text('No food items available in this order.')
            else
              ...uniqueFoodNames.map((foodName) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Text(foodName, style: const TextStyle(fontSize: 16)),
                    RatingBar.builder(
                      initialRating: 0,
                      minRating: 1,
                      allowHalfRating: false,
                      itemCount: 5,
                      itemBuilder:
                          (context, _) =>
                              const Icon(Icons.star, color: Colors.amber),
                      onRatingUpdate:
                          (rating) => foodRatings[foodName] = rating,
                    ),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Comment (optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      onChanged: (value) => foodComments[foodName] = value,
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              }).toList(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _submitReviews,
                child: const Text(
                  'Submit All Reviews',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
