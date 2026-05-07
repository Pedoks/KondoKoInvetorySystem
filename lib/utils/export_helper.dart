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
import '../models/item_model.dart';
import '../utils/constants.dart';

class ExportHelper {
  static final _dateFormat     = DateFormat('MM/dd/yyyy hh:mm a');
  static final _dateShort      = DateFormat('MM/dd/yyyy');
  static final _fileDateFormat = DateFormat('yyyyMMdd_HHmmss');

  // ════════════════════════════════════════════════════
  //  KEY GROUPS  (Dashboard)
  // ════════════════════════════════════════════════════

  static Future<void> exportKeyGroupsToPdf(
    BuildContext context,
    List<KeyGroupModel> groups, {
    bool download = false,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin:     const pw.EdgeInsets.all(32),
        header:     (ctx) => _pdfHeader('Key Groups Inventory Report'),
        footer:     (ctx) => _pdfFooter(ctx),
        build: (ctx) => [
          pw.SizedBox(height: 12),
          pw.Text(
            'Generated: ${_dateFormat.format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
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
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(AppConstants.primaryColorValue)),
                children: [
                  _pdfCell('Owner',       isHeader: true),
                  _pdfCell('Unit',        isHeader: true),
                  _pdfCell('Key Holder',  isHeader: true),
                  _pdfCell('Unit Status', isHeader: true),
                  _pdfCell('Total',       isHeader: true),
                  _pdfCell('Available',   isHeader: true),
                ],
              ),
              ...groups.map((g) => pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: groups.indexOf(g).isEven
                      ? const PdfColor.fromInt(AppConstants.lightOrangeValue)
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
          ...groups.map((g) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                margin:  const pw.EdgeInsets.only(top: 16, bottom: 8),
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: const pw.BoxDecoration(
                  color:        PdfColor.fromInt(AppConstants.primaryColorValue),
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                  '${g.unit} — ${g.ownersName}  '
                  '(${g.availableKeys}/${g.totalKeys} available)',
                  style: pw.TextStyle(
                    color:      PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize:   11,
                  ),
                ),
              ),
              pw.Table(
                border: pw.TableBorder.all(
                    color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                        color: PdfColors.grey200),
                    children: [
                      _pdfCell('Key Type', isHeader: true, fontSize: 9),
                      _pdfCell('Barcode',  isHeader: true, fontSize: 9),
                      _pdfCell('Status',   isHeader: true, fontSize: 9),
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

    if (download) {
      await _downloadPdf(context, pdf, 'key_groups');
    } else {
      await _sharePdf(context, pdf, 'key_groups');
    }
  }

  static Future<void> exportKeyGroupsToExcel(
    BuildContext context,
    List<KeyGroupModel> groups, {
    bool download = false,
  }) async {
    final excel = Excel.createExcel();

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
    excel.delete('Sheet1');

    if (download) {
      await _downloadExcel(context, excel, 'key_groups');
    } else {
      await _shareExcel(context, excel, 'key_groups');
    }
  }

  // ════════════════════════════════════════════════════
  //  KEY TRANSACTIONS  (Keys In & Out)
  // ════════════════════════════════════════════════════

  static Future<void> exportTransactionsToPdf(
    BuildContext context,
    List<KeyTransactionModel> transactions, {
    bool download = false,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin:     const pw.EdgeInsets.all(32),
        header:     (ctx) => _pdfHeader('Key Transaction History — Global Report'),
        footer:     (ctx) => _pdfFooter(ctx),
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
                decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(AppConstants.primaryColorValue)),
                children: [
                  _pdfCell('User',      isHeader: true),
                  _pdfCell('Unit',      isHeader: true),
                  _pdfCell('Check-Out', isHeader: true),
                  _pdfCell('Check-In',  isHeader: true),
                  _pdfCell('Duration',  isHeader: true),
                  _pdfCell('Status',    isHeader: true),
                ],
              ),
              ...transactions.asMap().entries.map((entry) {
                final i        = entry.key;
                final t        = entry.value;
                final duration = t.checkInDate != null
                    ? _calcDuration(t.checkOutDate, t.checkInDate!)
                    : 'Still Out';
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: i.isEven
                        ? const PdfColor.fromInt(AppConstants.lightOrangeValue)
                        : PdfColors.white,
                  ),
                  children: [
                    _pdfCell(t.userName, fontSize: 9),
                    _pdfCell(t.unit, fontSize: 9),
                    _pdfCell(_dateFormat.format(t.checkOutDate.toLocal()),
                        fontSize: 9),
                    _pdfCell(
                      t.checkInDate != null
                          ? _dateFormat.format(t.checkInDate!.toLocal())
                          : '—',
                      fontSize: 9,
                    ),
                    _pdfCell(duration, fontSize: 9),
                    _pdfCell(t.status,  fontSize: 9),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );

    if (download) {
      await _downloadPdf(context, pdf, 'key_transactions');
    } else {
      await _sharePdf(context, pdf, 'key_transactions');
    }
  }

  static Future<void> exportTransactionsToExcel(
    BuildContext context,
    List<KeyTransactionModel> transactions, {
    bool download = false,
  }) async {
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

    if (download) {
      await _downloadExcel(context, excel, 'key_transactions');
    } else {
      await _shareExcel(context, excel, 'key_transactions');
    }
  }

  // ════════════════════════════════════════════════════
  //  ITEMS  (Item Dashboard)
  // ════════════════════════════════════════════════════

  static Future<void> exportItemsToPdf(
    BuildContext context,
    List<ItemModel> items, {
    bool download = false,
  }) async {
    final pdf = pw.Document();

    final consumables    = items.where((i) => i.isConsumable).toList();
    final nonConsumables = items.where((i) => i.isNonConsumable).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin:     const pw.EdgeInsets.all(32),
        header:     (ctx) => _pdfHeader('Items Inventory Report'),
        footer:     (ctx) => _pdfFooter(ctx),
        build: (ctx) => [
          pw.SizedBox(height: 12),
          pw.Text(
            'Generated: ${_dateFormat.format(DateTime.now())}  •  '
            'Total items: ${items.length}  '
            '(Consumable: ${consumables.length}  '
            'Non-Consumable: ${nonConsumables.length})',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 16),

          // ── Summary table ──────────────────────────
          _pdfSectionTitle('Items Summary'),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(
                color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.5),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(AppConstants.primaryColorValue)),
                children: [
                  _pdfCell('Item Name',   isHeader: true),
                  _pdfCell('Type',        isHeader: true),
                  _pdfCell('Quantity',    isHeader: true),
                  _pdfCell('Stock Status',isHeader: true),
                  _pdfCell('Date Added',  isHeader: true),
                ],
              ),
              ...items.asMap().entries.map((entry) {
                final i    = entry.key;
                final item = entry.value;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: i.isEven
                        ? const PdfColor.fromInt(AppConstants.lightOrangeValue)
                        : PdfColors.white,
                  ),
                  children: [
                    _pdfCell(item.itemName, fontSize: 9),
                    _pdfCell(item.itemType, fontSize: 9),
                    _pdfCell(item.quantityDisplay, fontSize: 9),
                    _pdfCell(item.stockStatus, fontSize: 9),
                    _pdfCell(_dateShort.format(item.date), fontSize: 9),
                  ],
                );
              }),
            ],
          ),

          // ── Consumable detail ──────────────────────
          if (consumables.isNotEmpty) ...[
            pw.SizedBox(height: 24),
            _pdfSectionTitle('Consumable Items — Unit Detail'),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(1.5),
                5: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200),
                  children: [
                    _pdfCell('Item Name',     isHeader: true, fontSize: 9),
                    _pdfCell('Unit Type',     isHeader: true, fontSize: 9),
                    _pdfCell('Pref. Unit',    isHeader: true, fontSize: 9),
                    _pdfCell('Qty (Pref)',    isHeader: true, fontSize: 9),
                    _pdfCell('Min Stock',     isHeader: true, fontSize: 9),
                    _pdfCell('Max Stock',     isHeader: true, fontSize: 9),
                  ],
                ),
                ...consumables.map((item) {
                  final qty = item.quantityInPreferred;
                  final min = item.minStockInPreferred;
                  final max = item.maxStockInPreferred;
                  return pw.TableRow(
                    children: [
                      _pdfCell(item.itemName, fontSize: 8),
                      _pdfCell(item.unitType, fontSize: 8),
                      _pdfCell(item.preferredUnit, fontSize: 8),
                      _pdfCell('${_fmtDouble(qty)} ${item.preferredUnit}',
                          fontSize: 8),
                      _pdfCell('${_fmtDouble(min)} ${item.preferredUnit}',
                          fontSize: 8),
                      _pdfCell('${_fmtDouble(max)} ${item.preferredUnit}',
                          fontSize: 8),
                    ],
                  );
                }),
              ],
            ),
          ],

          // ── Non-Consumable detail ──────────────────
          if (nonConsumables.isNotEmpty) ...[
            pw.SizedBox(height: 24),
            _pdfSectionTitle('Non-Consumable Items'),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200),
                  children: [
                    _pdfCell('Item Name',    isHeader: true, fontSize: 9),
                    _pdfCell('Description',  isHeader: true, fontSize: 9),
                    _pdfCell('Barcode',      isHeader: true, fontSize: 9),
                    _pdfCell('Stock Status', isHeader: true, fontSize: 9),
                  ],
                ),
                ...nonConsumables.map((item) => pw.TableRow(
                  children: [
                    _pdfCell(item.itemName, fontSize: 8),
                    _pdfCell(
                        item.description.isNotEmpty
                            ? item.description
                            : '—',
                        fontSize: 8),
                    _pdfCell(
                        item.barcode.isNotEmpty ? item.barcode : '—',
                        fontSize: 8),
                    _pdfCell(item.stockStatus, fontSize: 8),
                  ],
                )),
              ],
            ),
          ],
        ],
      ),
    );

    if (download) {
      await _downloadPdf(context, pdf, 'items_inventory');
    } else {
      await _sharePdf(context, pdf, 'items_inventory');
    }
  }

  static Future<void> exportItemsToExcel(
    BuildContext context,
    List<ItemModel> items, {
    bool download = false,
  }) async {
    final excel = Excel.createExcel();

    // ── Sheet 1: Summary ───────────────────────────
    final summarySheet = excel['Items Summary'];
    excel.setDefaultSheet('Items Summary');

    _excelHeader(summarySheet, [
      'Item Name', 'Item Type', 'Stock Status',
      'Quantity', 'Date Added',
    ]);

    for (final item in items) {
      summarySheet.appendRow([
        TextCellValue(item.itemName),
        TextCellValue(item.itemType),
        TextCellValue(item.stockStatus),
        TextCellValue(item.quantityDisplay),
        TextCellValue(_dateShort.format(item.date)),
      ]);
    }
    _autoWidthHint(summarySheet, 5);

    // ── Sheet 2: Consumable Detail ─────────────────
    final consumables = items.where((i) => i.isConsumable).toList();
    if (consumables.isNotEmpty) {
      final cSheet = excel['Consumable Detail'];
      _excelHeader(cSheet, [
        'Item Name', 'Unit Type', 'Base Unit', 'Preferred Unit',
        'Qty (Preferred)', 'Min Stock (Pref)', 'Max Stock (Pref)',
        'Conv. Factor', 'Stock Status', 'Date Added',
      ]);

      for (final item in consumables) {
        cSheet.appendRow([
          TextCellValue(item.itemName),
          TextCellValue(item.unitType),
          TextCellValue(item.baseUnit),
          TextCellValue(item.preferredUnit),
          TextCellValue(
              '${_fmtDouble(item.quantityInPreferred)} ${item.preferredUnit}'),
          TextCellValue(
              '${_fmtDouble(item.minStockInPreferred)} ${item.preferredUnit}'),
          TextCellValue(
              '${_fmtDouble(item.maxStockInPreferred)} ${item.preferredUnit}'),
          DoubleCellValue(item.conversionFactor),
          TextCellValue(item.stockStatus),
          TextCellValue(_dateShort.format(item.date)),
        ]);
      }
      _autoWidthHint(cSheet, 10);
    }

    // ── Sheet 3: Non-Consumable Detail ─────────────
    final nonConsumables = items.where((i) => i.isNonConsumable).toList();
    if (nonConsumables.isNotEmpty) {
      final ncSheet = excel['Non-Consumable Detail'];
      _excelHeader(ncSheet, [
        'Item Name', 'Barcode', 'Description', 'Stock Status', 'Date Added',
      ]);

      for (final item in nonConsumables) {
        ncSheet.appendRow([
          TextCellValue(item.itemName),
          TextCellValue(item.barcode.isNotEmpty ? item.barcode : '—'),
          TextCellValue(
              item.description.isNotEmpty ? item.description : '—'),
          TextCellValue(item.stockStatus),
          TextCellValue(_dateShort.format(item.date)),
        ]);
      }
      _autoWidthHint(ncSheet, 5);
    }

    excel.delete('Sheet1');

    if (download) {
      await _downloadExcel(context, excel, 'items_inventory');
    } else {
      await _shareExcel(context, excel, 'items_inventory');
    }
  }

  // ════════════════════════════════════════════════════
  //  ITEM TRANSACTIONS  (Issued Items — Global History)
  // ════════════════════════════════════════════════════

  static Future<void> exportItemTransactionsToPdf(
    BuildContext context,
    List<ItemTransactionModel> transactions, {
    bool download = false,
  }) async {
    final pdf = pw.Document();

    final consumableTxs = transactions
        .where((t) =>
            t.transactionType == 'StockIn' ||
            t.transactionType == 'StockOut')
        .toList();
    final nonConsumableTxs = transactions
        .where((t) =>
            t.transactionType == 'Issued' ||
            t.transactionType == 'Returned')
        .toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin:     const pw.EdgeInsets.all(32),
        header:     (ctx) => _pdfHeader('Item Transaction History — Global Report'),
        footer:     (ctx) => _pdfFooter(ctx),
        build: (ctx) => [
          pw.SizedBox(height: 12),
          pw.Text(
            'Generated: ${_dateFormat.format(DateTime.now())}  •  '
            'Total: ${transactions.length}  '
            '(Consumable: ${consumableTxs.length}  '
            'Non-Consumable: ${nonConsumableTxs.length})',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 16),

          // ── Consumable transactions ────────────────
          if (consumableTxs.isNotEmpty) ...[
            _pdfSectionTitle('Consumable Transactions (Stock In / Out)'),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(AppConstants.primaryColorValue)),
                  children: [
                    _pdfCell('User',     isHeader: true),
                    _pdfCell('Item',     isHeader: true),
                    _pdfCell('Type',     isHeader: true),
                    _pdfCell('Quantity', isHeader: true),
                    _pdfCell('Date',     isHeader: true),
                  ],
                ),
                ...consumableTxs.asMap().entries.map((entry) {
                  final i = entry.key;
                  final t = entry.value;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: i.isEven
                          ? const PdfColor.fromInt(AppConstants.lightOrangeValue)
                          : PdfColors.white,
                    ),
                    children: [
                      _pdfCell(t.userName, fontSize: 9),
                      _pdfCell(t.itemName, fontSize: 9),
                      _pdfCell(t.transactionType, fontSize: 9),
                      _pdfCell(t.displayQtyLabel, fontSize: 9),
                      _pdfCell(
                          _dateFormat.format(t.checkOutDate.toLocal()),
                          fontSize: 9),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 24),
          ],

          // ── Non-consumable transactions ────────────
          if (nonConsumableTxs.isNotEmpty) ...[
            _pdfSectionTitle('Non-Consumable Transactions (Issued / Returned)'),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FlexColumnWidth(2),
                5: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(AppConstants.primaryColorValue)),
                  children: [
                    _pdfCell('User',      isHeader: true),
                    _pdfCell('Item',      isHeader: true),
                    _pdfCell('Type',      isHeader: true),
                    _pdfCell('Issued At', isHeader: true),
                    _pdfCell('Returned',  isHeader: true),
                    _pdfCell('Duration',  isHeader: true),
                  ],
                ),
                ...nonConsumableTxs.asMap().entries.map((entry) {
                  final i        = entry.key;
                  final t        = entry.value;
                  final duration = t.checkInDate != null
                      ? _calcDuration(t.checkOutDate, t.checkInDate!)
                      : 'Still Out';
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: i.isEven
                          ? const PdfColor.fromInt(AppConstants.lightOrangeValue)
                          : PdfColors.white,
                    ),
                    children: [
                      _pdfCell(t.userName, fontSize: 9),
                      _pdfCell(t.itemName, fontSize: 9),
                      _pdfCell(t.transactionType, fontSize: 9),
                      _pdfCell(
                          _dateFormat.format(t.checkOutDate.toLocal()),
                          fontSize: 9),
                      _pdfCell(
                        t.checkInDate != null
                            ? _dateFormat.format(t.checkInDate!.toLocal())
                            : '—',
                        fontSize: 9,
                      ),
                      _pdfCell(duration, fontSize: 9),
                    ],
                  );
                }),
              ],
            ),
          ],
        ],
      ),
    );

    if (download) {
      await _downloadPdf(context, pdf, 'item_transactions');
    } else {
      await _sharePdf(context, pdf, 'item_transactions');
    }
  }

  static Future<void> exportItemTransactionsToExcel(
    BuildContext context,
    List<ItemTransactionModel> transactions, {
    bool download = false,
  }) async {
    final excel = Excel.createExcel();

    // ── Sheet 1: All Transactions ──────────────────
    final allSheet = excel['All Transactions'];
    excel.setDefaultSheet('All Transactions');
    _excelHeader(allSheet, [
      'User Name', 'Item Name', 'Transaction Type', 'Quantity',
      'Date', 'Check-In Date', 'Duration', 'Status',
    ]);

    for (final t in transactions) {
      final duration = t.checkInDate != null
          ? _calcDuration(t.checkOutDate, t.checkInDate!)
          : 'Still Out';
      allSheet.appendRow([
        TextCellValue(t.userName),
        TextCellValue(t.itemName),
        TextCellValue(t.transactionType),
        TextCellValue(t.displayQtyLabel),
        TextCellValue(_dateFormat.format(t.checkOutDate.toLocal())),
        TextCellValue(
          t.checkInDate != null
              ? _dateFormat.format(t.checkInDate!.toLocal())
              : '—',
        ),
        TextCellValue(duration),
        TextCellValue(t.status ?? '—'),
      ]);
    }
    _autoWidthHint(allSheet, 8);

    // ── Sheet 2: Consumable Only ───────────────────
    final consumableTxs = transactions
        .where((t) =>
            t.transactionType == 'StockIn' ||
            t.transactionType == 'StockOut')
        .toList();

    if (consumableTxs.isNotEmpty) {
      final cSheet = excel['Consumable Transactions'];
      _excelHeader(cSheet, [
        'User Name', 'Item Name', 'Transaction Type',
        'Quantity', 'Date',
      ]);

      for (final t in consumableTxs) {
        cSheet.appendRow([
          TextCellValue(t.userName),
          TextCellValue(t.itemName),
          TextCellValue(t.transactionType),
          TextCellValue(t.displayQtyLabel),
          TextCellValue(_dateFormat.format(t.checkOutDate.toLocal())),
        ]);
      }
      _autoWidthHint(cSheet, 5);
    }

    // ── Sheet 3: Non-Consumable Only ───────────────
    final nonConsumableTxs = transactions
        .where((t) =>
            t.transactionType == 'Issued' ||
            t.transactionType == 'Returned')
        .toList();

    if (nonConsumableTxs.isNotEmpty) {
      final ncSheet = excel['Non-Consumable Transactions'];
      _excelHeader(ncSheet, [
        'User Name', 'Item Name', 'Transaction Type',
        'Issued At', 'Returned At', 'Duration', 'Status',
      ]);

      for (final t in nonConsumableTxs) {
        final duration = t.checkInDate != null
            ? _calcDuration(t.checkOutDate, t.checkInDate!)
            : 'Still Out';
        ncSheet.appendRow([
          TextCellValue(t.userName),
          TextCellValue(t.itemName),
          TextCellValue(t.transactionType),
          TextCellValue(_dateFormat.format(t.checkOutDate.toLocal())),
          TextCellValue(
            t.checkInDate != null
                ? _dateFormat.format(t.checkInDate!.toLocal())
                : '—',
          ),
          TextCellValue(duration),
          TextCellValue(t.status ?? '—'),
        ]);
      }
      _autoWidthHint(ncSheet, 7);
    }

    excel.delete('Sheet1');

    if (download) {
      await _downloadExcel(context, excel, 'item_transactions');
    } else {
      await _shareExcel(context, excel, 'item_transactions');
    }
  }

  // ════════════════════════════════════════════════════
  //  PRIVATE — PDF helpers
  // ════════════════════════════════════════════════════

  static pw.Widget _pdfHeader(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
              color: PdfColor.fromInt(AppConstants.primaryColorValue), width: 2),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize:   16,
              fontWeight: pw.FontWeight.bold,
              color:      const PdfColor.fromInt(AppConstants.primaryColorValue),
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
        border: pw.Border(
            top: pw.BorderSide(color: PdfColors.grey300)),
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

  static pw.Widget _pdfSectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const pw.BoxDecoration(
        color: PdfColor.fromInt(AppConstants.primaryColorValue),
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          color:      PdfColors.white,
          fontWeight: pw.FontWeight.bold,
          fontSize:   11,
        ),
      ),
    );
  }

  static pw.Widget _pdfCell(
    String text, {
    bool   isHeader = false,
    double fontSize = 10,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize:   fontSize,
          fontWeight: isHeader
              ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : PdfColors.black,
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════
  //  PRIVATE — Excel helpers
  // ════════════════════════════════════════════════════

  static void _excelHeader(Sheet sheet, List<String> headers) {
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value      = TextCellValue(headers[i]);
      cell.cellStyle  = CellStyle(
        bold:                true,
        backgroundColorHex:  ExcelColor.fromInt(AppConstants.primaryColorValue),
        fontColorHex:        ExcelColor.fromHexString('#FFFFFF'),
      );
    }
  }

  static void _autoWidthHint(Sheet sheet, int colCount) {
    for (int i = 0; i < colCount; i++) {
      sheet.setColumnWidth(i, 22);
    }
  }

  // ════════════════════════════════════════════════════
  //  PRIVATE — Share (temp dir + share sheet)
  // ════════════════════════════════════════════════════

  static Future<void> _sharePdf(
    BuildContext context,
    pw.Document pdf,
    String prefix,
  ) async {
    final bytes    = await pdf.save();
    final dir      = await getTemporaryDirectory();
    final filename = '${prefix}_${_fileDateFormat.format(DateTime.now())}.pdf';
    final file     = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], subject: filename);
  }

  static Future<void> _shareExcel(
    BuildContext context,
    Excel excel,
    String prefix,
  ) async {
    final bytes = excel.encode();
    if (bytes == null) return;
    final dir      = await getTemporaryDirectory();
    final filename =
        '${prefix}_${_fileDateFormat.format(DateTime.now())}.xlsx';
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], subject: filename);
  }

  // ════════════════════════════════════════════════════
  //  PRIVATE — Download (public Downloads folder)
  //  Works on Android 10+ without extra permissions.
  //  On Android 9 and below add WRITE_EXTERNAL_STORAGE
  //  to your AndroidManifest.xml.
  // ════════════════════════════════════════════════════

  static Future<void> _downloadPdf(
    BuildContext context,
    pw.Document pdf,
    String prefix,
  ) async {
    final bytes    = await pdf.save();
    final filename =
        '${prefix}_${_fileDateFormat.format(DateTime.now())}.pdf';
    final file     = await _downloadsFile(filename);
    await file.writeAsBytes(bytes);
    _showDownloadSnack(context, filename);
  }

  static Future<void> _downloadExcel(
    BuildContext context,
    Excel excel,
    String prefix,
  ) async {
    final bytes = excel.encode();
    if (bytes == null) return;
    final filename =
        '${prefix}_${_fileDateFormat.format(DateTime.now())}.xlsx';
    final file = await _downloadsFile(filename);
    await file.writeAsBytes(bytes);
    _showDownloadSnack(context, filename);
  }

  /// Resolves the public Downloads directory on Android.
  /// Falls back to the app's external storage dir if unavailable.
  static Future<File> _downloadsFile(String filename) async {
    // /storage/emulated/0/Download  — works on Android 10+
    const downloadsPath = '/storage/emulated/0/Download';
    final downloadsDir  = Directory(downloadsPath);

    if (await downloadsDir.exists()) {
      return File('$downloadsPath/$filename');
    }

    // Fallback: app-specific external directory
    final extDir = await getExternalStorageDirectory();
    final fallbackDir = Directory(
        '${extDir?.path ?? (await getTemporaryDirectory()).path}/Download');
    if (!await fallbackDir.exists()) {
      await fallbackDir.create(recursive: true);
    }
    return File('${fallbackDir.path}/$filename');
  }

  static void _showDownloadSnack(BuildContext context, String filename) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.download_done_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Saved to Downloads: $filename',
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1565C0),
        duration:        const Duration(seconds: 4),
        behavior:        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ════════════════════════════════════════════════════
  //  PRIVATE — General utilities
  // ════════════════════════════════════════════════════

  static String _calcDuration(DateTime start, DateTime end) {
    final diff = end.difference(start);
    if (diff.inDays > 0)
      return '${diff.inDays}d ${diff.inHours.remainder(24)}h';
    if (diff.inHours > 0)
      return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return '${diff.inSeconds}s';
  }

  static String _fmtDouble(double v) =>
      v == v.truncateToDouble()
          ? v.toInt().toString()
          : v.toStringAsFixed(1);
}