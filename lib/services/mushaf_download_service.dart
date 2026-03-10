// RN: mushaf sayfa indirme – getMushafPageUrl + FileSystem.downloadAsync eşdeğeri.

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'quran_service.dart';

/// İndirilen sayfalar [applicationDocumentsDirectory]/mushaf/ içine page_001.png ... olarak yazılır.
Future<({bool success, String? error})> downloadMushafPages(
  List<int> pageNumbers, {
  void Function(int current, int total)? onProgress,
}) async {
  if (pageNumbers.isEmpty) return (success: true, error: null);
  try {
    final dir = await getApplicationDocumentsDirectory();
    final mushafDir = Directory('${dir.path}/mushaf');
    if (!await mushafDir.exists()) await mushafDir.create(recursive: true);

    int current = 0;
    final total = pageNumbers.length;
    for (final pageNum in pageNumbers) {
      onProgress?.call(current, total);
      final url = getMushafPageUrl(pageNum);
      final fileName = 'page_${pageNum.toString().padLeft(3, '0')}.png';
      final file = File('${mushafDir.path}/$fileName');
      if (await file.exists()) {
        current++;
        continue;
      }
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) {
        return (success: false, error: 'HTTP ${res.statusCode} for page $pageNum');
      }
      await file.writeAsBytes(res.bodyBytes);
      current++;
      onProgress?.call(current, total);
    }
    return (success: true, error: null);
  } catch (e) {
    return (success: false, error: e.toString());
  }
}
