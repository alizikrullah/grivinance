import 'package:flutter/material.dart';

class GriviBottomNav extends StatelessWidget {
  const GriviBottomNav({super.key, required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: index,
      onTap: onChanged,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Beranda'),
        BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), label: 'Transaksi'),
        BottomNavigationBarItem(icon: Icon(Icons.pie_chart_outline), label: 'Grafik'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Akun'),
      ],
    );
  }
}
