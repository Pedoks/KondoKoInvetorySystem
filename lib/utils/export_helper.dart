// lib/utils/export_helper.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';

import '../models/key_group_model.dart';
import '../models/key_transaction_model.dart';

class ExportHelper {
  static final _dateFormat = DateFormat('MM/dd/yyyy hh:mm a');
  static final _fileDateFormat = DateFormat('yyyyMMdd_HHmmss');

  // ── PDF: Key Groups (Dashboard) ──────────────────────────────────────
  static Future<void> exportKeyGroupsToPdf(
    BuildContext context,
    List<KeyGroupModel> groups,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _pdfHeader('Key Groups Inventory Report'),
        footer: (ctx) => _pdfFooter(ctx),
        build: (ctx) => [
          pw.SizedBox(height: 12),
          pw.Text(
            'Generated: ${_dateFormat.format(DateTime.now())}',
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1),
              5: const pw.FlexColumnWidth(1),
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFA821E)),
                children: [
                  _pdfCell('Owner', isHeader: true),
                  _pdfCell('Unit', isHeader: true),
                  _pdfCell('Key Holder', isHeader: true),
                  _pdfCell('Unit Status', isHeader: true),
                  _pdfCell('Total', isHeader: true),
                  _pdfCell('Available', isHeader: true),
                ],
              ),
              // Data rows
              ...groups.map((g) => pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: groups.indexOf(g).isEven
                      ? const PdfColor.fromInt(0xFFFFF3E8)
                      : PdfColors.white,
                ),
                children: [
                  _pdfCell(g.ownersName),
                  _pdfCell(g.unit),
                  _pdfCell(g.keyHolder),
                  _pdfCell(g.unitStatus),
                  _pdfCell('${g.totalKeys}'),
                  _pdfCell('${g.availableKeys}'),
                ],
              )),
            ],
          ),
          pw.SizedBox(height: 24),
          // Per-group key detail section
          ...groups.map((g) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 16, bottom: 8),
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFFA821E),
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                  '${g.unit} — ${g.ownersName}  (${g.availableKeys}/${g.totalKeys} available)',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _pdfCell('Key Type', isHeader: true, fontSize: 9),
                      _pdfCell('Barcode', isHeader: true, fontSize: 9),
                      _pdfCell('Status', isHeader: true, fontSize: 9),
                    ],
                  ),
                  ...g.keys.map((k) => pw.TableRow(
                    children: [
                      _pdfCell(k.keyType, fontSize: 9),
                      _pdfCell(k.barcode, fontSize: 9),
                      _pdfCell('Available', fontSize: 9),
                    ],
                  )),
                ],
              ),
              pw.SizedBox(height: 8),
            ],
          )),
        ],
      ),
    );

    await _savePdfAndShare(context, pdf, 'key_groups');
  }

  // ── Excel: Key Groups (Dashboard) ────────────────────────────────────
  static Future<void> exportKeyGroupsToExcel(
    BuildContext context,
    List<KeyGroupModel> groups,
  ) async {
    final excel = Excel.createExcel();

    // Summary sheet
    final summarySheet = excel['Key Groups Summary'];
    excel.setDefaultSheet('Key Groups Summary');

    _excelHeader(summarySheet, [
      'Owner', 'Unit', 'Key Holder', 'Key Code',
      'Unit Status', 'Total Keys', 'Available Keys', 'Date',
    ]);

    for (final g in groups) {
      summarySheet.appendRow([
        TextCellValue(g.ownersName),
        TextCellValue(g.unit),
        TextCellValue(g.keyHolder),
        TextCellValue(g.keyCode),
        TextCellValue(g.unitStatus),
        IntCellValue(g.totalKeys),
        IntCellValue(g.availableKeys),
        TextCellValue(DateFormat('yyyy-MM-dd').format(g.date)),
      ]);
    }

    _autoWidthHint(summarySheet, 8);

    // Individual Keys sheet
    final keysSheet = excel['All Keys'];
    _excelHeader(keysSheet, [
      'Owner', 'Unit', 'Key Type', 'Barcode',
      'Key Holder', 'Key Code', 'Unit Status', 'Status',
    ]);

    for (final g in groups) {
      for (final k in g.keys) {
        keysSheet.appendRow([
          TextCellValue(g.ownersName),
          TextCellValue(g.unit),
          TextCellValue(k.keyType),
          TextCellValue(k.barcode),
          TextCellValue(g.keyHolder),
          TextCellValue(g.keyCode),
          TextCellValue(g.unitStatus),
          TextCellValue('Available'),
        ]);
      }
    }

    _autoWidthHint(keysSheet, 8);

    // Remove default sheet
    excel.delete('Sheet1');

    await _saveExcelAndShare(context, excel, 'key_groups');
  }

  // ── PDF: Transaction History (Keys In & Out) ──────────────────────────
  static Future<void> exportTransactionsToPdf(
    BuildContext context,
    List<KeyTransactionModel> transactions,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _pdfHeader('Key Transaction History — Global Report'),
        footer: (ctx) => _pdfFooter(ctx),
        build: (ctx) => [
          pw.SizedBox(height: 12),
          pw.Text(
            'Generated: ${_dateFormat.format(DateTime.now())}  •  '
            'Total transactions: ${transactions.length}',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
              4: const pw.FlexColumnWidth(1.5),
              5: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFA821E)),
                children: [
                  _pdfCell('User', isHeader: true),
                  _pdfCell('Unit', isHeader: true),
                  _pdfCell('Check-Out', isHeader: true),
                  _pdfCell('Check-In', isHeader: true),
                  _pdfCell('Duration', isHeader: true),
                  _pdfCell('Status', isHeader: true),
                ],
              ),
              ...transactions.asMap().entries.map((entry) {
                final i = entry.key;
                final t = entry.value;
                final duration = t.checkInDate != null
                    ? _calcDuration(t.checkOutDate, t.checkInDate!)
                    : 'Still Out';
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: i.isEven
                        ? const PdfColor.fromInt(0xFFFFF3E8)
                        : PdfColors.white,
                  ),
                  children: [
                    _pdfCell(t.userName, fontSize: 9),
                    _pdfCell(t.unit, fontSize: 9),
                    _pdfCell(_dateFormat.format(t.checkOutDate.toLocal()), fontSize: 9),
                    _pdfCell(
                      t.checkInDate != null
                          ? _dateFormat.format(t.checkInDate!.toLocal())
                          : '—',
                      fontSize: 9,
                    ),
                    _pdfCell(duration, fontSize: 9),
                    _pdfCell(t.status, fontSize: 9),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );

    await _savePdfAndShare(context, pdf, 'key_transactions');
  }

  // ── Excel: Transaction History (Keys In & Out) ────────────────────────
  static Future<void> exportTransactionsToExcel(
    BuildContext context,
    List<KeyTransactionModel> transactions,
  ) async {
    final excel = Excel.createExcel();
    final sheet = excel['Global Transaction History'];
    excel.setDefaultSheet('Global Transaction History');

    _excelHeader(sheet, [
      'User Name', 'User ID', 'Unit', 'Barcode',
      'Check-Out Date', 'Check-In Date', 'Duration', 'Status',
    ]);

    for (final t in transactions) {
      final duration = t.checkInDate != null
          ? _calcDuration(t.checkOutDate, t.checkInDate!)
          : 'Still Out';
      sheet.appendRow([
        TextCellValue(t.userName),
        TextCellValue(t.userId),
        TextCellValue(t.unit),
        TextCellValue(t.barcode),
        TextCellValue(_dateFormat.format(t.checkOutDate.toLocal())),
        TextCellValue(
          t.checkInDate != null
              ? _dateFormat.format(t.checkInDate!.toLocal())
              : '—',
        ),
        TextCellValue(duration),
        TextCellValue(t.status),
      ]);
    }

    _autoWidthHint(sheet, 8);
    excel.delete('Sheet1');

    await _saveExcelAndShare(context, excel, 'key_transactions');
  }

  // ── Private Helpers ───────────────────────────────────────────────────

  static pw.Widget _pdfHeader(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFFA821E), width: 2),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFFFA821E),
            ),
          ),
          pw.Text(
            'KondoKo Inventory System',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
          ),
        ],
      ),
    );
  }

  static pw.Widget _pdfFooter(pw.Context ctx) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'KondoKo Inventory System',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
          pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
        ],
      ),
    );
  }

  static pw.Widget _pdfCell(
    String text, {
    bool isHeader = false,
    double fontSize = 10,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : PdfColors.black,
        ),
      ),
    );
  }

  static void _excelHeader(Sheet sheet, List<String> headers) {
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#FA821E'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }
  }

  static void _autoWidthHint(Sheet sheet, int colCount) {
    for (int i = 0; i < colCount; i++) {
      sheet.setColumnWidth(i, 20);
    }
  }

  static String _calcDuration(DateTime start, DateTime end) {
    final diff = end.difference(start);
    if (diff.inDays > 0) return '${diff.inDays}d ${diff.inHours.remainder(24)}h';
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return '${diff.inSeconds}s';
  }

  static Future<void> _savePdfAndShare(
    BuildContext context,
    pw.Document pdf,
    String prefix,
  ) async {
    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final filename = '${prefix}_${_fileDateFormat.format(DateTime.now())}.pdf';
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: filename,
    );
  }

  static Future<void> _saveExcelAndShare(
    BuildContext context,
    Excel excel,
    String prefix,
  ) async {
    final bytes = excel.encode();
    if (bytes == null) return;
    final dir = await getTemporaryDirectory();
    final filename = '${prefix}_${_fileDateFormat.format(DateTime.now())}.xlsx';
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: filename,
    );
  }
}