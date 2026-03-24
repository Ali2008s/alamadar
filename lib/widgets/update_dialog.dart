import 'package:flutter/material.dart';
import 'package:almadar/core/theme.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:almadar/core/security_utils.dart';

class UpdateDialog extends StatefulWidget {
  final String updateUrl;
  final bool isForce;
  final String? notes;
  final bool isWebLink;

  const UpdateDialog({
    super.key,
    required this.updateUrl,
    this.isForce = false,
    this.notes,
    this.isWebLink = false,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  double _progress = 0;
  bool _isDownloading = false;
  late String _statusMessage;

  @override
  void initState() {
    super.initState();
    _statusMessage = widget.isWebLink
        ? 'يتوفر تحديث جديد عبر المتصفح!'
        : 'يتوفر تحديث جديد للتطبيق!';

    // If force update and APK link → auto-start download immediately
    if (widget.isForce && !widget.isWebLink) {
      Future.delayed(const Duration(milliseconds: 600), _handleUpdate);
    }
  }

  Future<void> _handleUpdate() async {
    if (widget.isWebLink) {
      final uri = Uri.parse(widget.updateUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    if (_isDownloading) return; // Prevent double-tap

    setState(() {
      _isDownloading = true;
      _progress = 0;
      _statusMessage = 'جاري تحميل التحديث...';
    });

    try {
      // Use app-private external cache dir — NO storage permission needed on Android 10+
      final directory = await getExternalStorageDirectory();
      final savePath =
          '${directory!.path}/almadar_update_${DateTime.now().millisecondsSinceEpoch}.apk';

      await Dio().download(
        widget.updateUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() {
              _progress = received / total;
            });
          }
        },
      );

      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _statusMessage = 'اكتمل التحميل! اضغط تثبيت.';
      });

      // Auto-open installer
      await OpenFilex.open(savePath);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _statusMessage = 'فشل التحميل. تحقق من الاتصال وحاول مجدداً.';
      });
      debugPrint("Download error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isForce,
      child: Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F0F),
            image: const DecorationImage(
              image: AssetImage('assets/images/logo.jpg'),
              opacity: 0.05,
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 1),

                // Icon & Title
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentBlue.withOpacity(0.2),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    color: AppColors.accentBlue,
                    size: 80,
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  'تحديث جديد متوفر',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _statusMessage,
                  style: const TextStyle(color: Colors.white60, fontSize: 16),
                ),

                const Spacer(flex: 1),

                // Update Notes Card
                if (widget.notes != null && widget.notes!.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 30),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'مميزات التحديث:',
                          style: TextStyle(
                            color: AppColors.accentBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.notes!,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.5,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),

                const Spacer(flex: 2),

                // Progress Area
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      if (_isDownloading) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${(_progress * 100).toInt()}%",
                              style: const TextStyle(
                                color: AppColors.accentBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const Text(
                              "جاري التحميل",
                              style: TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LinearPercentIndicator(
                          padding: EdgeInsets.zero,
                          lineHeight: 18.0,
                          percent: _progress,
                          barRadius: const Radius.circular(9),
                          progressColor: AppColors.accentBlue,
                          backgroundColor: Colors.white.withOpacity(0.1),
                          animateFromLastPercent: true,
                        ),
                      ],

                      const SizedBox(height: 40),

                      // Action Buttons
                      if (!_isDownloading)
                        Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 60,
                              child: ElevatedButton(
                                onPressed: _handleUpdate,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accentBlue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  elevation: 10,
                                  shadowColor: AppColors.accentBlue.withOpacity(
                                    0.4,
                                  ),
                                ),
                                child: Text(
                                  widget.isWebLink
                                      ? 'تحديث عبر المتصفح'
                                      : 'تحديث التطبيق الآن',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            if (!widget.isForce)
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text(
                                  'تذكيري لاحقاً',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
