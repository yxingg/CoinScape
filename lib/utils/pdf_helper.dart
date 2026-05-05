import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../database/database.dart';
import '../services/font_manager.dart';

import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

Future<Uint8List?> _loadImageBytes(String? imagePath) async {
  if (imagePath == null || imagePath.isEmpty) return null;
  if (kIsWeb) {
    if (imagePath.startsWith('base64:')) {
      try {
        return base64Decode(imagePath.substring(7));
      } catch (_) {}
    }
  } else {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final file = File(p.join(docDir.path, imagePath.replaceAll('/', p.separator)));
      if (file.existsSync()) {
        return await file.readAsBytes();
      }
    } catch (_) {}
  }
  return null;
}

Future<Uint8List> generateCoinsPdf(
  List<Coin> coins, {
  String? chineseFontId,
  String? englishFontId,
  List<PdfSeriesSection> seriesSections = const [],
}) async {
  final pdf = pw.Document();

  pw.Font? baseFont;
  pw.Font? boldFont;

  Future<void> loadCustomOrPresetFont() async {
    // 默认回退：使用线上/应用缓存的 Noto Sans
    baseFont = await PdfGoogleFonts.notoSansSCRegular();
    boldFont = await PdfGoogleFonts.notoSansSCBold();

    if (chineseFontId != null && chineseFontId.isNotEmpty) {
      final bytes = await FontManager.loadFont(chineseFontId);
      if (bytes != null) {
        try {
          baseFont = pw.Font.ttf(bytes.buffer.asByteData());
          boldFont = baseFont; // 如果只有一个字体文件，加粗也默认用这个，或者你后期让用户分选粗体
        } catch (_) {}
      }
    }
  }

  await loadCustomOrPresetFont();

  final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  final String dateStr = dateFormat.format(DateTime.now());

  double totalPrice = 0.0;
  for (var c in coins) {
    totalPrice += (c.unitPrice ?? 0) * (c.quantity ?? 1);
  }

  // Pre-load all image bytes
  final Map<String, Uint8List?> coinImages = {};
  for (var c in coins) {
    if (c.firstImagePath != null && c.firstImagePath!.isNotEmpty) {
      coinImages[c.id] = await _loadImageBytes(c.firstImagePath);
    }
  }

  final theme = pw.ThemeData.withFont(base: baseFont, bold: boldFont);

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('纪念币收藏报告', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('导出日期: $dateStr'),
          pw.Text('总计选中: ${coins.length} 枚'),
          pw.Text('总估价: ￥${totalPrice.toStringAsFixed(2)}'),
        ],
      ),
    ),
  );

  final sections = seriesSections.isEmpty
      ? [PdfSeriesSection(title: '纪念币', coins: coins)]
      : seriesSections;

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('目录', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: const {
              0: pw.FixedColumnWidth(40),
              1: pw.FlexColumnWidth(),
              2: pw.FixedColumnWidth(80),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('序号')),
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('分组')),
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('数量')),
                ],
              ),
              ...List.generate(sections.length, (index) {
                final section = sections[index];
                return pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${index + 1}')),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(section.title)),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${section.coins.length}')),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    ),
  );

  for (final section in sections) {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        build: (_) => pw.Center(
          child: pw.Text(section.title, style: pw.TextStyle(fontSize: 34, fontWeight: pw.FontWeight.bold)),
        ),
      ),
    );

    for (final c in section.coins) {
      final imgBytes = coinImages[c.id];
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          theme: theme,
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(c.name, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 16),
              if (imgBytes != null)
                pw.Container(
                  height: 220,
                  width: double.infinity,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    image: pw.DecorationImage(image: pw.MemoryImage(imgBytes), fit: pw.BoxFit.cover),
                  ),
                )
              else
                pw.Container(
                  height: 220,
                  width: double.infinity,
                  color: PdfColors.grey200,
                  child: pw.Center(child: pw.Text('无图片')),
                ),
              pw.SizedBox(height: 16),
              pw.Text('年份: ${c.year ?? '-'}'),
              pw.Text('面值: ${c.faceValue ?? '-'}'),
              pw.Text('材质: ${c.material ?? '-'}'),
              pw.Text('重量: ${c.weight ?? '-'} g'),
              pw.Text('直径: ${c.diameter ?? '-'} mm'),
              pw.Text('数量: ${c.quantity ?? 0} ${c.quantityUnit ?? ''}'),
              pw.Text('单价: ￥${c.unitPrice ?? 0}'),
              pw.SizedBox(height: 8),
              pw.Text('简评: ${c.comments?.isNotEmpty == true ? c.comments : '-'}'),
            ],
          ),
        ),
      );
    }
  }

  return pdf.save();
}

class PdfSeriesSection {
  final String title;
  final List<Coin> coins;

  PdfSeriesSection({required this.title, required this.coins});
}
