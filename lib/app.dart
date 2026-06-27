import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'constants/app_constants.dart';
import 'screens/webview_screen.dart';

/// Main application widget
class WebSpaceApp extends StatelessWidget {
  const WebSpaceApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Royal Green color matching Honda Stylo
    const Color royalGreen = Color(0xFF1E4334);
    
    return MaterialApp(
      title: AppConstants.appTitle,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: royalGreen,
          brightness: Brightness.dark,
          primary: royalGreen,
          onPrimary: Colors.white,
          secondary: const Color(0xFFC0A062), // Elegant gold accent
          onSecondary: Colors.black,
          surface: const Color(0xFF121212),
          background: const Color(0xFF0A0A0A),
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
      ),
      home: const WebViewScreen(),
    );
  }
}
