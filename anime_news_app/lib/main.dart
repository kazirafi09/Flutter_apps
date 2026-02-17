import 'package:flutter/material.dart';
import 'package:anime_news_app/homepage.dart';

void main() {
  runApp(const MyApp());
}

/// Root of the application
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Anime News App',
      home: const MyHomePage(),
    );
  }
}
