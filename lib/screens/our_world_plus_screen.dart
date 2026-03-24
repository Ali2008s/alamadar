import 'package:flutter/material.dart';
import 'package:almadar/services/dynamic_api_service.dart';
import 'package:almadar/data/models.dart';
import 'package:almadar/screens/dynamic_content_list_screen.dart';

class OurWorldPlusScreen extends StatelessWidget {
  const OurWorldPlusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = DynamicApiService();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'عالمنا بلص 🚀',
          style: TextStyle(fontFamily: 'AppFont', fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<List<DynamicApiSourceConfig>>(
            stream: service.getActiveDynamicConfigs(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final configs = snapshot.data ?? [];

              if (configs.isEmpty) {
                return const Center(
                  child: Text(
                    'لا توجد باقات متاحة حالياً',
                    style: TextStyle(fontFamily: 'AppFont', color: Colors.white, fontSize: 18),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: configs.length,
                itemBuilder: (context, index) {
                  final config = configs[index];
                  // Parse hex color or default to blue
                  Color cardColor = Colors.blue;
                  try {
                    cardColor = Color(
                      int.parse(config.tabColorHex.replaceFirst('#', '0xFF')),
                    );
                  } catch (e) {
                    // Fallback
                  }

                  // Determine Icon Data
                  IconData tabIcon = Icons.extension;
                  if (config.tabIcon.toLowerCase() == 'movie')
                    tabIcon = Icons.movie;
                  if (config.tabIcon.toLowerCase() == 'tv') tabIcon = Icons.tv;
                  if (config.tabIcon.toLowerCase() == 'sports')
                    tabIcon = Icons.sports_soccer;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              DynamicContentListScreen(config: config),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            cardColor.withOpacity(0.8),
                            cardColor.withOpacity(0.4),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: cardColor.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -20,
                            bottom: -20,
                            child: Icon(
                              tabIcon,
                              size: 100,
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    tabIcon,
                                    size: 30,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        config.tabName,
                                        style: const TextStyle(
                                          fontFamily: 'AppFont',
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
