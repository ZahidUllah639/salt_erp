import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/erp_models.dart';
import '../services/printing_service.dart';
import 'app_components.dart';
import 'app_icons.dart';

class ReceiptModal extends StatefulWidget {
  final VoidCallback onClose;
  final ReceiptData? receiptData;

  const ReceiptModal({
    super.key,
    required this.onClose,
    this.receiptData,
  });

  @override
  State<ReceiptModal> createState() => _ReceiptModalState();
}

class _ReceiptModalState extends State<ReceiptModal> {
  String _paperWidth = '80'; // '58' or '80'
  bool _isLoadingPrinters = true;
  List<PrinterDevice> _printers = [];
  PrinterDevice? _selectedPrinter;
  bool _isProcessing = false;
  String? _statusMessage;
  bool _isError = false;

  late ReceiptData _data;

  @override
  void initState() {
    super.initState();
    _data = widget.receiptData ?? ReceiptData.sampleSalesReceipt();
    _loadPrinters();
  }

  Future<void> _loadPrinters() async {
    try {
      final list = await PrintingService.instance.getAvailablePrinters();
      if (mounted) {
        setState(() {
          _printers = list;
          if (list.isNotEmpty) {
            _selectedPrinter = list.firstWhere(
              (p) => p.name.toLowerCase().contains('xp') || p.name.toLowerCase().contains('thermal') || p.isDefault,
              orElse: () => list.first,
            );
          }
          _isLoadingPrinters = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPrinters = false);
    }
  }

  Future<void> _handlePrint() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = null;
      _isError = false;
    });

    final result = await PrintingService.instance.printThermalReceipt(
      _data,
      paperWidth: _paperWidth,
      printer: _selectedPrinter,
    );

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _isError = !result.success && !result.isCancelled;
        _statusMessage = result.message;
      });

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (!result.isCancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print failed: ${result.message}'),
            backgroundColor: AppColors.danger,
            action: SnackBarAction(
              label: 'Save PDF',
              textColor: Colors.white,
              onPressed: _handleExportPdf,
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleExportPdf() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = null;
      _isError = false;
    });

    final result = await PrintingService.instance.exportReceiptPdf(
      _data,
      paperWidth: _paperWidth,
    );

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _isError = !result.success;
        _statusMessage = result.message;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? AppColors.success : AppColors.danger,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final is80 = _paperWidth == '80';
    final paperWidthPx = is80 ? 302.0 : 220.0;
    final paperPadding = is80 ? 18.0 : 12.0;
    final itemFontSize = is80 ? 7.5 : 6.2;

    return Material(
      color: Colors.transparent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Backdrop with smooth fade
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: AppMotion.duration(context, AppMotion.fast),
            curve: AppMotion.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    color: const Color(0xFF0A1220).withAlpha(143),
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              );
            },
          ),
          // Dialog Card with smooth entrance scale and fade
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: AppMotion.duration(context, AppMotion.normal),
            curve: AppMotion.easeOut,
            builder: (context, value, child) {
              if (AppMotion.isReducedMotion(context)) return child!;
              return Opacity(
                opacity: value,
                child: Transform.scale(
                  scale: 0.97 + (0.03 * value),
                  child: child,
                ),
              );
            },
            child: Container(
              width: 720,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height - 48,
              ),
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.2),
                    blurRadius: 60,
                    offset: Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Modal Head
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.border),
                      ),
                    ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${_data.title} Thermal Preview',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text,
                                  ),
                                ),
                                if (_data.isReprint) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFFF59E0B)),
                                    ),
                                    child: const Text(
                                      'REPRINT',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF92400E),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_data.referenceNo} • Reprinting does not mutate balances or recreate transactions',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 9.5,
                                color: Color(0xFF7F8999),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: widget.onClose,
                          child: Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: AppIcons.icon('close', size: 14, color: AppColors.textMuted),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Preview Toolbar
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceAlt,
                    border: Border(
                      bottom: BorderSide(color: AppColors.border),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Paper width toggle
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDF0F4),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Row(
                          children: [
                            _buildSegmentButton('58 mm', '58'),
                            _buildSegmentButton('80 mm', '80'),
                          ],
                        ),
                      ),

                      // Printer connection indicator & selector
                      Row(
                        children: [
                          if (_isLoadingPrinters) ...[
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Detecting printers...',
                              style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                            ),
                          ] else if (_printers.isNotEmpty) ...[
                            AppIcons.icon('check', size: 15, color: AppColors.green),
                            const SizedBox(width: 5),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<PrinterDevice>(
                                value: _selectedPrinter,
                                isDense: true,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text,
                                ),
                                items: _printers.map((p) {
                                  return DropdownMenuItem<PrinterDevice>(
                                    value: p,
                                    child: Text(p.name),
                                  );
                                }).toList(),
                                onChanged: (p) => setState(() => _selectedPrinter = p),
                              ),
                            ),
                          ] else ...[
                            AppIcons.icon('print', size: 15, color: AppColors.textMuted),
                            const SizedBox(width: 5),
                            const Text(
                              'Virtual PDF / System Default',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Status message bar (if active)
                if (_statusMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    color: _isError ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                    child: Text(
                      _statusMessage!,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _isError ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
                      ),
                    ),
                  ),

                // Paper Zone
                Flexible(
                  child: Container(
                    width: double.infinity,
                    color: const Color(0xFFE8EBEF),
                    padding: const EdgeInsets.all(24),
                    child: SingleChildScrollView(
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: paperWidthPx,
                          padding: EdgeInsets.all(paperPadding),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Color.fromRGBO(0, 0, 0, 0.12),
                                blurRadius: 18,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: DefaultTextStyle(
                            style: const TextStyle(
                              fontFamily: 'Courier',
                              color: Color(0xFF111111),
                              fontSize: 7.5,
                              height: 1.35,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Business Header
                                Center(
                                  child: Text(
                                    _data.businessName.toUpperCase(),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: is80 ? 13 : 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Center(
                                  child: Text(
                                    _data.businessAddress,
                                    style: const TextStyle(fontSize: 7),
                                  ),
                                ),
                                Center(
                                  child: Text(
                                    'Phone: ${_data.businessPhone}',
                                    style: const TextStyle(fontSize: 7),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                _buildDashedDivider(),
                                const SizedBox(height: 4),

                                // Title
                                Center(
                                  child: Text(
                                    _data.title.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: is80 ? 9 : 8,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (_data.isReprint) ...[
                                  const SizedBox(height: 2),
                                  const Center(
                                    child: Text(
                                      '*** REPRINT - AUDIT VERIFIED ***',
                                      style: TextStyle(fontSize: 6.5, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                _buildDashedDivider(),
                                const SizedBox(height: 5),

                                // Metadata
                                _buildReceiptMetaRow('Receipt #', _data.referenceNo),
                                _buildReceiptMetaRow('Date & Time', _data.dateTime),
                                if (_data.partyName != null && _data.partyName!.isNotEmpty)
                                  _buildReceiptMetaRow(_data.partyLabel ?? 'Party', _data.partyName!),
                                if (_data.partyPhone != null && _data.partyPhone!.isNotEmpty)
                                  _buildReceiptMetaRow('Phone', _data.partyPhone!),
                                if (_data.paymentMethod != null && _data.paymentMethod!.isNotEmpty)
                                  _buildReceiptMetaRow('Payment Wallet', _data.paymentMethod!),
                                if (_data.sourceWalletName != null)
                                  _buildReceiptMetaRow('Source Wallet', _data.sourceWalletName!),
                                if (_data.destinationWalletName != null)
                                  _buildReceiptMetaRow('Dest Wallet', _data.destinationWalletName!),

                                const SizedBox(height: 5),
                                _buildDashedDivider(),
                                const SizedBox(height: 5),

                                // Itemized Table (if items present)
                                if (_data.items.isNotEmpty) ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: is80 ? 5 : 4,
                                        child: Text(
                                          'ITEM',
                                          style: TextStyle(
                                            fontSize: itemFontSize,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: is80 ? 32 : 24,
                                        child: Text(
                                          'QTY',
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            fontSize: itemFontSize,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (is80)
                                        const SizedBox(
                                          width: 38,
                                          child: Text(
                                            'RATE',
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontSize: 7.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      SizedBox(
                                        width: is80 ? 46 : 38,
                                        child: Text(
                                          'TOTAL',
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            fontSize: itemFontSize,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  _buildDashedDivider(),
                                  const SizedBox(height: 3),
                                  ..._data.items.map((item) {
                                    final qtyStr = '${item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toStringAsFixed(2)} ${item.unit}'.trim();
                                    return _buildReceiptItem(
                                      item.description,
                                      qtyStr,
                                      item.unitPrice.toStringAsFixed(0),
                                      item.totalAmount.toStringAsFixed(0),
                                      is80,
                                      itemFontSize,
                                    );
                                  }),
                                  const SizedBox(height: 5),
                                  _buildDashedDivider(),
                                  const SizedBox(height: 5),
                                ],

                                // Totals
                                if (_data.subtotal > 0 && _data.items.isNotEmpty)
                                  _buildReceiptMetaRow('Subtotal', 'Rs ${_data.subtotal.toStringAsFixed(0)}'),
                                if (_data.discount > 0)
                                  _buildReceiptMetaRow('Discount', '- Rs ${_data.discount.toStringAsFixed(0)}'),
                                if (_data.tax > 0)
                                  _buildReceiptMetaRow('Tax', '+ Rs ${_data.tax.toStringAsFixed(0)}'),

                                const SizedBox(height: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: const BoxDecoration(
                                    border: Border.symmetric(
                                      horizontal: BorderSide(color: Color(0xFF111111), width: 1.2),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'GRAND TOTAL',
                                        style: TextStyle(
                                          fontSize: is80 ? 9.5 : 8.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        'Rs ${_data.grandTotal.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: is80 ? 9.5 : 8.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),

                                if (_data.paidAmount > 0 || _data.outstandingAmount > 0) ...[
                                  _buildReceiptMetaRow('Amount Paid', 'Rs ${_data.paidAmount.toStringAsFixed(0)}'),
                                  _buildReceiptMetaRow(
                                    'Outstanding',
                                    'Rs ${_data.outstandingAmount.toStringAsFixed(0)}',
                                    isBold: _data.outstandingAmount > 0,
                                  ),
                                ],

                                if (_data.partyBalance != null && _data.partyBalance!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  _buildDashedDivider(),
                                  const SizedBox(height: 4),
                                  Center(
                                    child: Text(
                                      'Account Balance: ${_data.partyBalance}',
                                      style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],

                                if (_data.notes != null && _data.notes!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Note: ${_data.notes}',
                                    style: const TextStyle(fontSize: 6.5, color: Color(0xFF444444)),
                                  ),
                                ],

                                const SizedBox(height: 6),
                                _buildDashedDivider(),
                                const SizedBox(height: 6),
                                const Center(
                                  child: Text(
                                    'Thank you for your business',
                                    style: TextStyle(fontSize: 7),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Center(
                                  child: Text(
                                    'Original receipt • Anwar Salt Factory ERP',
                                    style: TextStyle(fontSize: 6, color: Color(0xFF666666)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Modal Foot
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppColors.border),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AppButton(
                        label: 'Close',
                        variant: ButtonVariant.ghost,
                        onClick: widget.onClose,
                      ),
                      const SizedBox(width: 7),
                      AppButton(
                        label: 'Save as PDF',
                        icon: 'download',
                        variant: ButtonVariant.secondary,
                        onClick: _isProcessing ? () {} : _handleExportPdf,
                      ),
                      const SizedBox(width: 7),
                      AppButton(
                        label: _isProcessing ? 'Processing...' : 'Print receipt',
                        icon: 'print',
                        variant: ButtonVariant.primary,
                        onClick: _isProcessing ? () {} : _handlePrint,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildSegmentButton(String label, String value) {
    final active = _paperWidth == value;
    return GestureDetector(
      onTap: () => setState(() => _paperWidth = value),
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0xFFCCD1D9),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? AppColors.primaryDark : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptMetaRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 7)),
          Text(
            value,
            style: TextStyle(
              fontSize: 7,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptItem(
    String item,
    String qty,
    String rate,
    String amount,
    bool is80,
    double fontSize,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: is80 ? 5 : 4,
            child: Text(item, style: TextStyle(fontSize: fontSize)),
          ),
          SizedBox(
            width: is80 ? 32 : 24,
            child: Text(
              qty,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: fontSize),
            ),
          ),
          if (is80)
            SizedBox(
              width: 38,
              child: Text(
                rate,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: fontSize),
              ),
            ),
          SizedBox(
            width: is80 ? 46 : 38,
            child: Text(
              amount,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: fontSize),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashedDivider() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const dashWidth = 3.0;
        const dashSpace = 2.0;
        final count = (width / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(count, (_) {
            return const SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Color(0xFF111111)),
              ),
            );
          }),
        );
      },
    );
  }
}
