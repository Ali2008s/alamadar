import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:almadar/services/premium_service.dart';
import 'package:almadar/core/theme.dart';
import 'package:almadar/data/models.dart';
import 'package:almadar/widgets/app_image.dart';
import 'package:almadar/widgets/tv_interactive.dart';
import 'package:almadar/screens/premium_channels_screen.dart';
import 'package:almadar/widgets/gradient_text.dart';
import 'package:almadar/services/dynamic_api_service.dart';
import 'package:almadar/screens/dynamic_content_list_screen.dart';
import 'dart:ui';

class PremiumCategoriesScreen extends StatelessWidget {
  const PremiumCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final premiumService = Provider.of<PremiumService>(context, listen: false);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // 🎨 Glow Effects for Premium Look
            Positioned(
              top: -100,
              right: -50,
              child: _buildGlow(AppColors.accentBlue.withOpacity(0.15), 300),
            ),
            Positioned(
              bottom: -150,
              left: -100,
              child: _buildGlow(AppColors.accentPink.withOpacity(0.1), 350),
            ),

            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildModernAppBar(context),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  sliver: FutureBuilder<List<Category>>(
                    future: premiumService.getPremiumCategories(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SliverFillRemaining(
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.accentBlue,
                            ),
                          ),
                        );
                      }
                      final categories = snapshot.data ?? [];
                      if (categories.isEmpty) {
                        return const SliverFillRemaining(
                          child: Center(
                            child: Text(
                              'لا توجد أقسام حالياً',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        );
                      }

                      return SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 20,
                              crossAxisSpacing: 20,
                              childAspectRatio: 1.1,
                            ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final cat = categories[index];
                          return _buildCategoryCard(context, cat);
                        }, childCount: categories.length),
                      );
                    },
                  ),
                ),

                // --- Dynamic APIs (Our World Plus) ---
                StreamBuilder<List<DynamicApiSourceConfig>>(
                  stream: DynamicApiService().getActiveDynamicConfigs(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SliverToBoxAdapter(
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accentBlue,
                          ),
                        ),
                      );
                    }
                    final configs = snapshot.data ?? [];
                    if (configs.isEmpty)
                      return const SliverToBoxAdapter(child: SizedBox.shrink());

                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'باقات عالمنا بلس الإضافية',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 15),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 20,
                                    crossAxisSpacing: 20,
                                    childAspectRatio: 1.1,
                                  ),
                              itemCount: configs.length,
                              itemBuilder: (context, index) {
                                final config = configs[index];
                                return _buildDynamicCard(context, config);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 50),
                ), // bottom padding
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlow(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
        child: Container(),
      ),
    );
  }

  Widget _buildModernAppBar(BuildContext context) {
    return SliverAppBar(
      automaticallyImplyLeading: false,
      floating: true,
      pinned: true,
      expandedHeight: 120,
      backgroundColor: AppColors.background.withOpacity(0.8),
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Padding(
          padding: const EdgeInsets.fromLTRB(20, 50, 20, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const GradientText(
                    'عالمنا بلس',
                    gradient: AppColors.accentGradient,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    'المحتوى الحصري والمميز',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              TVInteractive(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, Category cat) {
    return TVInteractive(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PremiumChannelsScreen(category: cat)),
      ),
      borderRadius: BorderRadius.circular(25),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (cat.iconUrl.isNotEmpty)
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: 25,
                        left: 25,
                        right: 25,
                        bottom: 10,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accentBlue.withOpacity(0.2),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          AppImage(imageUrl: cat.iconUrl, fit: BoxFit.contain),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      cat.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicCard(
    BuildContext context,
    DynamicApiSourceConfig config,
  ) {
    IconData tabIcon = Icons.extension;
    if (config.tabIcon.toLowerCase() == 'movie') tabIcon = Icons.movie;
    if (config.tabIcon.toLowerCase() == 'tv') tabIcon = Icons.tv;
    if (config.tabIcon.toLowerCase() == 'sports') tabIcon = Icons.sports_soccer;

    Color cardColor = Colors.blue;
    try {
      cardColor = Color(
        int.parse(config.tabColorHex.replaceFirst('#', '0xFF')),
      );
    } catch (_) {}

    return TVInteractive(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DynamicContentListScreen(config: config),
        ),
      ),
      borderRadius: BorderRadius.circular(25),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: cardColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: cardColor.withOpacity(0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  flex: 3,
                  child: Center(
                    child: Icon(
                      tabIcon,
                      size: 60,
                      color: cardColor.withOpacity(0.8),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      config.tabName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
