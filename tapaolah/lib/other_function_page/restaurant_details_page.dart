import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tapaolah/home/food_details.dart';
import 'package:tapaolah/utilis/color.dart';
import 'package:tapaolah/widgets/big_text.dart';
import 'package:tapaolah/widgets/small_text.dart';

class RestaurantDetailsPage extends StatefulWidget {
  final String restaurantId;
  final String email;

  const RestaurantDetailsPage({
    super.key,
    required this.restaurantId,
    required this.email,
  });

  @override
  State<RestaurantDetailsPage> createState() => _RestaurantDetailsPageState();
}

class _RestaurantDetailsPageState extends State<RestaurantDetailsPage> {
  late Future<Map<String, dynamic>> _restaurantFuture;
  late Future<List<Map<String, dynamic>>> _menuItemsFuture;
  late Future<double> _averageRatingFuture;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _restaurantFuture = _fetchRestaurantDetails();
    _menuItemsFuture = _fetchMenuItems();
    _averageRatingFuture = _fetchAverageRating();
    _checkIfFavorite();
  }

  Future<Map<String, dynamic>> _fetchRestaurantDetails() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('homeChefRegister')
              .doc(widget.restaurantId)
              .get();

      if (!doc.exists) {
        throw Exception('Restaurant not found');
      }

      return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
    } catch (e) {
      debugPrint('Error fetching restaurant details: $e');
      throw e;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchMenuItems() async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('menuItems')
              .where('restaurantId', isEqualTo: widget.restaurantId)
              .where('isAvailable', isEqualTo: true)
              .get();

      return querySnapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();
    } catch (e) {
      debugPrint('Error fetching menu items: $e');
      return [];
    }
  }

  Future<double> _fetchAverageRating() async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('reviews')
              .where('restaurantId', isEqualTo: widget.restaurantId)
              .where('type', isEqualTo: 'restaurant')
              .get();

      if (querySnapshot.docs.isEmpty) return 0.0;

      double total = 0;
      for (var doc in querySnapshot.docs) {
        total += (doc['rating'] as num).toDouble();
      }

      return total / querySnapshot.docs.length;
    } catch (e) {
      debugPrint('Error fetching average rating: $e');
      return 0.0;
    }
  }

  Future<void> _checkIfFavorite() async {
    try {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.email)
              .get();

      if (userDoc.exists) {
        final favorites = List<String>.from(
          userDoc.data()?['favoriteRestaurants'] ?? [],
        );
        setState(() {
          _isFavorite = favorites.contains(widget.restaurantId);
        });
      }
    } catch (e) {
      debugPrint('Error checking favorite status: $e');
    }
  }

  Future<void> addToFavorite(
    String userEmail,
    Map<String, dynamic> restaurant,
  ) async {
    final favoriteRef = FirebaseFirestore.instance.collection(
      'favoriteRestaurants',
    );

    final existing =
        await favoriteRef
            .where('email', isEqualTo: userEmail)
            .where('restaurantId', isEqualTo: restaurant['id'])
            .get();

    if (existing.docs.isNotEmpty) {
      print('Already in favorite');
      return;
    }

    await favoriteRef.add({
      'email': userEmail,
      'restaurantName': restaurant['name'],
      'imageUrl': restaurant['logo'],
      'rating': restaurant['rating'] ?? 0,
      'location': restaurant['location'] ?? '',
      'restaurantId': restaurant['id'],
      'timestamp': FieldValue.serverTimestamp(),
    });

    print('Favorite added successfully');
  }

  Future<void> removeFromFavorite(String email, String restaurantId) async {
    final docRef = FirebaseFirestore.instance
        .collection('favoriteRestaurants')
        .doc(email)
        .collection('restaurants')
        .doc(restaurantId);

    await docRef.delete();
  }

  Widget _buildRatingStars(double rating) {
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 20,
        );
      }),
    );
  }

  Widget _buildMenuItem(Map<String, dynamic> item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => PopularFoodDetails(
                    food: {...item, 'restaurantId': widget.restaurantId},
                    email: widget.email,
                  ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Food Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child:
                    item['imageUrl'] != null
                        ? Image.network(
                          item['imageUrl'],
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey[200],
                              child: const Icon(Icons.fastfood),
                            );
                          },
                        )
                        : Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey[200],
                          child: const Icon(Icons.fastfood),
                        ),
              ),
              const SizedBox(width: 12),

              // Food Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Food Name
                    Text(
                      item['name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Description
                    Text(
                      item['description'] ?? 'No description available',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Price
                    Text(
                      "RM ${item['price']?.toStringAsFixed(2) ?? '0.00'}",
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: _restaurantFuture,
        builder: (context, restaurantSnapshot) {
          if (restaurantSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (restaurantSnapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load restaurant: ${restaurantSnapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _restaurantFuture = _fetchRestaurantDetails();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final restaurant = restaurantSnapshot.data!;

          return CustomScrollView(
            slivers: [
              // Restaurant Header (Image + Basic Info)
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Restaurant Image
                      restaurant['logo'] != null
                          ? Image.network(
                            restaurant['logo'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.restaurant,
                                  size: 100,
                                  color: Colors.white,
                                ),
                              );
                            },
                          )
                          : Container(
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.restaurant,
                              size: 100,
                              color: Colors.white,
                            ),
                          ),

                      // Gradient Overlay
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.7),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),

                      // Restaurant Info
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Restaurant Name
                            Text(
                              restaurant['name'],
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),

                            // Rating
                            FutureBuilder<double>(
                              future: _averageRatingFuture,
                              builder: (context, ratingSnapshot) {
                                final rating = ratingSnapshot.data ?? 0.0;
                                return Row(
                                  children: [
                                    _buildRatingStars(rating),
                                    const SizedBox(width: 8),
                                    Text(
                                      rating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  // Favorite Button
                  IconButton(
                    icon: Icon(
                      _isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: _isFavorite ? Colors.red : Colors.white,
                    ),
                    onPressed: () async {
                      if (_isFavorite) {
                        // 已收藏 → 移除
                        await removeFromFavorite(
                          widget.email,
                          restaurant['restaurantId'],
                        );
                      } else {
                        // 未收藏 → 添加
                        await addToFavorite(widget.email, restaurant);
                      }

                      // 状态更新
                      setState(() {
                        _isFavorite = !_isFavorite;
                      });
                    },
                  ),
                ],
              ),

              // Restaurant Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Description
                      Text(
                        restaurant['description'] ?? 'No description available',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[800],
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Address
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              restaurant['location'] ?? 'No address provided',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Menu Section Header
                      const Text(
                        'Menu',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Menu Items
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _menuItemsFuture,
                builder: (context, menuSnapshot) {
                  if (menuSnapshot.connectionState == ConnectionState.waiting) {
                    return const SliverToBoxAdapter(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (menuSnapshot.hasError || menuSnapshot.data!.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          menuSnapshot.hasError
                              ? 'Failed to load menu: ${menuSnapshot.error}'
                              : 'No menu items available',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final menuItems = menuSnapshot.data!;

                  return SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: _buildMenuItem(menuItems[index]),
                      );
                    }, childCount: menuItems.length),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
