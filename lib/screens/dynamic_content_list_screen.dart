import 'package:flutter/material.dart';
import 'package:almadar/services/dynamic_api_service.dart';
import 'package:almadar/data/models.dart';
import 'package:almadar/screens/player_screen.dart';
import 'package:almadar/core/theme.dart';
import 'package:almadar/widgets/app_image.dart';

class DynamicContentListScreen extends StatefulWidget {
  final DynamicApiSourceConfig config;

  const DynamicContentListScreen({super.key, required this.config});

  @override
  State<DynamicContentListScreen> createState() =>
      _DynamicContentListScreenState();
}

class _DynamicContentListScreenState extends State<DynamicContentListScreen> {
  final DynamicApiService _service = DynamicApiService();
  List<DynamicContentItem> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      var results = await _service.fetchDynamicContent(widget.config);

      if (widget.config.sortAlphabetically) {
        results.sort((a, b) => a.title.compareTo(b.title));
      }
      if (widget.config.sortByLatest) {
        // Assuming latest is at the bottom, just reverse if needed or use ID. For now just reverse.
        results = results.reversed.toList();
      }

      setState(() {
        _items = results;
        _isLoading = false;
      });
    } catch (e) {
      if (widget.config.autoRetryFailures) {
        // Basic one-time retry
        try {
          var results = await _service.fetchDynamicContent(widget.config);
          setState(() {
            _items = results;
            _isLoading = false;
          });
          return;
        } catch (_) {}
      }
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _openPlayer(DynamicContentItem item) {
    if (widget.config.familyPin.isNotEmpty) {
      // Prompt for PIN
      String typedPin = '';
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('قفل عائلي'),
          content: TextField(
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            decoration: const InputDecoration(hintText: 'أدخل الرمز السري'),
            onChanged: (v) => typedPin = v,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (typedPin == widget.config.familyPin) {
                  Navigator.pop(ctx);
                  _launchPlayerInner(item);
                } else {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('الرمز خاطئ')));
                }
              },
              child: const Text('فتح'),
            ),
          ],
        ),
      );
    } else {
      _launchPlayerInner(item);
    }
  }

  void _launchPlayerInner(DynamicContentItem item) {
    Map<String, String> customHeaders = {};
    if (widget.config.userAgent.isNotEmpty)
      customHeaders['User-Agent'] = widget.config.userAgent;
    if (widget.config.referer.isNotEmpty)
      customHeaders['Referer'] = widget.config.referer;

    final source = VideoSource(
      quality: 'Auto',
      url: item.streamUrl,
      headers: customHeaders.isNotEmpty ? customHeaders : null,
      drmType: item.drmType,
      drmLicenseUrl: item.drmType?.toLowerCase() == 'widevine'
          ? item.drmLicenseUrl
          : null,
      drmKey: item.drmType?.toLowerCase() == 'clearkey'
          ? item.drmLicenseUrl
          : null,
    );

    final dynamicChannel = Channel(
      id: item.streamUrl.hashCode.toString(),
      name: item.title,
      logoUrl: item.logoUrl,
      categoryId: item.categoryId,
      sources: [source],
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          channel: dynamicChannel,
          forceLandscapeMode: widget.config.forceLandscape,
          isLive: widget.config.tabIcon.toLowerCase() == 'tv' || item.streamUrl.contains('live'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color appBarColor = Colors.blue;
    try {
      appBarColor = Color(
        int.parse(widget.config.tabColorHex.replaceFirst('#', '0xFF')),
      );
    } catch (_) {}

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.config.tabName,
          style: const TextStyle(fontFamily: 'AppFont', fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [appBarColor.withOpacity(0.8), Colors.transparent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 10),
            Text('خطأ: $_error', style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _fetchData,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Text(
          'لا توجد باقات متاحة حالياً',
          style: const TextStyle(fontFamily: 'AppFont', color: Colors.white, fontSize: 18),
        ),
      );
    }

    if (widget.config.presentationMode == 'list') {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(15),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(10),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AppImage(
                  imageUrl: item.logoUrl,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              ),
              title: Text(
                item.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'AppFont',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: item.description.isNotEmpty
                  ? Text(
                      item.description,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontFamily: 'AppFont',
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
              onTap: () => _openPlayer(item),
            ),
          );
        },
      );
    }

    // Grid mode
    int columns = widget.config.gridColumns;
    if (columns < 2) columns = 2;
    if (columns > 4) columns = 4;

    return GridView.builder(
      padding: const EdgeInsets.all(15),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: widget.config.imageAspectRatio,
        crossAxisSpacing: 15,
        mainAxisSpacing: 18,
      ),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return GestureDetector(
          onTap: () => _openPlayer(item),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white10, width: 0.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AppImage(
                          imageUrl: item.logoUrl,
                          fit: BoxFit.cover,
                          borderRadius: 18,
                        ),
                        Positioned.fill(
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black87],
                                stops: [0.6, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'AppFont',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
