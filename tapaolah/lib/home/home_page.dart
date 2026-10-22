import 'package:flutter/material.dart';
import 'package:tapaolah/home/topup.dart';
import 'package:tapaolah/other_function_page/favorite_restaurants_page.dart';
import 'package:tapaolah/other_function_page/info_page.dart';
import 'package:tapaolah/other_function_page/search_page.dart';
import 'package:tapaolah/utilis/color.dart';
import 'package:tapaolah/home/food_page_body.dart';
import 'package:tapaolah/utilis/navigation_bar.dart';
import 'package:tapaolah/order_part/cart_page.dart';
import 'package:tapaolah/order_part/order_history_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MainFoodPage extends StatefulWidget {
  final String email;
  const MainFoodPage({super.key, required this.email});

  @override
  State<MainFoodPage> createState() => _MainFoodPageState();
}

class _MainFoodPageState extends State<MainFoodPage> {
  int _selectedIndex = 0;
  String? _selectedFilter;
  List<String> _foodTypes = [];
  bool _isLoadingFoodTypes = true;
  String? _userAddress;
  bool _isLoadingAddress = true;

  @override
  void initState() {
    super.initState();
    _fetchFoodTypes();
    _checkPromo();
    _fetchLatestOrderAddress();
  }

  Future<void> _checkPromo() async {
    final now = Timestamp.now();

    final query =
        await FirebaseFirestore.instance
            .collection('promoCodes')
            .where('validUntil', isGreaterThan: now)
            .get();

    if (query.docs.isNotEmpty) {
      final promo = query.docs.first.data();

      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: const Text("🎉 New Promo!"),
              content: Text(
                "${promo['description']}\nUse Code: ${promo['code']}",
              ),
              actions: [
                TextButton(
                  child: const Text("Got it"),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
      );
    }
  }

  Future<void> _fetchLatestOrderAddress() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('orderInfo')
              .doc(widget.email)
              .get();

      if (doc.exists && doc.data()!.containsKey('latest')) {
        final data = doc.data()!;
        setState(() {
          _userAddress = data['latest']['address'] ?? "No Address";
        });
      } else {
        setState(() {
          _userAddress = "No Address";
        });
      }
    } catch (e) {
      setState(() {
        _userAddress = "Failed to load";
      });
    } finally {
      setState(() {
        _isLoadingAddress = false;
      });
    }
  }

  Future<void> _fetchFoodTypes() async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('menuItems')
              .where('isAvailable', isEqualTo: true)
              .get();

      final types =
          querySnapshot.docs
              .map((doc) => doc.data()['foodType'] as String?)
              .where((type) => type != null && type.isNotEmpty)
              .toSet()
              .toList();

      types.sort();

      setState(() {
        _foodTypes = types.cast<String>();
        _isLoadingFoodTypes = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingFoodTypes = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load food types: $e')));
    }
  }

  Future<int> _getCartItemCount() async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('cart')
            .where('email', isEqualTo: widget.email)
            .get();
    return snapshot.docs.length;
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);

    if (index == 0) return;

    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TopUpPage(email: widget.email)),
      );
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => InfoPage(email: widget.email)),
      );
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Filter by Cuisine'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFilterOption(null, 'All Cuisines'),
                    const Divider(),
                    ..._foodTypes.map((type) => _buildFilterOption(type, type)),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFilterOption(String? value, String title) {
    return ListTile(
      title: Text(title),
      leading: Radio<String?>(
        value: value,
        groupValue: _selectedFilter,
        onChanged: (String? newValue) {
          setState(() {
            _selectedFilter = newValue;
          });
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _clearFilter() {
    setState(() {
      _selectedFilter = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // Top bar
              Container(
                margin: const EdgeInsets.only(top: 45, bottom: 15),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () {
                        // 点击 logo 可以执行的动作，例如跳转或弹窗
                        print("Logo tapped!");
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Image.asset(
                            'assets/logo1.png',
                            width: 100,
                            height: 100,
                            fit: BoxFit.contain,
                          ),
                        ],
                      ),
                    ),

                    // Right buttons
                    Row(
                      children: [
                        // Filter
                        Stack(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.filter_alt,
                                color: Theme.of(context).iconTheme.color,
                              ),
                              onPressed:
                                  _isLoadingFoodTypes
                                      ? null
                                      : _showFilterDialog,
                              tooltip: 'Filter by cuisine',
                              style: IconButton.styleFrom(
                                side:
                                    _selectedFilter != null
                                        ? BorderSide(
                                          color: AppColors.lightBackground,
                                          width: 1,
                                        )
                                        : null,
                              ),
                            ),
                            if (_selectedFilter != null)
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 12,
                                    minHeight: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 8),

                        // Search
                        IconButton(
                          icon: Icon(
                            Icons.search,
                            color: Theme.of(context).iconTheme.color,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SearchPage(email: widget.email),
                              ),
                            );
                          },
                          tooltip: 'Search food',
                          style: IconButton.styleFrom(),
                        ),
                        const SizedBox(width: 8),

                        // Favorites
                        IconButton(
                          icon: Icon(
                            Icons.favorite,
                            color: Theme.of(context).iconTheme.color,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => FavoriteRestaurantsPage(
                                      email: widget.email,
                                    ),
                              ),
                            );
                          },
                          tooltip: 'Favorite restaurants',
                          style: IconButton.styleFrom(),
                        ),
                        const SizedBox(width: 8),

                        // Order History
                        IconButton(
                          icon: Icon(
                            Icons.receipt_long,
                            color: Theme.of(context).iconTheme.color,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => OrderHistoryPage(
                                      userEmail: widget.email,
                                    ),
                              ),
                            );
                          },
                          tooltip: 'Order history',
                          style: IconButton.styleFrom(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Filter chip
              if (_selectedFilter != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Chip(
                        label: Text('Showing: $_selectedFilter'),
                        backgroundColor: const Color.fromARGB(
                          255,
                          72,
                          255,
                          0,
                        ).withOpacity(0.2),
                        deleteIcon: Icon(
                          Icons.close,
                          size: 18,
                          color: Theme.of(context).iconTheme.color,
                        ),
                        onDeleted: _clearFilter,
                      ),
                    ],
                  ),
                ),

              // Main food content
              Expanded(
                child: FoodPageBody(
                  filter: _selectedFilter,
                  email: widget.email,
                ),
              ),
            ],
          ),

          // 🛒 Floating cart in bottom right
          Positioned(
            bottom: 20,
            right: 20,
            child: FutureBuilder<int>(
              future: _getCartItemCount(),
              builder: (context, snapshot) {
                int itemCount = snapshot.data ?? 0;
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CartPage(email: widget.email),
                      ),
                    );
                  },
                  child: Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.shopping_cart,
                          color: Theme.of(context).iconTheme.color,
                          size: 28,
                        ),
                      ),
                      if (itemCount > 0)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$itemCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
