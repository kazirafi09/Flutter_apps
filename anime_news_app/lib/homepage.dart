import 'package:flutter/material.dart';

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(screenHeight * 0.15),
        child: AppBar(
          // 1. Use flexibleSpace to utilize the reserved height
          flexibleSpace: Container(
            // Use a Column here to stack elements vertically across the height
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end, // Align content to the bottom of the 18% space
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0), // Padding applied to the row container
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      // 1. Main Title
                      const Text(
                        'AniFeed',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      OutlinedButton(
                        onPressed: () {}, 
                        child: const Row(
                          mainAxisSize: MainAxisSize.min, 
                          children: [
                            Icon(Icons.logout, color: Colors.black),
                            SizedBox(width: 8), 
                            Text('Logout', style: TextStyle(color: Colors.black)),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                Text("This is where the search bar will go", style: TextStyle(fontSize: 16, color: Colors.black54)), // Placeholder for search bar
              ],
            ),
          ),
          
          // 2. Important: Remove the 'title' property or set it to empty, 
          // as flexibleSpace often overrides the layout of the standard 'title'.
          title: null, // Set title to null
          
          // Optional: Set elevation to 0 so the flexibleSpace background is visible
          elevation: 0, 
          backgroundColor: Colors.white, // Set a background color for the AppBar area
        ),
      ),
      
      body: Stack(
        children: [
          // ... (Rest of your body widget remains the same)
          Positioned.fill( 
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24), 
                  topRight: Radius.circular(24)
              ),
              child: Image.asset(
                'assets/img/anime_background.png', 
                fit: BoxFit.cover,
              ),
            ),
          ),

          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24), 
                  topRight: Radius.circular(24)
              ),
              child: Container(
                color: const Color(0x4D000000),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                child: const Text(
                  "Welcome to the Anime News App!", 
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}