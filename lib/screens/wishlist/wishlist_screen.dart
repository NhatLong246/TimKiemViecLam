import 'package:flutter/material.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          /// ===== HEADER =====
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
            color: Colors.blue,
            child: Column(
              children: [
                const Icon(
                  Icons.favorite_border,
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Wishlist',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Đăng nhập để xem danh sách yêu thích',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                /// ===== LOGIN BUTTON =====
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/login');
                    // nhớ map route này trong MaterialApp
                  },
                  child: const Text('Đăng nhập ngay'),
                ),
              ],
            ),
          ),

          /// ===== OPTIONAL TEXT =====
          Expanded(
            child: Center(
              child: Text(
                'Bạn chưa đăng nhập',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
