import 'package:flutter/material.dart';

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(screenHeight * 0.18),
        child: AppBar(
          title: Text('Anime News App'),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Colors.brown[200],
            padding: const EdgeInsets.all(16.0),
            child: Text('Welcome to Anime News App', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),),
          ),
          Container(
            color: Colors.brown[100],
            padding: const EdgeInsets.all(16.0), 
            child: Text('Latest news will be displayed here', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),),
          ),
        ]
        
      )
    );
  }
}