import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tapaolah/order_part/cart_page.dart';
import 'package:tapaolah/utilis/dimensions.dart';
import 'package:tapaolah/widgets/app_icon.dart';
import 'package:tapaolah/widgets/big_text.dart';
import 'package:tapaolah/widgets/exandable_text_widget.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class PopularFoodDetails extends StatefulWidget {
  final Map<String, dynamic> food;
  final String email;

  const PopularFoodDetails({
    super.key,
    required this.food,
    required this.email,
  });

  @override
  State<PopularFoodDetails> createState() => _PopularFoodDetailsState();
}

class _PopularFoodDetailsState extends State<PopularFoodDetails> {
  int quantity = 1;

  String userArea = 'Loading...';

  @override
  void initState() {
    super.initState();
  }

  Future<QuerySnapshot> fetchFoodReviews(String foodId) async {
    print('Fetching reviews for foodId: $foodId');

    try {
      final snap =
          await FirebaseFirestore.instance
              .collection('reviews')
              .where('type', isEqualTo: 'food')
              .where('foodId', isEqualTo: foodId)
              .orderBy('timestamp', descending: true)
              .get();

      print('Found ${snap.docs.length} reviews');
      return snap;
    } catch (e) {
      print('Error fetching reviews: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    final email = widget.email;

    String name = food['name'] ?? 'No name';
    String imageUrl = food['imageUrl'] ?? '';
    String description = food['description'] ?? 'No description';
    String foodId = food['id'] ?? '';
    double unitPrice = (food['price'] ?? 10).toDouble();
    double totalPrice = quantity * unitPrice;

    bool isAvailable = food['isAvailable'] == true;
    bool isRestaurantOpen = food['isRestaurantOpen'] == true;
    bool isDisabled = !(isAvailable && isRestaurantOpen);

    print('Full food data: ${widget.food}');
    print('isAvailable: $isAvailable');
    print('isRestaurantOpen: $isRestaurantOpen');
    print('isDisabled: $isDisabled');

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            child: Container(
              width: double.maxFinite,
              height: Dimensions.popularFoodImgSize,
              decoration: BoxDecoration(
                image: DecorationImage(
                  fit: BoxFit.cover,
                  image: NetworkImage(imageUrl),
                ),
              ),
            ),
          ),

          // Top Icons
          Positioned(
            top: Dimensions.height45,
            left: Dimensions.width20,
            right: Dimensions.width20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: AppIcon(
                    icon: Icons.arrow_back_ios,
                    backgroundColor: Colors.white,
                    iconColor: Colors.black,
                    size: 40,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CartPage(email: widget.email),
                      ),
                    );
                  },
                  child: AppIcon(
                    icon: Icons.shopping_cart_outlined,
                    backgroundColor: Colors.white,
                    iconColor: Colors.black,
                    size: 40,
                  ),
                ),
              ],
            ),
          ),

          // Details Content
          Positioned(
            left: 0,
            right: 0,
            top: Dimensions.popularFoodImgSize - 20,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: Dimensions.height20,
                left: Dimensions.width20,
                right: Dimensions.width20,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,

                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(Dimensions.radius20),
                  topRight: Radius.circular(Dimensions.radius20),
                ),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Add average rating and restaurant location here
                    SizedBox(height: Dimensions.height10),
                    BigText(
                      text: "Introduce",
                      size: 25,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                    ExpandableTextWidget(
                      text: description,
                      size: 15,
                      textColor: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                    SizedBox(height: Dimensions.height20),

                    Row(
                      children: [
                        Icon(Icons.fastfood, size: 25),
                        SizedBox(width: 6),
                        Text(
                          "Type: ${food['foodType'] ?? 'Unknown'}",
                          style: TextStyle(
                            fontSize: 17,
                            color:
                                Theme.of(context).textTheme.titleLarge?.color,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 25),
                        SizedBox(width: 6),
                        Text(
                          "Allergens: ${(food['allergens'] as List<dynamic>?)?.join(', ') ?? 'None'},",
                          style: TextStyle(fontSize: 17),
                        ),
                      ],
                    ),

                    FutureBuilder<QuerySnapshot>(
                      future: fetchFoodReviews(foodId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          print('Error: ${snapshot.error}');
                          return Text('Error: ${snapshot.error}');
                        }

                        final reviews = snapshot.data?.docs ?? [];
                        if (reviews.isEmpty) {
                          print('No reviews found for foodId: $foodId');
                          return const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text("No reviews yet for this food."),
                          );
                        }
                        double totalRating = 0;
                        for (var doc in reviews) {
                          final data = doc.data() as Map<String, dynamic>;
                          totalRating += (data['rating'] ?? 0).toDouble();
                        }
                        final averageRating = totalRating / reviews.length;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text(
                                  averageRating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text('(${reviews.length} reviews)'),
                              ],
                            ),
                            const SizedBox(height: 12),

                            BigText(
                              text: "Reviews",
                              color:
                                  Theme.of(context).textTheme.titleLarge?.color,
                            ),
                            Column(
                              children:
                                  reviews.map((doc) {
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundImage: NetworkImage(
                                          data['userProfileImage'] ??
                                              'https://ui-avatars.com/api/?name=User',
                                        ),
                                      ),
                                      title: Text(
                                        data['username'] ?? 'Anonymous',
                                        style: TextStyle(
                                          color:
                                              Theme.of(
                                                context,
                                              ).textTheme.titleLarge?.color,
                                        ),
                                      ),

                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          RatingBarIndicator(
                                            rating:
                                                (data['rating'] ?? 0)
                                                    .toDouble(),
                                            itemCount: 5,
                                            itemSize: 18,
                                            itemBuilder:
                                                (context, _) => const Icon(
                                                  Icons.star,
                                                  color: Colors.amber,
                                                ),
                                          ),
                                          Text(
                                            data['comment'] ?? '',
                                            style: TextStyle(
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).textTheme.titleLarge?.color,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // Bottom Bar
      // Bottom Bar
      bottomNavigationBar: Container(
        height: Dimensions.bottomHeightBar,
        padding: EdgeInsets.symmetric(
          horizontal: Dimensions.width20,
          vertical: Dimensions.height15,
        ),
        decoration: BoxDecoration(
          color: isDisabled ? Colors.grey.shade300 : Colors.grey.shade200,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(Dimensions.radius20),
            topRight: Radius.circular(Dimensions.radius20),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Quantity Controller
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: Dimensions.width20,
                vertical: Dimensions.height15,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Dimensions.radius20),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap:
                        isDisabled
                            ? null
                            : () {
                              setState(() {
                                if (quantity > 1) quantity--;
                              });
                            },
                    child: Icon(
                      Icons.remove,
                      color:
                          isDisabled
                              ? Colors.grey
                              : const Color.fromARGB(255, 136, 141, 85),
                      size: Dimensions.iconSize24,
                    ),
                  ),
                  SizedBox(width: Dimensions.width10),
                  BigText(text: quantity.toString()),
                  SizedBox(width: Dimensions.width10),
                  GestureDetector(
                    onTap:
                        isDisabled
                            ? null
                            : () {
                              setState(() {
                                quantity++;
                              });
                            },
                    child: Icon(
                      Icons.add,
                      color:
                          isDisabled
                              ? Colors.grey
                              : const Color.fromARGB(255, 136, 141, 85),
                      size: Dimensions.iconSize24,
                    ),
                  ),
                ],
              ),
            ),

            // Add to Cart Button
            GestureDetector(
              onTap:
                  isDisabled
                      ? null
                      : () async {
                        try {
                          double totalPrice = quantity * unitPrice;
                          String? restId = food['restaurantId'];

                          final restDoc =
                              await FirebaseFirestore.instance
                                  .collection('homeChefRegister')
                                  .doc(restId)
                                  .get();

                          if (!restDoc.exists) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Restaurant not found.')),
                            );
                            return;
                          }

                          final existingCartQuery =
                              await FirebaseFirestore.instance
                                  .collection('cart')
                                  .where('userEmail', isEqualTo: email)
                                  .where('foodId', isEqualTo: foodId)
                                  .limit(1)
                                  .get();

                          if (existingCartQuery.docs.isNotEmpty) {
                            final existingDoc = existingCartQuery.docs.first;
                            final existingData = existingDoc.data();
                            int existingQuantity =
                                existingData['quantity'] ?? 0;

                            int newQuantity = existingQuantity + quantity;
                            double newTotalPrice = newQuantity * unitPrice;

                            await FirebaseFirestore.instance
                                .collection('cart')
                                .doc(existingDoc.id)
                                .update({
                                  'quantity': newQuantity,
                                  'totalPrice': newTotalPrice,
                                  'addedAt': FieldValue.serverTimestamp(),
                                });

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Updated quantity for $name in cart!',
                                ),
                              ),
                            );
                          } else {
                            await FirebaseFirestore.instance
                                .collection('cart')
                                .add({
                                  'userEmail': email,
                                  'foodId': foodId,
                                  'name': name,
                                  'imageUrl': imageUrl,
                                  'price': unitPrice,
                                  'quantity': quantity,
                                  'totalPrice': totalPrice,
                                  'restId': restId,
                                  'addedAt': FieldValue.serverTimestamp(),
                                });

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$name added to cart!')),
                            );
                          }
                        } catch (e) {
                          print('❌ Error adding to cart: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to add to cart')),
                          );
                        }
                      },
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: Dimensions.width20,
                  vertical: Dimensions.height15,
                ),
                decoration: BoxDecoration(
                  color:
                      isDisabled
                          ? Colors.grey
                          : const Color.fromARGB(255, 149, 255, 100),
                  borderRadius: BorderRadius.circular(Dimensions.radius20),
                ),
                child: BigText(
                  text: "RM${totalPrice.toStringAsFixed(2)} | Add to cart",
                  color: Colors.black,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
