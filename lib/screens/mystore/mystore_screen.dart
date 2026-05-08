import 'package:flutter/material.dart';

class MystoreScreen extends StatefulWidget {
  const MystoreScreen({super.key});

  @override
  State<MystoreScreen> createState() => _MystoreScreenState();
}

class _MystoreScreenState extends State<MystoreScreen> {
  int selectedCategoryIndex = 0;

  /// ===== MOCK DATA =====
  final List<String> categories = [
    "Tất cả",
    "Điện tử",
    "Thời trang",
    "Gia dụng",
    "Mỹ phẩm",
  ];
  final List<String> brands = ["Nike", "Adidas", "Apple", "Samsung"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),

      /// ===== APPBAR =====
      appBar: AppBar(
        title: const Text(
          "Cửa hàng của chúng tôi",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.search_rounded, color: Colors.black87),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),

      /// ===== BODY =====
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSectionTitle("Các thương hiệu nổi bật"),
          _buildFeaturedBrands(),
          _buildCategoryTabs(),
          _buildSectionTitle("Thương hiệu trong danh mục"),
          _buildBrandBanner(),
          _buildSectionTitle("Bạn có thể quan tâm"),
          _buildProductGrid(),
        ],
      ),
    );
  }

  /// ===== SECTION TITLE =====
  Widget _buildSectionTitle(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3142),
          ),
        ),
      ),
    );
  }

  /// ===== FEATURED BRANDS =====
  Widget _buildFeaturedBrands() {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 110,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          itemCount: brands.length,
          itemBuilder: (_, index) {
            return Container(
              width: 100,
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircleAvatar(backgroundColor: Colors.blue, radius: 20),
                  const SizedBox(height: 8),
                  Text(brands[index], style: const TextStyle(fontSize: 12)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// ===== CATEGORY TABS =====
  Widget _buildCategoryTabs() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverAppBarDelegate(
        minHeight: 70,
        maxHeight: 70,
        child: Container(
          color: const Color(0xFFF4F7FA),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: categories.length,
            itemBuilder: (_, index) {
              final isSelected = selectedCategoryIndex == index;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedCategoryIndex = index;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 12,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [Color(0xFF4960F9), Color(0xFF1937FE)],
                          )
                        : null,
                    color: isSelected ? null : Colors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: Text(
                      categories[index],
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.blueGrey,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// ===== BRAND BANNER =====
  Widget _buildBrandBanner() {
    return SliverToBoxAdapter(
      child: Column(
        children: brands.map((brand) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2D3142), Color(0xFF4F5D75)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.store, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    brand,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                ElevatedButton(onPressed: () {}, child: const Text("Theo dõi")),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// ===== PRODUCT GRID =====
  Widget _buildProductGrid() {
    return SliverPadding(
      padding: const EdgeInsets.all(20),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate((_, index) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    color: Colors.grey[300],
                    child: const Center(child: Text("Image")),
                  ),
                ),
                const SizedBox(height: 8),
                const Text("Product"),
                const SizedBox(height: 4),
                const Text("\$99"),
              ],
            ),
          );
        }, childCount: 6),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          mainAxisExtent: 280,
        ),
      ),
    );
  }
}

/// ===== STICKY HEADER =====
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _SliverAppBarDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(context, shrinkOffset, overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return true;
  }
}
