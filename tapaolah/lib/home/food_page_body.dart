import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dots_indicator/dots_indicator.dart';
import 'package:flutter/material.dart';
import 'package:tapaolah/home/food_details.dart';
import 'package:tapaolah/utilis/color.dart';
import 'package:tapaolah/utilis/dimensions.dart';
import 'package:tapaolah/widgets/big_text.dart';
import 'package:tapaolah/widgets/icon_and_text.dart';
import 'package:tapaolah/widgets/small_text.dart';

class FoodPageBody extends StatefulWidget {
  final String? filter;
  final String email;
  const FoodPageBody({super.key, this.filter, required this.email});

  @override
  State<FoodPageBody> createState() => _FoodPageBodyState();
}

class _FoodPageBodyState extends State<FoodPageBody> {
  late PageController _pageController;
  double _currPageValue = 0.0;
  double _scaleFactor = 0.8;
  double _height = Dimensions.pageViewContainer;
  late Future<List<Map<String, dynamic>>> _top5FoodsFuture;
  late Future<List<Map<String, dynamic>>> _topRatedFoodsFuture;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
    _pageController.addListener(() {
      setState(() {
        _currPageValue = _pageController.page!;
      });
    });

    _top5FoodsFuture = _getTop5Foods();
    _topRatedFoodsFuture = _getTopRatedFoods();
  }

  @override
  void didUpdateWidget(FoodPageBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter != widget.filter) {
      setState(() {});
    }
  }

  Query _getFeaturedItemsQuery() {
    return FirebaseFirestore.instance
        .collection('menuItems')
        .where('isAvailable', isEqualTo: true)
        .limit(5);
  }

  Query _getFilteredItemsQuery() {
    var query = FirebaseFirestore.instance
        .collection('menuItems')
        .where('isAvailable', isEqualTo: true);

    if (widget.filter != null && widget.filter!.isNotEmpty) {
      query = query.where('foodType', isEqualTo: widget.filter);
    }
    return query;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _getTopRatedFoods() async {
    try {
      // 创建基础查询
      var query = FirebaseFirestore.instance
          .collection('menuItems')
          .where('isAvailable', isEqualTo: true);

      // 如果有 filter，则加入 foodType 筛选条件
      if (widget.filter != null && widget.filter!.isNotEmpty) {
        query = query.where('foodType', isEqualTo: widget.filter);
      }

      final foodSnapshot = await query.get();
      List<Map<String, dynamic>> foodList = [];

      for (var doc in foodSnapshot.docs) {
        final food = doc.data();
        final foodId = doc.id;

        final reviewSnapshot =
            await FirebaseFirestore.instance
                .collection('reviews')
                .where('foodId', isEqualTo: foodId)
                .where('type', isEqualTo: 'food')
                .get();

        if (reviewSnapshot.docs.isEmpty) continue;

        double totalRating = 0;
        int count = 0;

        for (var review in reviewSnapshot.docs) {
          totalRating += (review['rating'] as num).toDouble();
          count++;
        }

        double avgRating = totalRating / count;

        foodList.add({
          ...food,
          'id': foodId,
          'isAvailable': food['isAvailable'] ?? true,
          'isRestaurantOpen': food['isRestaurantOpen'] ?? true,
          'avgRating': avgRating,
          'ratingCount': count,
        });
      }

      // 按 avgRating 排序，取前 20 个
      foodList.sort(
        (a, b) =>
            (b['avgRating'] as double).compareTo(a['avgRating'] as double),
      );

      return foodList.take(20).toList();
    } catch (e) {
      print('Error in _getTopRatedFoods: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getTop5Foods() async {
    final foodSnapshot =
        await FirebaseFirestore.instance
            .collection('menuItems')
            .where('isAvailable', isEqualTo: true)
            .get();

    List<Map<String, dynamic>> foodList = [];

    for (var doc in foodSnapshot.docs) {
      final food = doc.data();
      final foodId = doc.id;

      final reviewSnapshot =
          await FirebaseFirestore.instance
              .collection('reviews')
              .where('foodId', isEqualTo: foodId)
              .where('type', isEqualTo: 'food')
              .get();

      if (reviewSnapshot.docs.isEmpty) continue;

      double totalRating = 0;
      int count = 0;

      for (var review in reviewSnapshot.docs) {
        totalRating += (review['rating'] as num).toDouble();
        count++;
      }

      double avgRating = totalRating / count;

      foodList.add({
        ...food,
        'id': foodId,
        'isAvailable': food['isAvailable'] ?? true,
        'isRestaurantOpen': food['isRestaurantOpen'] ?? true,
        'avgRating': avgRating,
        'ratingCount': count,
      });
    }

    foodList.sort(
      (a, b) => (b['avgRating'] as double).compareTo(a['avgRating'] as double),
    );
    return foodList.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: Dimensions.pageView + Dimensions.height10 + 30,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _top5FoodsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No top rated items.'));
                }

                final items = snapshot.data!;
                final itemCount = items.length;

                return Column(
                  children: [
                    SizedBox(
                      height: Dimensions.pageView,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: itemCount,
                        itemBuilder: (context, index) {
                          final food = items[index];
                          return _buildPageItem(food, index);
                        },
                      ),
                    ),
                    SizedBox(height: Dimensions.height10),
                    if (itemCount > 0)
                      DotsIndicator(
                        dotsCount: itemCount,
                        position: _currPageValue.clamp(0, itemCount - 1),
                        decorator: DotsDecorator(
                          activeColor: AppColors.lightBackground,
                          size: const Size.square(9.0),
                          activeSize: const Size(18.0, 9.0),
                          activeShape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5.0),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),

          Padding(
            padding: EdgeInsets.only(
              left: Dimensions.width30,
              top: Dimensions.height20,
            ),
            child: Row(
              children: [
                BigText(
                  text: "Popular Food",
                  color: Theme.of(context).textTheme.titleLarge?.color,
                  size: 20,
                ),
                SizedBox(width: Dimensions.width10),
              ],
            ),
          ),

          FutureBuilder<List<Map<String, dynamic>>>(
            future: _getTopRatedFoods(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Padding(
                  padding: EdgeInsets.all(Dimensions.height20),
                  child: Center(child: Text("No popular food found")),
                );
              }

              final topFoods = snapshot.data!;

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: topFoods.length,
                itemBuilder: (context, index) {
                  final food = topFoods[index];
                  return _buildFoodItem(food);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFoodItem(Map<String, dynamic> food) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PopularFoodDetails(food: food, email: widget.email),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: Dimensions.width20,
          vertical: Dimensions.height10,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(Dimensions.radius20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: Dimensions.listViewImgSize,
              height: Dimensions.listViewImgSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Dimensions.radius20),
                image: DecorationImage(
                  image: NetworkImage(
                    (food['imageUrl'] ?? '').replaceAll(
                      '.firebasestorage.app',
                      '.appspot.com',
                    ),
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(Dimensions.height10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BigText(
                      text: food['name'] ?? 'No Name',
                      size: 18,
                      overflow: TextOverflow.ellipsis,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    SizedBox(height: Dimensions.height10 / 2),
                    SizedBox(height: Dimensions.height10 / 2),
                    Row(
                      children: [
                        IconAndTextWidget(
                          icon: Icons.food_bank,
                          text: food['foodType']?.toString() ?? '',
                          iconColor: Colors.orangeAccent,
                          color:
                              Theme.of(context).textTheme.bodyMedium?.color ??
                              Colors.black,
                          textSize: 14,
                        ),

                        SizedBox(width: 10),
                        IconAndTextWidget(
                          icon: Icons.list_alt,
                          text:
                              (food['allergens'] as List<dynamic>?)?.join(
                                ', ',
                              ) ??
                              'No allergens',
                          iconColor: Colors.red,
                          color:
                              Theme.of(context).textTheme.bodyMedium?.color ??
                              Colors.black,
                          textSize: 14,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageItem(Map<String, dynamic> food, int index) {
    Matrix4 matrix = Matrix4.identity();
    double currScale = 1.0;
    double currTrans = 0.0;

    if (index == _currPageValue.floor()) {
      currScale = 1 - (_currPageValue - index) * (1 - _scaleFactor);
      currTrans = _height * (1 - currScale) / 2;
      matrix = Matrix4.diagonal3Values(1, currScale, 1)
        ..setTranslationRaw(0, currTrans, 0);
    } else {
      currScale = _scaleFactor;
      matrix = Matrix4.diagonal3Values(1, currScale, 1)
        ..setTranslationRaw(0, _height * (1 - _scaleFactor) / 2, 0);
    }

    return Transform(
      transform: matrix,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => PopularFoodDetails(food: food, email: widget.email),
            ),
          );
        },
        child: Stack(
          children: [
            Container(
              height: Dimensions.pageViewContainer,
              margin: EdgeInsets.symmetric(horizontal: Dimensions.width10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Dimensions.radius30),
                image: DecorationImage(
                  image: NetworkImage(
                    (food['imageUrl'] ?? '').replaceAll(
                      '.firebasestorage.app',
                      '.appspot.com',
                    ),
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: Dimensions.pageViewTextContainer,
                margin: EdgeInsets.only(
                  left: Dimensions.width20,
                  right: Dimensions.width20,
                  bottom: Dimensions.height20,
                ),
                padding: EdgeInsets.all(Dimensions.height10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Dimensions.radius20),
                  color: Theme.of(context).cardTheme.color,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BigText(
                      text: food['name'] ?? "No name",
                      size: 18,
                      color:
                          Theme.of(context).textTheme.bodyMedium?.color ??
                          Colors.black,
                    ),
                    SizedBox(height: Dimensions.height10 / 2),
                    StreamBuilder<QuerySnapshot>(
                      stream:
                          FirebaseFirestore.instance
                              .collection('reviews')
                              .where('type', isEqualTo: 'food')
                              .where('foodName', isEqualTo: food['name'])
                              .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          final reviews = snapshot.data!.docs;
                          final totalRating = reviews.fold<double>(
                            0,
                            (sum, doc) =>
                                sum + (doc['rating'] as num).toDouble(),
                          );
                          final avgRating = (totalRating / reviews.length)
                              .toStringAsFixed(1);
                          return Row(children: [SizedBox(width: 5)]);
                        }

                        final reviews = snapshot.data!.docs;
                        final totalRating = reviews.fold<double>(
                          0,
                          (sum, doc) => sum + (doc['rating'] as num).toDouble(),
                        );
                        final avgRating = (totalRating / reviews.length)
                            .toStringAsFixed(1);

                        return Row(
                          children: [
                            IconAndTextWidget(
                              icon: Icons.star,
                              text: avgRating,
                              iconColor: Colors.yellow,
                              color:
                                  Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.color ??
                                  Colors.black,
                              textSize: 15,
                            ),
                            SizedBox(width: 5),
                          ],
                        );
                      },
                    ),
                    SizedBox(height: Dimensions.height10 / 2),
                    Row(
                      children: [
                        IconAndTextWidget(
                          icon: Icons.food_bank,
                          text: food['foodType'] ?? '',
                          iconColor: Colors.orangeAccent,
                          color:
                              Theme.of(context).textTheme.bodyMedium?.color ??
                              Colors.black,
                          textSize: 14,
                        ),
                        SizedBox(width: 10),
                        IconAndTextWidget(
                          icon: Icons.list_alt,
                          text:
                              (food['allergens'] as List<dynamic>?)?.join(
                                ', ',
                              ) ??
                              'No allergens',
                          iconColor: Colors.red,
                          color:
                              Theme.of(context).textTheme.bodyMedium?.color ??
                              Colors.black,
                          textSize: 14,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
