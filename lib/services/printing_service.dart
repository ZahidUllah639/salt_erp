import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/erp_models.dart';
import '../models/party.dart';
import '../models/ledger_entry.dart';

class PrinterDevice {
  final String name;
  final bool isDefault;

  const PrinterDevice({required this.name, this.isDefault = false});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrinterDevice && runtimeType == other.runtimeType && name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name;
}

class PrintResult {
  final bool success;
  final String message;
  final bool isCancelled;
  final String? filePath;

  const PrintResult({
    required this.success,
    required this.message,
    this.isCancelled = false,
    this.filePath,
  });

  factory PrintResult.ok([String msg = 'Printed successfully', String? path]) =>
      PrintResult(success: true, message: msg, filePath: path);

  factory PrintResult.cancelled([String msg = 'Print job was cancelled']) =>
      PrintResult(success: false, message: msg, isCancelled: true);

  factory PrintResult.fail(String error) =>
      PrintResult(success: false, message: error);
}

class PrintingService {
  PrintingService._();
  static final PrintingService instance = PrintingService._();

  // =========================================================================
  // PRINTER ENUMERATION & DIAGNOSTICS
  // =========================================================================

  Future<List<PrinterDevice>> getAvailablePrinters() async {
    try {
      if (Platform.isWindows) {
        final res = await Process.run(
          'powershell',
          ['-NoProfile', '-Command', 'Get-CimInstance Win32_Printer | Select-Object Name, Default | ConvertTo-Json'],
        );
        if (res.exitCode == 0 && res.stdout.toString().trim().isNotEmpty) {
          final decoded = jsonDecode(res.stdout.toString());
          if (decoded is List) {
            return decoded.map((m) => PrinterDevice(
              name: m['Name'].toString(),
              isDefault: m['Default'] == true,
            )).toList();
          } else if (decoded is Map) {
            return [
              PrinterDevice(
                name: decoded['Name'].toString(),
                isDefault: decoded['Default'] == true,
              ),
            ];
          }
        }
      }
    } catch (e) {
      debugPrint('Printer enumeration notice: $e');
    }
    return const [
      PrinterDevice(name: 'Microsoft Print to PDF', isDefault: true),
      PrinterDevice(name: 'Xprinter XP-Q200 Thermal', isDefault: false),
    ];
  }

  // =========================================================================
  // THERMAL RECEIPT PDF BUILDER (58 mm & 80 mm)
  // =========================================================================

  Future<Uint8List> generateThermalReceiptPdf(
    ReceiptData receipt, {
    String paperWidth = '80',
  }) async {
    final is80 = paperWidth == '80';
    // 58 mm roll is ~164 pt; 80 mm roll is ~226 pt
    final rollWidth = is80 ? (80.0 * PdfPageFormat.mm) : (58.0 * PdfPageFormat.mm);
    final margin = is80 ? (3.5 * PdfPageFormat.mm) : (2.0 * PdfPageFormat.mm);

    final pdf = pw.Document();

    final bodyFontSize = is80 ? 7.5 : 6.2;
    final titleFontSize = is80 ? 12.0 : 10.0;
    final headerFontSize = is80 ? 8.5 : 7.0;
    final grandTotalFontSize = is80 ? 10.5 : 8.5;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(rollWidth, double.infinity, marginAll: margin),
        build: (pw.Context context) {
          return pw.DefaultTextStyle(
            style: pw.TextStyle(
              font: pw.Font.courier(),
              fontSize: bodyFontSize,
              lineSpacing: 1.2,
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Factory Brand Header
                pw.Center(
                  child: pw.Text(
                    receipt.businessName.toUpperCase(),
                    style: pw.TextStyle(
                      font: pw.Font.courierBold(),
                      fontSize: titleFontSize,
                    ),
                  ),
                ),
                pw.SizedBox(height: 1),
                pw.Center(
                  child: pw.Text(
                    receipt.businessAddress,
                    style: pw.TextStyle(fontSize: bodyFontSize - 0.5),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    'Phone: ${receipt.businessPhone}',
                    style: pw.TextStyle(fontSize: bodyFontSize - 0.5),
                  ),
                ),
                pw.SizedBox(height: 4),

                // Dashed divider
                _buildDashedLine(is80 ? 46 : 32),
                pw.SizedBox(height: 3),

                // Receipt Title
                pw.Center(
                  child: pw.Text(
                    receipt.title.toUpperCase(),
                    style: pw.TextStyle(
                      font: pw.Font.courierBold(),
                      fontSize: headerFontSize,
                    ),
                  ),
                ),

                // Reprint Banner (Audited)
                if (receipt.isReprint) ...[
                  pw.SizedBox(height: 2),
                  pw.Center(
                    child: pw.Text(
                      '*** REPRINT - AUDIT VERIFIED ***',
                      style: pw.TextStyle(
                        font: pw.Font.courierBold(),
                        fontSize: bodyFontSize - 0.5,
                      ),
                    ),
                  ),
                ],

                pw.SizedBox(height: 3),
                _buildDashedLine(is80 ? 46 : 32),
                pw.SizedBox(height: 4),

                // Transaction Meta
                _buildMetaRow('Receipt #', receipt.referenceNo, bodyFontSize),
                _buildMetaRow('Date & Time', receipt.dateTime, bodyFontSize),
                if (receipt.partyName != null && receipt.partyName!.isNotEmpty)
                  _buildMetaRow(receipt.partyLabel ?? 'Party', receipt.partyName!, bodyFontSize),
                if (receipt.partyPhone != null && receipt.partyPhone!.isNotEmpty)
                  _buildMetaRow('Phone', receipt.partyPhone!, bodyFontSize),
                if (receipt.paymentMethod != null && receipt.paymentMethod!.isNotEmpty)
                  _buildMetaRow('Payment Wallet', receipt.paymentMethod!, bodyFontSize),
                if (receipt.sourceWalletName != null)
                  _buildMetaRow('Source Wallet', receipt.sourceWalletName!, bodyFontSize),
                if (receipt.destinationWalletName != null)
                  _buildMetaRow('Destination Wallet', receipt.destinationWalletName!, bodyFontSize),

                pw.SizedBox(height: 4),
                _buildDashedLine(is80 ? 46 : 32),
                pw.SizedBox(height: 4),

                // Itemized Table (if items exist)
                if (receipt.items.isNotEmpty) ...[
                  // Table Header
                  pw.Row(
                    children: [
                      pw.Expanded(
                        flex: is80 ? 5 : 4,
                        child: pw.Text(
                          'ITEM',
                          style: pw.TextStyle(font: pw.Font.courierBold(), fontSize: bodyFontSize),
                        ),
                      ),
                      pw.SizedBox(
                        width: is80 ? 32 : 24,
                        child: pw.Text(
                          'QTY',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(font: pw.Font.courierBold(), fontSize: bodyFontSize),
                        ),
                      ),
                      if (is80)
                        pw.SizedBox(
                          width: 38,
                          child: pw.Text(
                            'RATE',
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(font: pw.Font.courierBold(), fontSize: bodyFontSize),
                          ),
                        ),
                      pw.SizedBox(
                        width: is80 ? 46 : 38,
                        child: pw.Text(
                          'TOTAL',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(font: pw.Font.courierBold(), fontSize: bodyFontSize),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  _buildDashedLine(is80 ? 46 : 32),
                  pw.SizedBox(height: 3),

                  // Item Rows
                  ...receipt.items.map((item) {
                    final qtyStr = '${item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toStringAsFixed(2)} ${item.unit}'.trim();
                    final rateStr = item.unitPrice.toStringAsFixed(0);
                    final totalStr = item.totalAmount.toStringAsFixed(0);

                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            flex: is80 ? 5 : 4,
                            child: pw.Text(item.description, style: pw.TextStyle(fontSize: bodyFontSize)),
                          ),
                          pw.SizedBox(
                            width: is80 ? 32 : 24,
                            child: pw.Text(
                              qtyStr,
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(fontSize: bodyFontSize),
                            ),
                          ),
                          if (is80)
                            pw.SizedBox(
                              width: 38,
                              child: pw.Text(
                                rateStr,
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(fontSize: bodyFontSize),
                              ),
                            ),
                          pw.SizedBox(
                            width: is80 ? 46 : 38,
                            child: pw.Text(
                              totalStr,
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(fontSize: bodyFontSize),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  pw.SizedBox(height: 4),
                  _buildDashedLine(is80 ? 46 : 32),
                  pw.SizedBox(height: 4),
                ],

                // Financial Totals
                if (receipt.subtotal > 0 && receipt.items.isNotEmpty)
                  _buildMetaRow('Subtotal', 'Rs ${receipt.subtotal.toStringAsFixed(0)}', bodyFontSize),
                if (receipt.discount > 0)
                  _buildMetaRow('Discount', '- Rs ${receipt.discount.toStringAsFixed(0)}', bodyFontSize),
                if (receipt.tax > 0)
                  _buildMetaRow('Tax', '+ Rs ${receipt.tax.toStringAsFixed(0)}', bodyFontSize),

                // Grand Total Box
                pw.SizedBox(height: 2),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border.symmetric(
                      horizontal: pw.BorderSide(color: PdfColors.black, width: 1.2),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'GRAND TOTAL',
                        style: pw.TextStyle(
                          font: pw.Font.courierBold(),
                          fontSize: grandTotalFontSize,
                        ),
                      ),
                      pw.Text(
                        'Rs ${receipt.grandTotal.toStringAsFixed(0)}',
                        style: pw.TextStyle(
                          font: pw.Font.courierBold(),
                          fontSize: grandTotalFontSize,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 3),

                // Paid & Outstanding
                if (receipt.paidAmount > 0 || receipt.outstandingAmount > 0) ...[
                  _buildMetaRow('Paid Amount', 'Rs ${receipt.paidAmount.toStringAsFixed(0)}', bodyFontSize),
                  _buildMetaRow(
                    'Outstanding',
                    'Rs ${receipt.outstandingAmount.toStringAsFixed(0)}',
                    bodyFontSize,
                    isBold: receipt.outstandingAmount > 0,
                  ),
                ],

                // Ledger Balance
                if (receipt.partyBalance != null && receipt.partyBalance!.isNotEmpty) ...[
                  pw.SizedBox(height: 3),
                  _buildDashedLine(is80 ? 46 : 32),
                  pw.SizedBox(height: 3),
                  pw.Center(
                    child: pw.Text(
                      'Account Balance: ${receipt.partyBalance}',
                      style: pw.TextStyle(
                        font: pw.Font.courierBold(),
                        fontSize: bodyFontSize,
                      ),
                    ),
                  ),
                ],

                // Notes
                if (receipt.notes != null && receipt.notes!.isNotEmpty) ...[
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Note: ${receipt.notes}',
                    style: pw.TextStyle(fontSize: bodyFontSize - 0.5),
                  ),
                ],

                // Footer
                pw.SizedBox(height: 6),
                _buildDashedLine(is80 ? 46 : 32),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    'Thank you for your business!',
                    style: pw.TextStyle(fontSize: bodyFontSize),
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Center(
                  child: pw.Text(
                    'System generated slip | Anwar Salt Factory ERP',
                    style: pw.TextStyle(fontSize: bodyFontSize - 1.2),
                  ),
                ),
                pw.SizedBox(height: 10),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  // =========================================================================
  // A4 / A5 REPORT PDF BUILDER
  // =========================================================================

  Future<Uint8List> generateReportPdf(
    ReportData report, {
    PdfPageFormat pageFormat = PdfPageFormat.a4,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(28),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'ANWAR SALT FACTORY',
                        style: pw.TextStyle(
                          font: pw.Font.helveticaBold(),
                          fontSize: 16,
                          color: PdfColor.fromHex('#0E1726'),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Industrial Area, Khewra | Salt Manufacturing & Distribution',
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColor.fromHex('#64748B'),
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'OFFICIAL REPORT',
                        style: pw.TextStyle(
                          font: pw.Font.helveticaBold(),
                          fontSize: 10,
                          color: PdfColor.fromHex('#2563EB'),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Date: ${DateTime.now().toString().substring(0, 16)}',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          color: PdfColor.fromHex('#64748B'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                height: 2,
                color: PdfColor.fromHex('#2563EB'),
              ),
              pw.SizedBox(height: 10),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Anwar Salt Factory ERP | Financial & Operational Audited Report',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // Title & Subtitle Banner
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8FAFC'),
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        report.title,
                        style: pw.TextStyle(
                          font: pw.Font.helveticaBold(),
                          fontSize: 13,
                          color: PdfColor.fromHex('#0F172A'),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        report.subtitle,
                        style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#475569')),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#EFF6FF'),
                      borderRadius: pw.BorderRadius.circular(4),
                      border: pw.Border.all(color: PdfColor.fromHex('#BFDBFE')),
                    ),
                    child: pw.Text(
                      'Period: ${report.dateRange}',
                      style: pw.TextStyle(
                        font: pw.Font.helveticaBold(),
                        fontSize: 9,
                        color: PdfColor.fromHex('#1E40AF'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Summary Metric Cards
            if (report.summaryMetrics.isNotEmpty) ...[
              pw.Row(
                children: report.summaryMetrics.entries.map((entry) {
                  return pw.Expanded(
                    child: pw.Container(
                      margin: const pw.EdgeInsets.only(right: 8),
                      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(5),
                        border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            entry.key.toUpperCase(),
                            style: pw.TextStyle(
                              fontSize: 7.5,
                              font: pw.Font.helveticaBold(),
                              color: PdfColor.fromHex('#64748B'),
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            entry.value,
                            style: pw.TextStyle(
                              fontSize: 12,
                              font: pw.Font.helveticaBold(),
                              color: PdfColor.fromHex('#0F172A'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              pw.SizedBox(height: 14),
            ],

            // Data Table
            pw.TableHelper.fromTextArray(
              context: context,
              headers: report.columnHeaders,
              data: report.rows.map((row) => row.map((c) => c.replaceAll('—', '-').replaceAll('•', '|')).toList()).toList(),
              headerStyle: pw.TextStyle(
                font: pw.Font.helveticaBold(),
                fontSize: 8.5,
                color: PdfColors.white,
              ),
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#1E293B'),
              ),
              headerHeight: 24,
              cellHeight: 20,
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignments: _buildCellAlignments(report),
              rowDecoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColor.fromHex('#F1F5F9'), width: 0.8),
                ),
              ),
              oddRowDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8FAFC'),
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColor.fromHex('#F1F5F9'), width: 0.8),
                ),
              ),
            ),

            // Optional Totals Row
            if (report.totalsRow != null) ...[
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F1F5F9'),
                  border: pw.Border.symmetric(
                    horizontal: pw.BorderSide(color: PdfColor.fromHex('#94A3B8'), width: 1.2),
                  ),
                ),
                child: pw.Row(
                  children: List.generate(report.totalsRow!.length, (idx) {
                    final align = idx < report.columnAlignments.length ? report.columnAlignments[idx] : 'left';
                    final textAlign = align == 'right'
                        ? pw.TextAlign.right
                        : align == 'center'
                            ? pw.TextAlign.center
                            : pw.TextAlign.left;

                    final cellText = report.totalsRow![idx].replaceAll('—', '-');
                    return pw.Expanded(
                      child: pw.Text(
                        cellText,
                        textAlign: textAlign,
                        style: pw.TextStyle(
                          font: pw.Font.helveticaBold(),
                          fontSize: 8.5,
                          color: PdfColor.fromHex('#0F172A'),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],

            // Verification & Signatures Block
            pw.SizedBox(height: 36),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildSignatureLine('Prepared By (Accounts Officer)'),
                _buildSignatureLine('Verified By (Internal Auditor)'),
                _buildSignatureLine('Authorized Signature (Manager)'),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // =========================================================================
  // ACTIONS: PRINT, PREVIEW & EXPORT WITH ERROR HANDLING
  // =========================================================================

  Future<PrintResult> printThermalReceipt(
    ReceiptData receipt, {
    String paperWidth = '80',
    PrinterDevice? printer,
  }) async {
    try {
      final pdfBytes = await generateThermalReceiptPdf(receipt, paperWidth: paperWidth);
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/receipt_${receipt.referenceNo}.pdf');
      await file.writeAsBytes(pdfBytes);

      if (Platform.isWindows) {
        if (printer != null && !printer.name.toLowerCase().contains('pdf')) {
          await Process.run('powershell', [
            '-NoProfile',
            '-Command',
            'Start-Process -FilePath "${file.path}" -Verb PrintTo -ArgumentList \'"${printer.name}"\'',
          ]);
        } else {
          await Process.run('powershell', [
            '-NoProfile',
            '-Command',
            'Start-Process -FilePath "${file.path}" -Verb Print',
          ]);
        }
        return PrintResult.ok('Receipt sent to ${printer?.name ?? "default printer"}', file.path);
      } else {
        return PrintResult.ok('Receipt PDF created successfully', file.path);
      }
    } catch (e) {
      debugPrint('Printing error: $e');
      return PrintResult.fail(e.toString());
    }
  }

  Future<PrintResult> printReport(
    ReportData report, {
    PrinterDevice? printer,
  }) async {
    try {
      final pdfBytes = await generateReportPdf(report);
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(pdfBytes);

      if (Platform.isWindows) {
        if (printer != null && !printer.name.toLowerCase().contains('pdf')) {
          await Process.run('powershell', [
            '-NoProfile',
            '-Command',
            'Start-Process -FilePath "${file.path}" -Verb PrintTo -ArgumentList \'"${printer.name}"\'',
          ]);
        } else {
          await Process.run('powershell', [
            '-NoProfile',
            '-Command',
            'Start-Process -FilePath "${file.path}" -Verb Print',
          ]);
        }
        return PrintResult.ok('Report sent to ${printer?.name ?? "default printer"}', file.path);
      } else {
        return PrintResult.ok('Report PDF created successfully', file.path);
      }
    } catch (e) {
      debugPrint('Report print error: $e');
      return PrintResult.fail(e.toString());
    }
  }

  Future<PrintResult> exportReceiptPdf(
    ReceiptData receipt, {
    String paperWidth = '80',
  }) async {
    try {
      final pdfBytes = await generateThermalReceiptPdf(receipt, paperWidth: paperWidth);
      final filename = '${receipt.referenceNo}_receipt.pdf';

      Directory? dir;
      try {
        dir = await getApplicationDocumentsDirectory();
      } catch (_) {
        dir = Directory.systemTemp;
      }

      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(pdfBytes);

      return PrintResult.ok('Receipt saved to ${file.path}', file.path);
    } catch (e) {
      return PrintResult.fail('Export error: $e');
    }
  }

  Future<PrintResult> exportReportPdf(ReportData report) async {
    try {
      final pdfBytes = await generateReportPdf(report);
      final filename = '${report.title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      Directory? dir;
      try {
        dir = await getApplicationDocumentsDirectory();
      } catch (_) {
        dir = Directory.systemTemp;
      }

      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(pdfBytes);

      return PrintResult.ok('Report saved to ${file.path}', file.path);
    } catch (e) {
      return PrintResult.fail('Report export error: $e');
    }
  }

  // =========================================================================
  // WORKFLOW CONVERTERS (RECEIPTS FROM DOMAIN TRANSACTIONS)
  // =========================================================================

  ReceiptData receiptFromSale(
    Sale sale, {
    Party? customer,
    Wallet? wallet,
    bool isReprint = false,
  }) {
    final items = sale.items.map((i) {
      return ReceiptLineItem(
        description: 'Product #${i.productId}',
        quantity: i.quantity,
        unit: 'pkts',
        unitPrice: i.unitPrice,
        totalAmount: i.totalPrice,
      );
    }).toList();

    return ReceiptData(
      title: 'SALES RECEIPT',
      referenceNo: sale.saleNo,
      dateTime: sale.saleDate,
      partyLabel: 'Customer',
      partyName: customer?.name ?? 'Customer #${sale.customerId}',
      partyPhone: customer?.phone,
      partyBalance: customer != null ? 'Rs ${customer.currentBalance.toStringAsFixed(0)} ${customer.currentBalance >= 0 ? "Dr" : "Cr"}' : null,
      paymentMethod: wallet?.name ?? (sale.paidAmount > 0 ? 'Cash/Bank' : '100% Credit'),
      items: items,
      subtotal: sale.totalAmount,
      grandTotal: sale.totalAmount,
      paidAmount: sale.paidAmount,
      outstandingAmount: sale.outstandingAmount,
      notes: sale.notes ?? 'Official delivery receipt.',
      isReprint: isReprint,
    );
  }

  ReceiptData receiptFromPurchase(
    Purchase purchase, {
    Party? supplier,
    Wallet? wallet,
    bool isReprint = false,
  }) {
    final items = purchase.items.map((i) {
      return ReceiptLineItem(
        description: 'Item #${i.productId}',
        quantity: i.quantity,
        unit: 'kg',
        unitPrice: i.unitCost,
        totalAmount: i.totalCost,
      );
    }).toList();

    return ReceiptData(
      title: 'PURCHASE VOUCHER',
      referenceNo: purchase.purchaseNo,
      dateTime: purchase.purchaseDate,
      partyLabel: 'Supplier',
      partyName: supplier?.name ?? 'Supplier #${purchase.supplierId}',
      partyPhone: supplier?.phone,
      partyBalance: supplier != null ? 'Rs ${supplier.currentBalance.toStringAsFixed(0)} ${supplier.currentBalance >= 0 ? "Cr" : "Dr"}' : null,
      paymentMethod: wallet?.name ?? (purchase.paidAmount > 0 ? 'Disbursed' : 'Unpaid Credit'),
      items: items,
      subtotal: purchase.totalAmount,
      grandTotal: purchase.totalAmount,
      paidAmount: purchase.paidAmount,
      outstandingAmount: purchase.outstandingAmount,
      notes: purchase.notes ?? 'Goods received & verified at factory gate.',
      isReprint: isReprint,
    );
  }

  ReceiptData receiptFromDailyRecord(
    DailyRecord record, {
    Party? party,
    Wallet? sourceWallet,
    Wallet? destWallet,
    bool isReprint = false,
  }) {
    String title = 'TRANSACTION VOUCHER';
    String? partyLabel;
    if (record.recordType == 'Customer Collection') {
      title = 'CUSTOMER COLLECTION VOUCHER';
      partyLabel = 'Customer';
    } else if (record.recordType == 'Supplier Payment') {
      title = 'SUPPLIER PAYMENT VOUCHER';
      partyLabel = 'Supplier';
    } else if (record.recordType == 'Expense') {
      title = 'EXPENSE PAYMENT SLIP';
      partyLabel = 'Expense Category';
    } else if (record.recordType == 'Income') {
      title = 'DIRECT INCOME RECEIPT';
      partyLabel = 'Source';
    } else if (record.recordType == 'Wallet Transfer') {
      title = 'INTER-WALLET TRANSFER SLIP';
    } else if (record.recordType == 'Stock Adjustment') {
      title = 'STOCK ADJUSTMENT SLIP';
    }

    return ReceiptData(
      title: title,
      referenceNo: record.recordNo,
      dateTime: record.recordDate,
      partyLabel: partyLabel,
      partyName: party?.name ?? record.category,
      partyPhone: party?.phone,
      partyBalance: party != null ? 'Rs ${party.currentBalance.toStringAsFixed(0)}' : null,
      paymentMethod: destWallet?.name ?? sourceWallet?.name,
      sourceWalletName: sourceWallet?.name,
      destinationWalletName: destWallet?.name,
      grandTotal: record.amount,
      paidAmount: record.amount,
      outstandingAmount: 0.0,
      notes: '${record.description} - ${record.notes ?? ""}'.trim(),
      isReprint: isReprint,
    );
  }

  ReceiptData receiptFromPartyStatement(
    Party party,
    List<LedgerEntry> entries, {
    bool isReprint = false,
  }) {
    final recentEntries = entries.take(15).toList();
    final items = recentEntries.map((e) {
      final amt = e.debit > 0 ? e.debit : e.credit;
      return ReceiptLineItem(
        description: '${e.entryDate.length >= 10 ? e.entryDate.substring(0, 10) : e.entryDate} ${e.referenceNo}: ${e.description}',
        quantity: 1,
        unit: '',
        unitPrice: amt,
        totalAmount: amt,
      );
    }).toList();

    return ReceiptData(
      title: '${party.type.toUpperCase()} ACCOUNT STATEMENT',
      referenceNo: 'STMT-${party.id ?? 0}-${DateTime.now().millisecondsSinceEpoch % 10000}',
      dateTime: DateTime.now().toString().substring(0, 16),
      partyLabel: party.type,
      partyName: party.name,
      partyPhone: party.phone,
      partyBalance: 'Rs ${party.currentBalance.toStringAsFixed(0)} ${party.currentBalance >= 0 ? "Dr" : "Cr"}',
      items: items,
      grandTotal: party.currentBalance.abs(),
      outstandingAmount: party.currentBalance,
      notes: 'Statement reflects confirmed posted transactions only.',
      isReprint: isReprint,
    );
  }

  // =========================================================================
  // PRIVATE PDF HELPERS
  // =========================================================================

  pw.Widget _buildDashedLine(int length) {
    return pw.Center(
      child: pw.Text(
        '-' * length,
        style: pw.TextStyle(
          font: pw.Font.courier(),
          fontSize: 7,
          color: PdfColors.black,
        ),
      ),
    );
  }

  pw.Widget _buildMetaRow(String label, String value, double fontSize, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.0),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: fontSize),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: isBold ? pw.Font.courierBold() : pw.Font.courier(),
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }

  Map<int, pw.Alignment> _buildCellAlignments(ReportData report) {
    final map = <int, pw.Alignment>{};
    for (int i = 0; i < report.columnAlignments.length; i++) {
      final a = report.columnAlignments[i];
      if (a == 'right') {
        map[i] = pw.Alignment.centerRight;
      } else if (a == 'center') {
        map[i] = pw.Alignment.center;
      } else {
        map[i] = pw.Alignment.centerLeft;
      }
    }
    return map;
  }

  pw.Widget _buildSignatureLine(String label) {
    return pw.Column(
      children: [
        pw.Container(
          width: 140,
          height: 1,
          color: PdfColor.fromHex('#94A3B8'),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 7.5,
            color: PdfColor.fromHex('#64748B'),
          ),
        ),
      ],
    );
  }
}
