import 'package:flutter/material.dart';

class ResponsiveHomePage extends StatelessWidget {
  const ResponsiveHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Responsive App'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600) {
            // Mobile-sized UI
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.phone_android, size: 80),
                  SizedBox(height: 20),
                  Text(
                    'This is the mobile layout!',
                    style: TextStyle(fontSize: 20),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {},
                    child: Text('Mobile Action'),
                  ),
                ],
              ),
            );
          } else {
            // Desktop/Tablet-sized UI
            return Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.desktop_windows, size: 120),
                        SizedBox(height: 20),
                        Text(
                          'Welcome to the desktop experience!',
                          style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'You have more space, so enjoy a richer UI.',
                          style: TextStyle(fontSize: 22),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () {},
                              child: Text('Desktop Option 1'),
                            ),
                            SizedBox(width: 20),
                            OutlinedButton(
                              onPressed: () {},
                              child: Text('Desktop Option 2'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}