import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tapaolah/home/home_page.dart';
import 'package:tapaolah/order_part/check_out_page.dart';
import 'package:tapaolah/widgets/big_text.dart';
import 'package:tapaolah/widgets/small_text.dart';

class CartPage extends StatefulWidget {
  final String email;
  const CartPage({super.key, required this.email});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  Stream<QuerySnapshot> get cartStream =>
      FirebaseFirestore.instance
          .collection('cart')
          .where('userEmail', isEqualTo: widget.email)
          .snapshots();

  Future<String> getRestaurantName(String restId) async {
    final doc =
        await FirebaseFirestore.instance
            .collection('homeChefRegister')
            .doc(restId)
            .get();
    return doc['name'] ?? 'Unknown Restaurant';
  }

  Future<Map<String, dynamic>> getRestaurantData(String restId) async {
    final doc =
        await FirebaseFirestore.instance
            .collection('homeChefRegister')
            .doc(restId)
            .get();
    return doc.data() ?? {};
  }

  Future<void> _removeFromCart(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('cart').doc(docId).delete();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to remove item: $e')));
    }
  }

  Future<void> _updateQuantity(
    String docId,
    int newQuantity,
    double price,
  ) async {
    if (newQuantity <= 0) {
      await _removeFromCart(docId);
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('cart').doc(docId).update({
        'quantity': newQuantity,
        'totalPrice': newQuantity * price,
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update quantity: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Cart"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
          color: Theme.of(context).textTheme.bodyMedium?.color,
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: cartStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          var items = snapshot.data?.docs ?? [];
          items.sort((a, b) {
            final aTime = a['addedAt'] as Timestamp? ?? Timestamp.now();
            final bTime = b['addedAt'] as Timestamp? ?? Timestamp.now();
            return bTime.compareTo(aTime);
          });

          final Map<String, List<DocumentSnapshot>> groupedItems = {};
          for (var item in items) {
            final restId = item['restId'] ?? 'Unknown';
            groupedItems.putIfAbsent(restId, () => []).add(item);
          }

          if (groupedItems.isEmpty) {
            return _buildEmptyCart();
          }

          return _buildCartList(groupedItems);
        },
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 20),
          const Text(
            "Your cart is empty",
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text("Click here to add food"),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => MainFoodPage(email: widget.email),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartList(Map<String, List<DocumentSnapshot>> groupedItems) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children:
          groupedItems.entries.map((entry) {
            final restId = entry.key;
            final items = entry.value;

            return FutureBuilder<Map<String, dynamic>>(
              future: getRestaurantData(restId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return SizedBox();

                final restData = snapshot.data!;
                final restName = restData['name'] ?? 'Unknown';
                final isRestaurantOpen = restData['isRestaurantOpen'] ?? false;

                final totalItems = items.fold<int>(
                  0,
                  (sum, item) => sum + ((item['quantity'] ?? 1) as int),
                );
                final totalPrice = items.fold<double>(
                  0,
                  (sum, item) => sum + (item['totalPrice'] ?? 0).toDouble(),
                );

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 餐厅头部
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  BigText(text: restName),
                                  SmallText(
                                    text:
                                        "$totalItems item(s) | RM ${totalPrice.toStringAsFixed(2)}",
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.arrow_forward_ios,
                                color:
                                    isRestaurantOpen
                                        ? Colors.black
                                        : Colors.grey,
                              ),
                              onPressed:
                                  isRestaurantOpen
                                      ? () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) => CheckoutPage(
                                                  restaurantName: restName,
                                                  restaurantId: restId,
                                                  items: items,
                                                  totalPrice: totalPrice,
                                                  userEmail: widget.email,
                                                ),
                                          ),
                                        );
                                      }
                                      : null,
                            ),
                          ],
                        ),
                      ),

                      // 菜品列表
                      ...items.map((item) {
                        final data = item.data() as Map<String, dynamic>;
                        final quantity = data['quantity'] ?? 1;
                        final price = data['price'] ?? 0;

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              // 菜品图片
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child:
                                    data['imageUrl'] != null
                                        ? Image.network(
                                          data['imageUrl'],
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                        )
                                        : Container(
                                          width: 60,
                                          height: 60,
                                          color: Colors.grey[200],
                                          child: const Icon(Icons.fastfood),
                                        ),
                              ),
                              const SizedBox(width: 12),

                              // 菜品信息
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['name'] ?? 'No name',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      "RM ${(data['totalPrice'] ?? 0).toStringAsFixed(2)}",
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),

                              // 数量控制
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove),
                                    onPressed:
                                        () => _updateQuantity(
                                          item.id,
                                          quantity - 1,
                                          price.toDouble(),
                                        ),
                                  ),
                                  Text(quantity.toString()),
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed:
                                        () => _updateQuantity(
                                          item.id,
                                          quantity + 1,
                                          price.toDouble(),
                                        ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _removeFromCart(item.id),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                );
              },
            );
          }).toList(),
    );
  }
}
