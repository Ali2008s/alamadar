import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final emojis = {
    '👍': '1f44d.png',
    '❤️': '2764-fe0f.png',
    '😂': '1f602.png',
    '😮': '1f62e.png',
    '😢': '1f622.png',
    '🙏': '1f64f.png',
  };

  final dir = Directory('assets/images/emojis');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  for (final entry in emojis.entries) {
    final emoji = entry.key;
    final filename = entry.value;
    final url =
        'https://unpkg.com/emoji-datasource-apple@14.0.0/img/apple/64/$filename';
    print('Downloading $emoji from $url...');

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final file = File('assets/images/emojis/$emoji.png');
      await file.writeAsBytes(response.bodyBytes);
      print('Saved ${file.path}');
    } else {
      print('Failed to download $emoji: ${response.statusCode}');
    }
  }
}
