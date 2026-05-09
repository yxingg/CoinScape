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
      build: (_) => pw.Container(
        padding: const pw.EdgeInsets.all(60),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // 标题
            pw.Text(
              '纪念币收藏报告',
              style: pw.TextStyle(
                fontSize: 36,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.SizedBox(height: 40),
            
            // 装饰线
            pw.Container(
              width: 200,
              height: 4,
              color: PdfColors.blue700,
            ),
            pw.SizedBox(height: 40),
            
            // 统计信息卡片
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(24),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(16),
                border: pw.Border.all(color: PdfColors.blue200, width: 2),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '报告摘要',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  
                  pw.Table(
                    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
                    columnWidths: {
                      0: const pw.FixedColumnWidth(120),
                      1: const pw.FlexColumnWidth(),
                    },
                    children: [
                      pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 8),
                            child: pw.Text('导出日期:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 8),
                            child: pw.Text(dateStr),
                          ),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 8),
                            child: pw.Text('纪念币总数:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 8),
                            child: pw.Text('${coins.length} 枚'),
                          ),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 8),
                            child: pw.Text('总估价:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 8),
                            child: pw.Text(
                              '￥${totalPrice.toStringAsFixed(2)}',
                              style: pw.TextStyle(
                                color: PdfColors.green700,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 60),
            
            // 页脚
            pw.Text(
              'CoinScape 收藏管理系统',
              style: pw.TextStyle(
                fontSize: 14,
                color: PdfColors.grey600,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ],
        ),
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
      build: (_) => pw.Container(
        padding: const pw.EdgeInsets.all(40),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // 目录标题
            pw.Text(
              '目录',
              style: pw.TextStyle(
                fontSize: 32,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.indigo900,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              '纪念币分类列表',
              style: pw.TextStyle(
                fontSize: 16,
                color: PdfColors.grey600,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
            pw.SizedBox(height: 30),
            
            // 分组列表
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 1),
              columnWidths: const {
                0: pw.FixedColumnWidth(60),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(1),
                3: pw.FixedColumnWidth(100),
              },
              children: [
                // 表头
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.indigo50),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(12),
                      child: pw.Text(
                        '序号',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.indigo800,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(12),
                      child: pw.Text(
                        '系列/分组',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.indigo800,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(12),
                      child: pw.Text(
                        '描述',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.indigo800,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(12),
                      child: pw.Text(
                        '纪念币数量',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.indigo800,
                        ),
                      ),
                    ),
                  ],
                ),
                
                // 数据行
                ...List.generate(sections.length, (index) {
                  final section = sections[index];
                  final isEven = index % 2 == 0;
                  
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: isEven ? PdfColors.grey50 : PdfColors.white,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(12),
                        child: pw.Text(
                          '${index + 1}',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue700,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(12),
                        child: pw.Text(
                          section.title,
                          style: pw.TextStyle(fontSize: 14),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(12),
                        child: pw.Text(
                          '收藏系列',
                          style: pw.TextStyle(
                            fontSize: 13,
                            color: PdfColors.grey600,
                            fontStyle: pw.FontStyle.italic,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(12),
                        child: pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.blue100,
                            borderRadius: pw.BorderRadius.circular(20),
                          ),
                          child: pw.Center(
                            child: pw.Text(
                              '${section.coins.length} 枚',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 30),
            
            // 统计摘要
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.green50,
                borderRadius: pw.BorderRadius.circular(12),
                border: pw.Border.all(color: PdfColors.green200, width: 1),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '总计:',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green800,
                      fontSize: 16,
                    ),
                  ),
                  pw.Text(
                    '${sections.length} 个分组 • ${coins.length} 枚纪念币',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  for (final section in sections) {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        build: (_) => pw.Container(
          padding: const pw.EdgeInsets.all(60),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              // 装饰图标
              pw.Text(
                '📀',
                style: const pw.TextStyle(fontSize: 60),
              ),
              pw.SizedBox(height: 30),
              
              // 分组标题
              pw.Text(
                section.title,
                style: pw.TextStyle(
                  fontSize: 36,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.deepOrange800,
                ),
              ),
              pw.SizedBox(height: 16),
              
              // 装饰线
              pw.Container(
                width: 180,
                height: 3,
                color: PdfColors.deepOrange500,
              ),
              pw.SizedBox(height: 20),
              
              // 分组统计信息
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.deepOrange50,
                  borderRadius: pw.BorderRadius.circular(16),
                  border: pw.Border.all(color: PdfColors.deepOrange200, width: 2),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Icon(
                      pw.IconData(0xf02b), // 图书图标
                      size: 20,
                      color: PdfColors.deepOrange700,
                    ),
                    pw.SizedBox(width: 12),
                    pw.Text(
                      '本系列包含 ${section.coins.length} 枚纪念币',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.deepOrange700,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 40),
              
              // 页码提示
              pw.Text(
                '以下页面展示本系列纪念币详情',
                style: pw.TextStyle(
                  fontSize: 14,
                  color: PdfColors.grey600,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    for (int i = 0; i < section.coins.length; i++) {
      final c = section.coins[i];
      final imgBytes = coinImages[c.id];
      final isFirstInSection = i == 0; // 分组的第一个纪念币
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          theme: theme,
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 标题
              pw.Text(
                c.name,
                style: pw.TextStyle(
                  fontSize: isFirstInSection ? 26 : 22, // 第一个标题稍大
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: isFirstInSection ? 20 : 16),
              
              // 图片区域
              if (imgBytes != null)
                pw.Container(
                  height: isFirstInSection ? 280 : 200, // 第一个图片更大
                  width: double.infinity,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.circular(8),
                    image: pw.DecorationImage(
                      image: pw.MemoryImage(imgBytes),
                      fit: isFirstInSection ? pw.BoxFit.contain : pw.BoxFit.cover,
                    ),
                  ),
                  child: pw.Container(
                    decoration: pw.BoxDecoration(
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: PdfColors.grey400, width: 1),
                    ),
                  ),
                )
              else
                pw.Container(
                  height: isFirstInSection ? 280 : 200,
                  width: double.infinity,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Center(
                    child: pw.Text('无图片', style: pw.TextStyle(color: PdfColors.grey600)),
                  ),
                ),
              
              pw.SizedBox(height: isFirstInSection ? 24 : 18),
              
              // 详细信息表格布局
              pw.Table(
                columnWidths: {
                  0: const pw.FixedColumnWidth(80),
                  1: const pw.FlexColumnWidth(),
                },
                defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
                border: pw.TableBorder(
                  verticalInside: pw.BorderSide(color: PdfColors.grey300),
                  horizontalInside: pw.BorderSide(color: PdfColors.grey300),
                ),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('年份:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('${c.year ?? '-'}'),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('面值:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('${c.faceValue ?? '-'}'),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('材质:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('${c.material ?? "-"}'),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('重量:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('${c.weight ?? '-'} g'),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('直径:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('${c.diameter ?? '-'} mm'),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('数量:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('${c.quantity ?? 0} ${c.quantityUnit ?? ''}'),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('单价:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('￥${c.unitPrice ?? 0}'),
                      ),
                    ],
                  ),
                ],
              ),
              
              pw.SizedBox(height: 16),
              
              // 评论区域
              if (c.comments?.isNotEmpty == true) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.grey300, width: 1),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '备注:',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        c.comments!,
                        style: pw.TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                pw.Text(
                  '备注: -',
                  style: pw.TextStyle(color: PdfColors.grey500),
                ),
              ],
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
