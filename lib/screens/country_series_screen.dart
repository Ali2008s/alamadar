import 'package:flutter/material.dart';
import 'package:almadar/core/theme.dart';
import 'package:almadar/services/entertainment_service.dart';
import 'package:almadar/data/entertainment_models.dart';
import 'package:almadar/widgets/app_image.dart';

class CountrySeriesScreen extends StatelessWidget {
  final DramaCountry country;
  final EntertainmentService _service = EntertainmentService();

  CountrySeriesScreen({super.key, required this.country});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'مسلسلات ${country.name}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: FutureBuilder<List<DramaItem>>(
          future: _service.fetchSeriesByCountry(country.code),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text(
                  'لا توجد مسلسلات متاحة لهذه الدولة حالياً',
                  style: TextStyle(color: Colors.white54),
                ),
              );
            }

            final results = snapshot.data!;

            return GridView.builder(
              padding: const EdgeInsets.all(15),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.6,
                crossAxisSpacing: 10,
                mainAxisSpacing: 15,
              ),
              itemCount: results.length,
              itemBuilder: (context, index) {
                final item = results[index];
                return _buildItemCard(context, item);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, DramaItem item) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/series_details', arguments: item.id);
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AppImage(
                imageUrl: 'https://admin.dramaramadan.net${item.poster}',
                fit: BoxFit.cover,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              left: 6,
              right: 6,
              child: Text(
                item.title,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
