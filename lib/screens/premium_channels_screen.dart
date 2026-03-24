import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:almadar/services/premium_service.dart';
import 'package:almadar/core/theme.dart';
import 'package:almadar/data/models.dart';
import 'package:almadar/widgets/app_image.dart';
import 'package:almadar/widgets/tv_interactive.dart';
import 'package:almadar/screens/player_screen.dart';

class PremiumChannelsScreen extends StatelessWidget {
  final Category category;
  const PremiumChannelsScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final premiumService = Provider.of<PremiumService>(context, listen: false);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(category.name),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<List<Channel>>(
        future: premiumService.getChannelsByCategory(category.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final channels = snapshot.data ?? [];
          if (channels.isEmpty) {
            return const Center(
              child: Text(
                'لا توجد قنوات في هذا القسم',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(15),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
              childAspectRatio: 0.8,
            ),
            itemCount: channels.length,
            itemBuilder: (context, index) {
              final ch = channels[index];
              return _buildChannelCard(context, ch);
            },
          );
        },
      ),
    );
  }

  Widget _buildChannelCard(BuildContext context, Channel ch) {
    return TVInteractive(
      onTap: () async {
        final premiumService = Provider.of<PremiumService>(
          context,
          listen: false,
        );
        final fullChannel = await premiumService.getChannelDetails(ch.id);
        if (fullChannel != null && context.mounted) {
          // Pass the original name and logo from the list
          final channelToPlay = Channel(
            id: ch.id,
            name: ch.name,
            logoUrl: ch.logoUrl,
            categoryId: ch.categoryId,
            sources: fullChannel.sources,
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  PlayerScreen(channel: channelToPlay, isLive: true),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(15),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: AppImage(
                  imageUrl: ch.logoUrl,
                  fit: BoxFit.contain,
                  borderRadius: 10,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(15),
                ),
              ),
              child: Text(
                ch.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
