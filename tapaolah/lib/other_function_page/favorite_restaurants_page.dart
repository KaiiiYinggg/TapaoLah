import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tapaolah/other_function_page/restaurant_details_page.dart';

class FavoriteRestaurantsPage extends StatelessWidget {
  final String email;

  const FavoriteRestaurantsPage({super.key, required this.email});

  Future<List<Map<String, dynamic>>> _fetchFavorites() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('favoriteRestaurants')
              .where('email', isEqualTo: email)
              .orderBy('timestamp', descending: true)
              .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('Error fetching favorites: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorite Restaurants'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchFavorites(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                snapshot.hasError
                    ? 'Error loading favorites'
                    : 'No favorite restaurants found.',
                style: const TextStyle(fontSize: 16),
              ),
            );
          }

          final favorites = snapshot.data!;

          return ListView.builder(
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final restaurant = favorites[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child:
                        restaurant['imageUrl'] != null &&
                                restaurant['imageUrl'] != ''
                            ? Image.network(
                              restaurant['imageUrl'],
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            )
                            : Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey[300],
                              child: const Icon(Icons.restaurant),
                            ),
                  ),
                  title: Text(
                    restaurant['restaurantName'] ?? 'No name',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (restaurant['location'] != null &&
                          restaurant['location'] != '')
                        Text(restaurant['location']),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: const Text('Remove Favorite'),
                              content: const Text(
                                'Are you sure you want to remove this restaurant from favorites?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed:
                                      () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Remove'),
                                ),
                              ],
                            ),
                      );

                      if (confirm == true) {
                        try {
                          final query =
                              await FirebaseFirestore.instance
                                  .collection('favoriteRestaurants')
                                  .where('email', isEqualTo: email)
                                  .where(
                                    'restaurantId',
                                    isEqualTo: restaurant['restaurantId'],
                                  )
                                  .get();

                          for (final doc in query.docs) {
                            await doc.reference.delete();
                          }

                          // 重新渲染页面，StatelessWidget 临时方式
                          (context as Element).reassemble();
                        } catch (e) {
                          debugPrint('Failed to remove: $e');
                        }
                      }
                    },
                  ),
                  onTap: () {
                    if (restaurant['restaurantId'] != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => RestaurantDetailsPage(
                                restaurantId: restaurant['restaurantId'],
                                email: email,
                              ),
                        ),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
