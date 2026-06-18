import 'package:flutter/material.dart';

import 'constants/app_constants.dart';
import 'screens/webview_screen.dart';

/// Main application widget
class AnimeWebViewApp extends StatelessWidget {
  const AnimeWebViewApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),
      ),
      home: const WebViewScreen(),
    );
  }
}
