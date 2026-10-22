// lib/home/search_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tapaolah/home/food_details.dart';
import 'package:tapaolah/other_function_page/restaurant_details_page.dart';

class SearchPage extends StatefulWidget {
  final String email;
  const SearchPage({super.key, required this.email});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String searchQuery = '';
  List<Map<String, dynamic>> searchResults = [];
  String? errorMessage;

  Future<double> _getAverageRating(String foodId) async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('reviews')
              .where('foodId', isEqualTo: foodId)
              .where('type', isEqualTo: 'food')
              .get();

      if (querySnapshot.docs.isEmpty) return 0.0;

      double total = 0;
      for (var doc in querySnapshot.docs) {
        total += (doc['rating'] as num).toDouble();
      }

      return total / querySnapshot.docs.length;
    } catch (e) {
      print('Error getting average rating for food $foodId: $e');
      return 0.0;
    }
  }

  void performSearch(String query) async {
    setState(() {
      searchQuery = query;
      errorMessage = null;
    });

    if (query.isEmpty) {
      setState(() {
        searchResults = [];
      });
      return;
    }

    List<Map<String, dynamic>> tempResults = [];
    final queryLower = query.toLowerCase();

    try {
      // 1. Search in menuItems
      final foodSnapshot =
          await FirebaseFirestore.instance
              .collection('menuItems')
              .where('isAvailable', isEqualTo: true)
              .get();

      for (var doc in foodSnapshot.docs) {
        try {
          final foodName = doc['name']?.toString().toLowerCase() ?? '';
          final foodType = doc['foodType']?.toString().toLowerCase() ?? '';

          if (foodName.contains(queryLower) || foodType.contains(queryLower)) {
            final restaurantId = doc['restaurantId'];
            if (restaurantId == null || restaurantId.isEmpty) continue;

            final restaurantDoc =
                await FirebaseFirestore.instance
                    .collection('homeChefRegister')
                    .doc(restaurantId)
                    .get();

            if (!restaurantDoc.exists) continue;

            // Get average rating
            final avgRating = await _getAverageRating(doc['id'] ?? doc.id);

            // Get description if available
            final description =
                doc['description'] ?? 'No description available';

            tempResults.add({
              'id': doc.id,
              'name': doc['name'] ?? 'No name',
              'imageUrl': doc['imageUrl'] ?? '',
              'price': (doc['price'] as num?)?.toDouble() ?? 0.0,
              'description': doc['description'] ?? 'No description',
              'foodType': doc['foodType'] ?? 'Unknown',
              'allergens': doc['allergens'] ?? [],
              'isAvailable': doc['isAvailable'] ?? true,
              'isRestaurantOpen': doc['isRestaurantOpen'] ?? true,
              'restaurantId': doc['restaurantId'] ?? '',
              'restaurantName': restaurantDoc['name'] ?? 'Unknown Restaurant',
              'rating': avgRating,
            });
          }
        } catch (e) {
          print('Error processing menu item: $e');
        }
      }

      // 2. Search in restaurants
      final restaurantSnapshot =
          await FirebaseFirestore.instance
              .collection('homeChefRegister')
              .where('name', isGreaterThanOrEqualTo: query)
              .where('name', isLessThan: query + 'z')
              .get();

      for (var restaurantDoc in restaurantSnapshot.docs) {
        try {
          final restaurantName =
              restaurantDoc['name']?.toString().toLowerCase() ?? '';
          final restaurantId = restaurantDoc.id;

          if (restaurantName.contains(queryLower)) {
            final menuItemsSnapshot =
                await FirebaseFirestore.instance
                    .collection('menuItems')
                    .where('restaurantId', isEqualTo: restaurantId)
                    .where('isAvailable', isEqualTo: true)
                    .get();

            for (var menuItem in menuItemsSnapshot.docs) {
              if (!tempResults.any((item) => item['id'] == menuItem.id)) {
                final avgRating = await _getAverageRating(
                  menuItem['id'] ?? menuItem.id,
                );
                final description =
                    menuItem['description'] ?? 'No description available';

                tempResults.add({
                  'id': menuItem.id,
                  'name': menuItem['name'],
                  'imageUrl': menuItem['imageUrl'],
                  'price': menuItem['price'],
                  'description': description,
                  'restaurantName': restaurantName,
                  'restaurantId': restaurantId,
                  'rating': avgRating,
                });
              }
            }
          }
        } catch (e) {
          print('Error processing restaurant: $e');
        }
      }

      setState(() {
        searchResults = tempResults;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Search failed: ${e.toString()}';
      });
    }
  }

  Widget _buildRatingStars(double rating) {
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 16,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Search"),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search field
            TextField(
              decoration: const InputDecoration(
                hintText: "Search by food or restaurant...",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                performSearch(value);
              },
            ),
            const SizedBox(height: 16),

            // Error message
            if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            // Search results
            Expanded(
              child:
                  searchResults.isEmpty
                      ? const Center(child: Text("No results found."))
                      : ListView.builder(
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          final item = searchResults[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => PopularFoodDetails(
                                        food: item,
                                        email: widget.email,
                                      ),
                                ),
                              );
                            },
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Restaurant name and arrow icon with clickable navigation
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) =>
                                                    RestaurantDetailsPage(
                                                      restaurantId:
                                                          item['restaurantId'],
                                                      email: widget.email,
                                                    ),
                                          ),
                                        );
                                      },
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            item['restaurantName'],
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const Icon(
                                            Icons.arrow_forward_ios,
                                            size: 16,
                                            color: Colors.grey,
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 8),

                                    // Food item row
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Food image
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child:
                                              item['imageUrl'] != null &&
                                                      item['imageUrl'] != ''
                                                  ? Image.network(
                                                    item['imageUrl'],
                                                    width: 80,
                                                    height: 80,
                                                    fit: BoxFit.cover,
                                                  )
                                                  : Container(
                                                    width: 80,
                                                    height: 80,
                                                    color: Colors.grey[200],
                                                    child: const Icon(
                                                      Icons.fastfood,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                        ),
                                        const SizedBox(width: 12),

                                        // Food details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Food name
                                              Text(
                                                item['name'],
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),

                                              const SizedBox(height: 4),

                                              // Rating stars and value
                                              Row(
                                                children: [
                                                  _buildRatingStars(
                                                    item['rating'] ?? 0,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '(${(item['rating'] ?? 0).toStringAsFixed(1)})',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ],
                                              ),

                                              const SizedBox(height: 4),

                                              // Price
                                              Text(
                                                "RM ${item['price'].toStringAsFixed(2)}",
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.orange,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
