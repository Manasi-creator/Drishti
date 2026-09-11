import 'package:flutter/material.dart';
import 'services/api_service.dart';

void main() {
  runApp(const DrishtiApp());
}

class DrishtiApp extends StatelessWidget {
  const DrishtiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drishti',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Drishti'),
        ),
        body: Center(
          child: FutureBuilder<bool>(
            future: ApiService.checkHealth(),
            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }

              if (snapshot.hasError) {
                return Text(
                  'Backend connection failed:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                );
              }

              if (snapshot.data == true) {
                return const Text(
                  '✓ Connected to Drishti Backend',
                  style: TextStyle(fontSize: 24),
                );
              }

              return const Text(
                'Backend unavailable',
                style: TextStyle(fontSize: 24),
              );
            },
          ),
        ),
      ),
    );
  }
}