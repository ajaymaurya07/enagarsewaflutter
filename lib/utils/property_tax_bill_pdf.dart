import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../services/api_service.dart';
import 'ulb_language_helper.dart';

/// Builds the "सम्पति कर बिल" print-out the way the e-NagarSewa (NIC) portal
/// prints it — the discrepancy note band, the bill/ULB header, the
/// "पूर्व जमा धनराशि" table (printed both above and below the bill, as the
/// portal does), the "गृह संबंधी विवरण" grid, the row-wise "वित्तीय विवरण"
/// grid with its Grand Total and "भुगतान हेतु शेष राशि" lines.
///
/// The portal's link row (View Transaction History etc.) and its NIC footer are
/// left out — the links do nothing in a printed PDF.
///
/// This is the bill view; [PropertyTaxReceiptPdf] stays as the receipt view.
///
/// The Hindi labels are rendered through `Printing.convertHtml` (a platform
/// WebView prints the markup to PDF) because the `pdf` package draws one glyph
/// per code unit and has no Devanagari shaping — matras and conjuncts would
/// come out misplaced if the bill were laid out with `pw` widgets. If the
/// platform cannot convert HTML, [buildBytes] falls back to
/// [_buildFallbackDocument], a plain label/value sheet.
///
/// The portal prints a QR code in the top-right corner; it is left out here on
/// purpose because the app has no payload to encode into it yet.
class PropertyTaxBillPdf {
  PropertyTaxBillPdf._();

  static const double _margin = 0.8 * PdfPageFormat.cm;

  /// Page margins have to be requested differently per platform:
  ///
  /// * Android prints through a WebView, which ignores the `minMargins` the
  ///   plugin passes and honours the CSS `@page` margin instead — so the format
  ///   asks for none and [_cssPageMargin] supplies them. (The plugin also
  ///   multiplies `marginLeft` by 1000 without converting points to mils, so a
  ///   non-zero left margin would blow up the left edge anyway.)
  /// * iOS builds the printable rect from these margins, so the format carries
  ///   them there.
  static PdfPageFormat get _pageFormat => PdfPageFormat(
        21.0 * PdfPageFormat.cm,
        29.7 * PdfPageFormat.cm,
        marginAll: Platform.isIOS ? _margin : 0,
      );

  /// Kept in millimetres because `@page` is only read by the WebView path.
  static const String _cssPageMargin = '8mm';

  static String? _cachedKrutidevBase64;

  static final NumberFormat _grouped = NumberFormat('#,##0.00', 'en_US');

  static Future<Uint8List> buildBytes({
    required String propertyId,
    BillDetails? bill,
    OwnerDetails? owner,
    PropertyInfo? property,
    List<ReceiptDetailsItem> currReceipts = const [],
    String? arv,
    String? ulbName,
    String? ulbType,
    String? oldPropertyId,
    String? oldId,
    String? assessmentDate,
  }) async {
    final isKrutidev = await UlbLanguageHelper.isKrutidev();

    try {
      final html = await buildHtml(
        propertyId: propertyId,
        bill: bill,
        owner: owner,
        property: property,
        currReceipts: currReceipts,
        arv: arv,
        ulbName: ulbName,
        ulbType: ulbType,
        oldPropertyId: oldPropertyId,
        oldId: oldId,
        assessmentDate: assessmentDate,
        isKrutidev: isKrutidev,
      );
      // Deprecated upstream, but it is the only API that hands the markup to a
      // real WebView — and therefore the only one that shapes Devanagari.
      // ignore: deprecated_member_use
      return await Printing.convertHtml(html: html, format: _pageFormat);
    } catch (_) {
      final doc = await _buildFallbackDocument(
        propertyId: propertyId,
        bill: bill,
        owner: owner,
        property: property,
        isKrutidev: isKrutidev,
      );
      return doc.save();
    }
  }

  // ---------------------------------------------------------------- HTML

  @visibleForTesting
  static Future<String> buildHtml({
    required String propertyId,
    required BillDetails? bill,
    required OwnerDetails? owner,
    required PropertyInfo? property,
    required List<ReceiptDetailsItem> currReceipts,
    required String? arv,
    String? ulbName,
    String? ulbType,
    String? oldPropertyId,
    String? oldId,
    String? assessmentDate,
    required bool isKrutidev,
  }) async {
    final finYear = _text(bill?.finYear);
    final receipts = currReceipts.where(_hasReceiptNo).toList();
    final columns = _taxColumns(bill, receipts);

    // The portal's Grand Total is the sum of the "देय धनराशि" row.
    final grandTotal = columns.fold<double>(
      0,
      (sum, column) => sum + column.payableValue,
    );

    final fontFace = isKrutidev
        ? "@font-face { font-family:'KrutiDev010'; "
            "src:url(data:font/truetype;charset=utf-8;base64,${await _krutidevBase64()}) format('truetype'); }"
        : '';
    final languageClass = isKrutidev ? ' class="kd"' : '';

    String nameLine(String label, String? value) =>
        '<div>$label &ndash; <span$languageClass>${_esc(_text(value))}</span></div>';

    final printedOn = DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now());
    final maskedMobile = _maskMobile(owner?.mobileNo);
    final depositsSection = _depositsSectionHtml(receipts, finYear);

    return '''
<!DOCTYPE html>
<html lang="hi">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
$fontFace
* { box-sizing: border-box; }
@page { size: A4; margin: $_cssPageMargin; }
body {
  margin: 0;
  color: #000;
  font-size: 10.5px;
  font-family: 'Noto Sans Devanagari', 'Devanagari Sangam MN', 'Kohinoor Devanagari', 'Mangal', sans-serif;
}
table { width: 100%; border-collapse: collapse; }
.topnote {
  border: 1px solid #e3c363; background: #fffdf4; color: #c0392b;
  padding: 6px 10px; text-align: center; font-weight: bold;
  font-size: 9.5px; line-height: 1.6;
}
.head td { padding: 10px 0 2px 0; font-size: 10.5px; line-height: 1.9; vertical-align: top; }
.head .ulb { text-align: center; font-size: 17px; font-weight: bold; vertical-align: middle; }
.title { text-align: center; font-size: 15px; font-weight: bold; margin: 8px 0 6px; }
.grid { border: 1px solid #808080; }
.grid + .grid, .grid.join { margin-top: -1px; }
.grid td { border: 1px solid #808080; padding: 4px 6px; vertical-align: middle; }
.band td { background: #e6e6e6; text-align: center; font-weight: bold; font-size: 11.5px; padding: 5px; }
.chead td { background: #e6e6e6; text-align: center; font-weight: bold; }
.lbl { width: 22%; }
.val { font-weight: bold; }
.addr { line-height: 1.9; padding: 5px 6px !important; }
.n { text-align: right; width: 8%; }
.sn { text-align: left; width: 4%; }
.fh { width: 19.2%; }
/* The longest label in the grid; the portal keeps it on one line. */
.rest td { white-space: nowrap; font-size: 9.5px; padding: 4px 4px; }
.total td {
  background: #fffdf4; text-align: center; font-weight: bold; font-size: 11px; padding: 5px;
}
.kd { font-family: 'KrutiDev010'; font-size: 14px; }
.empty { text-align: center; font-style: italic; padding: 10px 6px; }
</style>
</head>
<body>

<div class="topnote">
  In case of any discrepancy in the data, Citizen has to contact related NAGAR NIGAM /
  NAGAR PALIKA PARISHAD / NAGAR PANCHAYAT. NIC (National Informatics Centre) is not
  responsible for the data on the website.
</div>

<table class="head">
  <tr>
    <td style="width:33%">
      बिल संख्या&nbsp;&nbsp;<b>${_esc(_text(bill?.billNo))}</b><br>
      बिल दिनांक&nbsp;&nbsp;<b>${_esc(_text(bill?.billDate))}</b><br>
      प्रिन्ट दिनांक&nbsp;&nbsp;<b>$printedOn</b>
    </td>
    <td class="ulb" style="width:34%">${_esc(_ulbHeading(ulbType, ulbName ?? property?.ulbName))}</td>
    <td style="width:33%"></td>
  </tr>
</table>

<div class="title">सम्पति कर बिल</div>

$depositsSection

<table class="grid join">
  <tr class="band"><td colspan="4">गृह संबंधी विवरण</td></tr>
  <tr>
    <td class="lbl">नयी 17-डिजिट प्रापर्टी आईडी0</td>
    <td class="val">${_esc(propertyId)}</td>
    <td class="lbl">पुरानी प्रापर्टी आईडी0</td>
    <td class="val">${_esc(_text(oldPropertyId))}</td>
  </tr>
  <tr>
    <td class="lbl">पुरानी आईडी0</td>
    <td class="val">${_esc(_text(oldId))}</td>
    <td class="lbl">वित्तीय वर्ष</td>
    <td class="val">${_esc(finYear)}</td>
  </tr>
  <tr>
    <td class="lbl">जोन</td>
    <td class="val">${_esc(_text(property?.zoneName))}</td>
    <td class="lbl">वार्ड</td>
    <td class="val">${_esc(_text(property?.wardName))}</td>
  </tr>
  <tr>
    <td class="lbl">मोहल्ला/चक</td>
    <td class="val" colspan="3">${_esc(_text(property?.mohallaName))}</td>
  </tr>
  <tr>
    <td class="lbl">नाम पता</td>
    <td class="val addr" colspan="3">
      ${nameLine('नाम', owner?.ownerName)}
      ${nameLine('पिता / पति का नाम', owner?.fatherName)}
      <div>गृह संख्या &ndash; ${_esc(_text(property?.houseNo))}</div>
      ${nameLine('पता', property?.address)}
      <div>मो &ndash; ${_esc(maskedMobile)}</div>
    </td>
  </tr>
  <tr>
    <td class="lbl">AV/ARV</td>
    <td class="val">${_esc(_amount(arv))}</td>
    <td class="lbl">Date of Assessment</td>
    <td class="val">${_esc(_text(assessmentDate))}</td>
  </tr>
  <tr>
    <td class="lbl">Property Type</td>
    <td class="val" colspan="3">${_esc(_text(property?.propertyType ?? property?.propertyUseAs))}</td>
  </tr>
</table>

${_financialGridHtml(columns, grandTotal)}

$depositsSection

</body>
</html>
''';
  }

  /// The row-wise "वित्तीय विवरण" grid: one column pair (label + amount) per
  /// tax head, the Grand Total band and the "भुगतान हेतु शेष राशि" line.
  static String _financialGridHtml(List<_TaxColumn> columns, double grandTotal) {
    String amountRow(int serial, String label, String Function(_TaxColumn) pick) {
      final cells = columns
          .map((c) => '<td>${_esc(label)}</td><td class="n">${_esc(pick(c))}</td>')
          .join();
      return '  <tr><td class="sn">$serial</td>$cells</tr>';
    }

    final headings =
        columns.map((c) => '<td class="fh" colspan="2">${_esc(c.title)}</td>').join();
    final remaining = columns
        .map((c) =>
            '<td>भुगतान हेतु शेष राशि</td><td class="n">${_esc(c.remaining)}</td>')
        .join();

    return '''
<table class="grid join">
  <tr class="band"><td colspan="11">वित्तीय विवरण</td></tr>
  <tr class="chead"><td class="sn">क्रं0सं0</td>$headings</tr>
${amountRow(1, 'वार्षिक मांग', (c) => c.annualDemand)}
${amountRow(2, 'बकाया', (c) => c.arrear)}
${amountRow(3, 'ब्याज', (c) => c.interest)}
${amountRow(4, 'मासिक ब्याज', (c) => c.monthlyInterest)}
${amountRow(5, 'कुल मांग', (c) => c.totalDemand)}
${amountRow(6, 'छूट', (c) => c.discount)}
${amountRow(7, 'अग्रिम जमा', (c) => c.advance)}
${amountRow(8, 'देय धनराशि', (c) => c.payable)}
  <tr class="total">
    <td colspan="11">सम्पूर्ण देय धनराशि योग (Grand Total) : ${_esc(_grouped.format(grandTotal))}</td>
  </tr>
  <tr class="rest"><td class="sn"></td>$remaining</tr>
</table>''';
  }

  /// The "वित्तीय वर्ष … में पूर्व जमा धनराशि के विवरण" block. The portal prints
  /// it twice — once above the bill and once below — so this markup is reused.
  static String _depositsSectionHtml(
    List<ReceiptDetailsItem> receipts,
    String finYear,
  ) {
    final band = '<tr class="band"><td colspan="10">वित्तीय वर्ष '
        '${_esc(finYear)} में पूर्व जमा धनराशि के विवरण</td></tr>';

    if (receipts.isEmpty) {
      const message = 'No Payment Transaction Done Through '
          'https://e-nagarsewaup.gov.in in the Financial Year ';
      return '<table class="grid join">\n  $band\n'
          '  <tr><td class="empty" colspan="10">$message${_esc(finYear)}</td></tr>\n'
          '</table>';
    }

    final rows = receipts.map((receipt) {
      final total = _sum([
        receipt.propertyTaxPaidAmount,
        receipt.waterTaxPaidAmount,
        receipt.waterChargePaidAmount,
        receipt.sewerTaxPaidAmount,
        receipt.otherTaxPaidAmount,
      ]);
      return '  <tr>'
          '<td style="text-align:center">${_esc(_bookNo(finYear))}</td>'
          '<td style="text-align:center">${_esc(_text(receipt.receiptNo))}</td>'
          '<td style="text-align:center">${_esc(_text(receipt.receiptDate))}</td>'
          '<td style="text-align:center">${_esc(_text(receipt.paymentMode))}</td>'
          '<td class="n">${_esc(_amount(receipt.propertyTaxPaidAmount))}</td>'
          '<td class="n">${_esc(_amount(receipt.waterTaxPaidAmount))}</td>'
          '<td class="n">${_esc(_amount(receipt.waterChargePaidAmount))}</td>'
          '<td class="n">${_esc(_amount(receipt.sewerTaxPaidAmount))}</td>'
          '<td class="n">${_esc(_amount(receipt.otherTaxPaidAmount))}</td>'
          '<td class="n val">${_esc(_grouped.format(total))}</td>'
          '</tr>';
    }).join('\n');

    return '''
<table class="grid join">
  $band
  <tr class="chead">
    <td>बुक संख्या</td><td>रसीद सं.</td><td>जमा की तारीख और समय</td><td>भुगतान मोड</td>
    <td>गृहकर जमा</td><td>जलकर जमा</td><td>जल शुल्क जमा</td><td>सीवरेजकर जमा</td>
    <td>अन्यकर जमा</td><td>कुल जमा</td>
  </tr>
$rows
</table>''';
  }

  // ------------------------------------------------------------ tax data

  static List<_TaxColumn> _taxColumns(
    BillDetails? bill,
    List<ReceiptDetailsItem> receipts,
  ) {
    double paidOf(String? Function(ReceiptDetailsItem) pick) =>
        _sum(receipts.map(pick).toList());

    return [
      _TaxColumn(
        title: 'गृहकर',
        annualDemand: bill?.houseCurrentTax,
        arrear: bill?.houseTaxArrear,
        interest: bill?.houseTaxInterest,
        monthlyInterest: bill?.houseTaxMonthlyInterest,
        totalDemand: bill?.houseTaxNetAmount,
        discount: bill?.houseTaxDiscount,
        advance: bill?.houseTaxAdvance,
        payable: bill?.houseTaxPayable,
        depositedValue: paidOf((r) => r.propertyTaxPaidAmount),
      ),
      _TaxColumn(
        title: 'जलकर',
        annualDemand: bill?.waterCurrentTax,
        arrear: bill?.waterTaxArrear,
        interest: bill?.waterTaxInterest,
        monthlyInterest: bill?.waterTaxMonthlyInterest,
        totalDemand: bill?.waterTaxNetAmount,
        discount: bill?.waterTaxDiscount,
        advance: bill?.waterTaxAdvance,
        payable: bill?.waterTaxPayable,
        depositedValue: paidOf((r) => r.waterTaxPaidAmount),
      ),
      _TaxColumn(
        title: 'जल शुल्क',
        annualDemand: bill?.waterChargeCurrent,
        arrear: bill?.waterChargeArrear,
        interest: bill?.waterChargeInterest,
        monthlyInterest: bill?.waterChargeMonthlyInterest,
        totalDemand: bill?.waterChargeNetAmount,
        discount: bill?.waterChargeDiscount,
        advance: bill?.waterChargeAdvance,
        payable: bill?.waterChargePayable,
        depositedValue: paidOf((r) => r.waterChargePaidAmount),
      ),
      _TaxColumn(
        title: 'सीवरेजकर',
        annualDemand: bill?.sewerCurrentTax,
        arrear: bill?.sewerTaxArrear,
        interest: bill?.sewerTaxInterest,
        monthlyInterest: bill?.sewerTaxMonthlyInterest,
        totalDemand: bill?.sewerTaxNetAmount,
        discount: bill?.sewerTaxDiscount,
        advance: bill?.sewerTaxAdvance,
        payable: bill?.sewerTaxPayable,
        depositedValue: paidOf((r) => r.sewerTaxPaidAmount),
      ),
      _TaxColumn(
        title: 'अन्यकर',
        annualDemand: bill?.otherCurrentTax,
        arrear: bill?.otherTaxArrear,
        interest: bill?.otherTaxInterest,
        monthlyInterest: bill?.otherTaxMonthlyInterest,
        totalDemand: bill?.othertaxNetAmount,
        discount: bill?.otherTaxDiscount,
        advance: bill?.otherTaxAdvance,
        payable: bill?.otherTaxPayable,
        depositedValue: paidOf((r) => r.otherTaxPaidAmount),
      ),
    ];
  }

  // -------------------------------------------------------------- helpers

  static Future<String> _krutidevBase64() async {
    if (_cachedKrutidevBase64 != null) return _cachedKrutidevBase64!;
    final data = await rootBundle.load(UlbLanguageHelper.krutidevAssetPath);
    return _cachedKrutidevBase64 = base64Encode(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }

  /// The ULB data API only ever returns these three types, either spelled out
  /// or as the signup codes (NN / NPP / NP).
  static const Map<String, String> _ulbTypeInHindi = {
    'nagar nigam': 'नगर निगम',
    'nn': 'नगर निगम',
    'nagar palika parishad': 'नगर पालिका परिषद',
    'npp': 'नगर पालिका परिषद',
    'nagar panchayat': 'नगर पंचायत',
    'np': 'नगर पंचायत',
  };

  /// Print-out heading, e.g. `नगर पालिका परिषद, Loni`. The type is translated
  /// from the fixed set above; the ULB name is printed as the API returns it
  /// because there is no Hindi spelling of it anywhere in the app.
  static String _ulbHeading(String? ulbType, String? ulbName) {
    final name = _text(ulbName);
    final rawType = ulbType?.trim() ?? '';
    final type = _ulbTypeInHindi[rawType.toLowerCase()] ?? rawType;

    if (type.isEmpty) return name;
    if (name == '-') return type;
    return '$type, $name';
  }

  static bool _hasReceiptNo(ReceiptDetailsItem receipt) {
    final receiptNo = receipt.receiptNo?.trim();
    return receiptNo != null && receiptNo.isNotEmpty && receiptNo != '-' && receiptNo != 'null';
  }

  static String _text(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == 'null') return '-';
    return trimmed;
  }

  static String _esc(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  static double _number(String? value) => double.tryParse(value?.trim() ?? '') ?? 0.0;

  static String _amount(String? value) => _number(value).toStringAsFixed(2);

  static double _sum(List<String?> values) =>
      values.fold<double>(0, (total, value) => total + _number(value));

  /// The portal prints the financial year's opening year as the book number.
  static String _bookNo(String finYear) {
    final year = finYear.split(RegExp(r'[-/]')).first.trim();
    return year.isEmpty || year == '-' ? '-' : year;
  }

  /// `9876596788` -> `#####96788`, matching the portal's masking.
  static String _maskMobile(String? mobile) {
    final digits = (mobile ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '-';
    if (digits.length <= 5) return digits;
    return '${'#' * (digits.length - 5)}${digits.substring(digits.length - 5)}';
  }

  // ------------------------------------------------------------- fallback

  /// Plain label/value sheet used when the platform cannot print HTML.
  static Future<pw.Document> _buildFallbackDocument({
    required String propertyId,
    required BillDetails? bill,
    required OwnerDetails? owner,
    required PropertyInfo? property,
    required bool isKrutidev,
  }) async {
    final languageFont = await UlbLanguageHelper.pdfFontIfKrutidev(isKrutidev);
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'Property Tax Bill',
                  style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'Property ID: $propertyId',
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Divider(thickness: 1.5),
              pw.SizedBox(height: 10),
              pw.Text('Property Information',
                  style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              _fallbackRow('Zone Name', _text(property?.zoneName)),
              _fallbackRow('Ward Name', _text(property?.wardName)),
              _fallbackRow('Mohalla Name', _text(property?.mohallaName)),
              _fallbackRow('House No.', _text(property?.houseNo)),
              _fallbackRow('Address', _text(property?.address), languageFont: languageFont),
              pw.SizedBox(height: 12),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text('Owner Information',
                  style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              _fallbackRow('Owner Name', _text(owner?.ownerName), languageFont: languageFont),
              _fallbackRow('Father Name', _text(owner?.fatherName), languageFont: languageFont),
              _fallbackRow('Mobile No.', _maskMobile(owner?.mobileNo)),
              pw.SizedBox(height: 12),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text('Tax Summary',
                  style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              _fallbackRow('Bill Date', _text(bill?.billDate)),
              _fallbackRow('Bill Number', _text(bill?.billNo)),
              _fallbackRow('Financial Year', _text(bill?.finYear)),
              _fallbackRow('House Tax Payable', 'Rs. ${_amount(bill?.houseTaxPayable)}'),
              _fallbackRow('Water Tax Payable', 'Rs. ${_amount(bill?.waterTaxPayable)}'),
              _fallbackRow('Water Charge Payable', 'Rs. ${_amount(bill?.waterChargePayable)}'),
              _fallbackRow('Sewer Tax Payable', 'Rs. ${_amount(bill?.sewerTaxPayable)}'),
              _fallbackRow('Other Tax Payable', 'Rs. ${_amount(bill?.otherTaxPayable)}'),
              pw.SizedBox(height: 14),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 1.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Grand Total',
                        style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Rs. ${_amount(bill?.netPayble)}',
                        style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return doc;
  }

  static pw.Widget _fallbackRow(String label, String value, {pw.Font? languageFont}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Text(label, style: const pw.TextStyle(color: PdfColors.grey700)),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            flex: 4,
            child: pw.Text(
              value,
              style: pw.TextStyle(font: languageFont, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

/// One tax head of the "वित्तीय विवरण" grid.
class _TaxColumn {
  _TaxColumn({
    required this.title,
    required String? annualDemand,
    required String? arrear,
    required String? interest,
    required String? monthlyInterest,
    required String? totalDemand,
    required String? discount,
    required String? advance,
    required String? payable,
    required this.depositedValue,
  })  : payableValue = PropertyTaxBillPdf._number(payable),
        annualDemand = PropertyTaxBillPdf._amount(annualDemand),
        arrear = PropertyTaxBillPdf._amount(arrear),
        interest = PropertyTaxBillPdf._amount(interest),
        monthlyInterest = PropertyTaxBillPdf._amount(monthlyInterest),
        totalDemand = PropertyTaxBillPdf._amount(totalDemand),
        discount = PropertyTaxBillPdf._amount(discount),
        advance = PropertyTaxBillPdf._amount(advance),
        payable = PropertyTaxBillPdf._amount(payable);

  final String title;
  final String annualDemand;
  final String arrear;
  final String interest;
  final String monthlyInterest;
  final String totalDemand;
  final String discount;
  final String advance;
  final String payable;

  final double payableValue;
  final double depositedValue;

  /// What is still owed on this head once the year's deposits are taken off.
  String get remaining =>
      (payableValue - depositedValue).clamp(0, double.infinity).toStringAsFixed(2);
}
