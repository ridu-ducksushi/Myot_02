import 'package:flutter/material.dart';

class PetsPlaceholder extends StatelessWidget {
  const PetsPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pets')),
      body: const Center(child: Text('Pets Screen - Coming Soon')),
    );
  }
}
