// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:provider/provider.dart';
// import 'package:tapaolah/home/home_page.dart';
// import 'package:tapaolah/home/topup.dart';
// import 'package:tapaolah/order_part/order_history_page.dart';
// import 'package:tapaolah/order_part/cart_page.dart';
// import 'package:tapaolah/other_function_page/info_page.dart';
// import 'package:tapaolah/other_function_page/map_search_page.dart';
// import 'package:tapaolah/other_function_page/review_rating.dart';
// import 'package:tapaolah/other_function_page/select_review_page.dart';
// import 'package:tapaolah/promocode.dart';
// import 'package:tapaolah/utilis/color.dart';
// import 'package:tapaolah/utilis/theme_notifier.dart';
// import 'firebase_options.dart';

// // ✅ 全局测试用 email（以后 login 成功后你就可以动态改它）
// String email = 'lilyyyyy2451@gmail.com';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

//   runApp(
//     ChangeNotifierProvider(
//       create: (_) => ThemeNotifier(),
//       child: const MyApp(),
//     ),
//   );
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Firebase Firestore Test',

//       theme: ThemeData(primarySwatch: Colors.teal),
//       //home: AddPromoCodePage(),
//       home: MainFoodPage(email: email),
//       //home: MapSearchPage(),
//       // home: CartPage(email: email),
//       //home: InfoPage(email: email),
//       // home: SelectOrderToReviewPage(userEmail: email),
//       //home: TopUpPage(email: email),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:tapaolah/home/home_page.dart';
import 'package:tapaolah/home/topup.dart';
import 'package:tapaolah/order_part/order_history_page.dart';
import 'package:tapaolah/order_part/cart_page.dart';
import 'package:tapaolah/other_function_page/info_page.dart';
import 'package:tapaolah/other_function_page/review_rating.dart';
import 'package:tapaolah/other_function_page/select_review_page.dart';
import 'package:tapaolah/promocode.dart';
import 'package:tapaolah/utilis/theme_notifier.dart';
import 'package:tapaolah/utilis/app_theme.dart'; // 你写 theme 的文件
import 'firebase_options.dart';

// ✅ 测试用 email
String email = 'ongcustong@gmail.com';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeNotifier(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return MaterialApp(
      title: 'TapPaoLah',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeNotifier.isDark ? ThemeMode.dark : ThemeMode.light,

      // ✅ 根据你测试哪个页面，改这里就好
      home: MainFoodPage(email: email),
      // home: AddPromoCodePage(),
      // home: MapSearchPage(),
      // home: CartPage(email: email),
      // home: InfoPage(email: email),
      // home: SelectOrderToReviewPage(userEmail: email),
      // home: TopUpPage(email: email),
    );
  }
}
