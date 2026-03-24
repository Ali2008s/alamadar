import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:almadar/services/data_service.dart';
import 'package:almadar/data/models.dart';
import 'package:almadar/core/theme.dart';
import 'package:almadar/widgets/app_image.dart';
import 'dart:ui';

class AllChannelsScreen extends StatefulWidget {
  const AllChannelsScreen({super.key});

  @override
  State<AllChannelsScreen> createState() => _AllChannelsScreenState();
}

class _AllChannelsScreenState extends State<AllChannelsScreen> {
  String _searchQuery = "";
  String? _selectedCategoryId = "all";
  bool _isSearching = false;

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<DataService>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          _buildBackgroundGlow(),
          CustomScrollView(
            slivers: [
              _buildAppBar(),
              _buildCategorySelector(dataService),
              _buildChannelsGrid(dataService),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundGlow() {
    return Positioned(
      top: -100,
      left: -50,
      child: Container(
        width: 300,
        height: 300,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.accentBlue.withOpacity(0.05),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
          child: Container(),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.background.withOpacity(0.9),
      title: _isSearching
          ? TextField(
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'ابحث عن قناة...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.white38),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            )
          : const Text(
              'عالمنا | القنوات',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(_isSearching ? Icons.close : Icons.search),
          onPressed: () => setState(() {
            _isSearching = !_isSearching;
            if (!_isSearching) _searchQuery = "";
          }),
        ),
      ],
    );
  }

  Widget _buildCategorySelector(DataService service) {
    return SliverToBoxAdapter(
      child: StreamBuilder<List<Category>>(
        stream: service.getCategories(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          final cats = snapshot.data!;

          return Container(
            height: 45,
            margin: const EdgeInsets.symmetric(vertical: 15),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              itemCount: cats.length + 1,
              itemBuilder: (context, index) {
                final bool isAll = index == 0;
                final String catId = isAll ? 'all' : cats[index - 1].id;
                final String catName = isAll ? 'الكل' : cats[index - 1].name;

                final isSelected = _selectedCategoryId == catId;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategoryId = catId),
                  child: Container(
                    margin: const EdgeInsets.only(left: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accentBlue
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.transparent : Colors.white10,
                      ),
                    ),
                    child: Text(
                      catName,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected ? Colors.white : Colors.white70,
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildChannelsGrid(DataService service) {
    return StreamBuilder<List<Channel>>(
      stream: service.getAllChannels(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          );
        final filteredChannels = snapshot.data!.where((Channel c) {
          final matchesSearch = c.name.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
          final matchesCategory =
              _selectedCategoryId == "all" ||
              c.categoryId == _selectedCategoryId;
          return matchesSearch && matchesCategory;
        }).toList();

        if (filteredChannels.isEmpty)
          return const SliverToBoxAdapter(
            child: Center(
              child: Text(
                'لا توجد قنوات تطابق البحث',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );

        return SliverPadding(
          padding: const EdgeInsets.all(15),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
              childAspectRatio: 1.3,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildChannelCard(filteredChannels[index]),
              childCount: filteredChannels.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildChannelCard(Channel channel) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        '/player',
        arguments: {'channel': channel, 'isLive': true},
      ),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: AppImage(imageUrl: channel.logoUrl, fit: BoxFit.contain),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            channel.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
