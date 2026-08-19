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

/// Builds the "संपत्ति कर रसीद" print-out in the same layout the
/// e-NagarSewa (NIC) portal prints — header band with bill/receipt numbers,
/// the "गृह संबंधी विवरण" grid, the five-column "वित्तीय विवरण" grid, the
/// total-deposited block, the discount note and the previous-payments section.
///
/// The Hindi labels are rendered through `Printing.convertHtml` (a platform
/// WebView prints the markup to PDF) because the `pdf` package draws one glyph
/// per code unit and has no Devanagari shaping — matras and conjuncts would
/// come out misplaced if the receipt were laid out with `pw` widgets. If the
/// platform cannot convert HTML, [buildBytes] falls back to
/// [_buildFallbackDocument], the plain label/value sheet.
class PropertyTaxReceiptPdf {
  PropertyTaxReceiptPdf._();

  static const double _margin = 0.8 * PdfPageFormat.cm;

  /// Page margins have to be requested differently per platform:
  ///
  /// * Android prints through a WebView, which ignores the `minMargins` the
  ///   plugin passes and honours the CSS `@page` margin instead — so the format
  ///   asks for none and [_cssPageMargin] supplies them. (The plugin also
  ///   multiplies `marginLeft` by 1000 without converting points to mils, so a
  ///   non-zero left margin would blow up the left edge anyway.)
  /// * iOS builds the printable rect from these margins, so the format carries
  ///   them there. If WebKit also applies `@page` the insets add up and the
  ///   receipt just sits a little narrower — better than the edge-to-edge page
  ///   that dropping them would risk.
  static PdfPageFormat get _pageFormat => PdfPageFormat(
        21.0 * PdfPageFormat.cm,
        29.7 * PdfPageFormat.cm,
        marginAll: Platform.isIOS ? _margin : 0,
      );

  /// Kept in millimetres because `@page` is only read by the WebView path.
  static const String _cssPageMargin = '8mm';

  static String? _cachedKrutidevBase64;

  static Future<Uint8List> buildBytes({
    required String propertyId,
    BillDetails? bill,
    OwnerDetails? owner,
    PropertyInfo? property,
    List<ReceiptDetailsItem> currReceipts = const [],
    String? arv,
    String? ulbName,
    String? ulbType,
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
    required bool isKrutidev,
  }) async {
    final finYear = _text(bill?.finYear);
    final receipts = currReceipts.where(_hasReceiptNo).toList();
    // The receipt raised against the bill on screen; the rest of the current
    // financial year's receipts go to the "पूर्व जमा धनराशि" section.
    final paid = receipts.where((r) => r.billNo == bill?.billNo).firstOrNull ??
        receipts.firstOrNull;
    final earlier = receipts.where((r) => r != paid).toList();

    final columns = _taxColumns(bill, paid);
    final totalDeposited = columns.fold<double>(
      0,
      (sum, column) => sum + column.depositedValue,
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
.head td { padding: 0 0 2px 0; font-size: 10px; line-height: 1.7; vertical-align: top; }
.head .ulb { text-align: center; font-size: 17px; font-weight: bold; }
.head .r { text-align: right; }
.title { text-align: center; font-size: 15px; font-weight: bold; margin: 10px 0 8px; }
.grid { border: 1px solid #808080; }
.grid + .grid, .grid.join { margin-top: -1px; }
.grid td { border: 1px solid #808080; padding: 4px 6px; vertical-align: middle; }
.band td { background: #e6e6e6; text-align: center; font-weight: bold; font-size: 11.5px; padding: 5px; }
.lbl { width: 22%; }
.val { font-weight: bold; }
.addr { line-height: 1.85; padding: 5px 6px !important; }
.grp { padding: 0 !important; width: 20%; vertical-align: top; }
.grp table td { border-top: 0; }
.grp table tr:first-child td { border-top: 0; }
.grp td.n { text-align: right; width: 42%; font-weight: bold; }
.ghead td { background: #f2f2f2; text-align: center; font-weight: bold; }
.kd { font-family: 'KrutiDev010'; font-size: 14px; }
.note {
  border: 1px solid #e3c363; background: #fffdf4; color: #c0392b;
  padding: 6px 10px; margin: 10px 0; text-align: center; line-height: 1.8;
}
.sub { background: #e6e6e6; border: 1px solid #808080; text-align: center;
  font-weight: bold; font-size: 11.5px; padding: 5px; margin-top: 10px; }
.empty { text-align: center; font-style: italic; padding: 10px 6px; }
.foot { text-align: center; font-style: italic; font-size: 10px;
  border-top: 1px solid #b0b0b0; margin-top: 10px; padding-top: 8px; }
</style>
</head>
<body>

<table class="head">
  <tr>
    <td style="width:30%">
      बिल संख्या: <b>${_esc(_text(bill?.billNo))}</b><br>
      बिल दिनांक: <b>${_esc(_text(bill?.billDate))}</b><br>
      प्रिंट दिनांक: <b>$printedOn</b>
    </td>
    <td class="ulb" style="width:40%">${_esc(_ulbHeading(ulbType, ulbName ?? property?.ulbName))}</td>
    <td class="r" style="width:30%">
      बुक संख्या: <b>${_esc(_bookNo(finYear))}</b><br>
      रसीद संख्या: <b>${_esc(_text(paid?.receiptNo))}</b><br>
      रसीद दिनांक: <b>${_esc(_text(paid?.receiptDate))}</b>
    </td>
  </tr>
</table>

<div class="title">${paid != null ? 'संपत्ति कर रसीद' : 'संपत्ति कर बिल'}</div>

<table class="grid">
  <tr class="band"><td colspan="4">गृह संबंधी विवरण</td></tr>
  <tr>
    <td class="lbl">नयी 17-डिजिट प्रापर्टी आई0डी0</td>
    <td class="val">${_esc(propertyId)}</td>
    <td class="lbl">पुरानी प्रापर्टी आई0डी0</td>
    <td class="val">-</td>
  </tr>
  <tr>
    <td class="lbl">पुरानी आई0डी0</td>
    <td class="val">-</td>
    <td class="lbl">वित्तीय वर्ष</td>
    <td class="val">${_esc(finYear)}</td>
  </tr>
  <tr>
    <td class="lbl">वित्तीय वर्ष क्रमांक</td>
    <td class="val">-</td>
    <td class="lbl">जोन</td>
    <td class="val">${_esc(_text(property?.zoneName))}</td>
  </tr>
  <tr>
    <td class="lbl">वार्ड</td>
    <td class="val">${_esc(_text(property?.wardName))}</td>
    <td class="lbl">मोहल्ला/चक</td>
    <td class="val">${_esc(_text(property?.mohallaName))}</td>
  </tr>
  <tr>
    <td class="lbl">जमा आपरेटर कोड</td>
    <td class="val">-</td>
    <td class="lbl">दिनांक क्रमांक</td>
    <td class="val">-</td>
  </tr>
  <tr>
    <td class="lbl">मोबाइल नं.</td>
    <td class="val">${_esc(maskedMobile)}</td>
    <td class="lbl">यूएलबी रसीद संख्या:</td>
    <td class="val">-</td>
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
    <td class="val">-</td>
  </tr>
  <tr>
    <td class="lbl">Property Type</td>
    <td class="val" colspan="3">${_esc(_text(property?.propertyType ?? property?.propertyUseAs))}</td>
  </tr>
</table>

<table class="grid join">
  <tr class="band"><td colspan="5">वित्तीय विवरण</td></tr>
  <tr>
${columns.map(_taxColumnHtml).join('\n')}
  </tr>
</table>

<table class="grid join">
  <tr>
    <td class="lbl">कुल जमा की गई धनराशि</td>
    <td>
      अंको मे: <b>${_esc(totalDeposited.toStringAsFixed(2))}</b><br>
      शब्दों में: <b>${_esc(_amountInWords(totalDeposited))}</b>
    </td>
  </tr>
  <tr>
    <td class="lbl">पेमेन्ट मोड विवरण</td>
    <td class="val">${_esc(_text(paid?.paymentMode))}</td>
  </tr>
</table>

<div class="note">
  * छूट नगर निगम द्वारा घोषित तिथियों के मध्य दी जायेगी एवं वार्षिक मांगदेय धनराशि पर दी जायेगी ।<br>
  इस रसीद पर छूट: (${columns.where((c) => c.showsDiscountPercent).map((c) => '${c.title}: <b>${c.discountPercent}</b>').join(', ')})
</div>

<div class="sub">वित्तीय वर्ष ${_esc(finYear)} में पूर्व जमा धनराशि के विवरण</div>
${_earlierPaymentsHtml(earlier, finYear)}

<div class="foot">Software developed by National Informatics Centre, Lucknow. Data is the responsibility of particular ULB.</div>

</body>
</html>
''';
  }

  static String _taxColumnHtml(_TaxColumn column) {
    String row(String label, String value) =>
        '<tr><td>${_esc(label)}</td><td class="n">${_esc(value)}</td></tr>';

    return '''    <td class="grp">
      <table>
        <tr class="ghead"><td colspan="2">${_esc(column.title)}</td></tr>
        ${row('वार्षिक मांग', column.annualDemand)}
        ${row('बकाया', column.arrear)}
        ${row('ब्याज', column.interest)}
        ${row('कुल मांग', column.totalDemand)}
        ${row('मासिक ब्याज', column.monthlyInterest)}
        ${row('छूट *', column.discount)}
        ${row('अग्रिम जमा', column.advance)}
        ${row('देय धनराशि', column.payable)}
        ${row('जमा राशि', column.deposited)}
      </table>
    </td>''';
  }

  static String _earlierPaymentsHtml(
    List<ReceiptDetailsItem> receipts,
    String finYear,
  ) {
    if (receipts.isEmpty) {
      return '<div class="empty">No Previous Payment Transaction Done Through '
          'https://e-nagarsewaup.gov.in in the Financial Year $finYear</div>';
    }

    final rows = receipts.map((receipt) {
      final amount = _sum([
        receipt.propertyTaxPaidAmount,
        receipt.waterTaxPaidAmount,
        receipt.waterChargePaidAmount,
        receipt.sewerTaxPaidAmount,
        receipt.otherTaxPaidAmount,
      ]);
      return '<tr>'
          '<td>${_esc(_text(receipt.receiptNo))}</td>'
          '<td>${_esc(_text(receipt.receiptDate))}</td>'
          '<td>${_esc(_text(receipt.paymentMode))}</td>'
          '<td class="val" style="text-align:right">${_esc(amount.toStringAsFixed(2))}</td>'
          '</tr>';
    }).join('\n');

    return '''
<table class="grid join">
  <tr class="band">
    <td>रसीद संख्या</td><td>रसीद दिनांक</td><td>पेमेन्ट मोड</td><td>जमा राशि</td>
  </tr>
$rows
</table>''';
  }

  // ------------------------------------------------------------ tax data

  static List<_TaxColumn> _taxColumns(
    BillDetails? bill,
    ReceiptDetailsItem? paid,
  ) {
    return [
      _TaxColumn(
        title: 'गृहकर',
        annualDemand: bill?.houseCurrentTax,
        arrear: bill?.houseTaxArrear,
        interest: bill?.houseTaxInterest,
        totalDemand: bill?.houseTaxNetAmount,
        monthlyInterest: bill?.houseTaxMonthlyInterest,
        discount: bill?.houseTaxDiscount,
        advance: bill?.houseTaxAdvance,
        payable: bill?.houseTaxPayable,
        deposited: paid?.propertyTaxPaidAmount,
      ),
      _TaxColumn(
        title: 'जलकर',
        annualDemand: bill?.waterCurrentTax,
        arrear: bill?.waterTaxArrear,
        interest: bill?.waterTaxInterest,
        totalDemand: bill?.waterTaxNetAmount,
        monthlyInterest: bill?.waterTaxMonthlyInterest,
        discount: bill?.waterTaxDiscount,
        advance: bill?.waterTaxAdvance,
        payable: bill?.waterTaxPayable,
        deposited: paid?.waterTaxPaidAmount,
      ),
      _TaxColumn(
        title: 'जल शुल्क',
        annualDemand: bill?.waterChargeCurrent,
        arrear: bill?.waterChargeArrear,
        interest: bill?.waterChargeInterest,
        totalDemand: bill?.waterChargeNetAmount,
        monthlyInterest: bill?.waterChargeMonthlyInterest,
        discount: bill?.waterChargeDiscount,
        advance: bill?.waterChargeAdvance,
        payable: bill?.waterChargePayable,
        deposited: paid?.waterChargePaidAmount,
        showsDiscountPercent: false,
      ),
      _TaxColumn(
        title: 'सीवरेजकर',
        annualDemand: bill?.sewerCurrentTax,
        arrear: bill?.sewerTaxArrear,
        interest: bill?.sewerTaxInterest,
        totalDemand: bill?.sewerTaxNetAmount,
        monthlyInterest: bill?.sewerTaxMonthlyInterest,
        discount: bill?.sewerTaxDiscount,
        advance: bill?.sewerTaxAdvance,
        payable: bill?.sewerTaxPayable,
        deposited: paid?.sewerTaxPaidAmount,
      ),
      _TaxColumn(
        title: 'अन्यकर',
        annualDemand: bill?.otherCurrentTax,
        arrear: bill?.otherTaxArrear,
        interest: bill?.otherTaxInterest,
        totalDemand: bill?.othertaxNetAmount,
        monthlyInterest: bill?.otherTaxMonthlyInterest,
        discount: bill?.otherTaxDiscount,
        advance: bill?.otherTaxAdvance,
        payable: bill?.otherTaxPayable,
        deposited: paid?.otherTaxPaidAmount,
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

  static const List<String> _ones = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
    'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
    'Seventeen', 'Eighteen', 'Nineteen',
  ];

  static const List<String> _tens = [
    '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety',
  ];

  static String _below100(int n) {
    if (n < 20) return _ones[n];
    final unit = n % 10;
    return '${_tens[n ~/ 10]}${unit == 0 ? '' : ' ${_ones[unit]}'}';
  }

  static String _below1000(int n) {
    if (n < 100) return _below100(n);
    final rest = n % 100;
    return '${_ones[n ~/ 100]} Hundred${rest == 0 ? '' : ' and ${_below100(rest)}'}';
  }

  /// Indian numbering (crore / lakh / thousand); paise are dropped the same way
  /// the portal drops them.
  static String _amountInWords(double amount) {
    var rupees = amount.round();
    if (rupees <= 0) return 'Zero Rupees Only';

    final parts = <String>[];
    void take(int divisor, String name) {
      final count = rupees ~/ divisor;
      if (count > 0) {
        parts.add('${_below1000(count)} $name');
        rupees %= divisor;
      }
    }

    take(10000000, 'Crore');
    take(100000, 'Lakh');
    take(1000, 'Thousand');
    if (rupees > 0) parts.add(_below1000(rupees));

    return '${parts.join(' ')} Rupees Only';
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
                  'Property Tax Details',
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
              _fallbackRow('House Tax Net Amount', 'Rs. ${_amount(bill?.houseTaxNetAmount)}'),
              _fallbackRow('Water Tax Net Amount', 'Rs. ${_amount(bill?.waterTaxNetAmount)}'),
              _fallbackRow('Sewer Tax Net Amount', 'Rs. ${_amount(bill?.sewerTaxNetAmount)}'),
              _fallbackRow('Other Tax Net Amount', 'Rs. ${_amount(bill?.othertaxNetAmount)}'),
              _fallbackRow('Water Charge Net Amount', 'Rs. ${_amount(bill?.waterChargeNetAmount)}'),
              _fallbackRow('Net Demand', 'Rs. ${_amount(bill?.netDemand)}'),
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
                    pw.Text('Net Payable',
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
    required String? totalDemand,
    required String? monthlyInterest,
    required String? discount,
    required String? advance,
    required String? payable,
    required String? deposited,
    this.showsDiscountPercent = true,
  })  : annualDemandValue = PropertyTaxReceiptPdf._number(annualDemand),
        discountValue = PropertyTaxReceiptPdf._number(discount),
        depositedValue = PropertyTaxReceiptPdf._number(deposited),
        annualDemand = PropertyTaxReceiptPdf._amount(annualDemand),
        arrear = PropertyTaxReceiptPdf._amount(arrear),
        interest = PropertyTaxReceiptPdf._amount(interest),
        totalDemand = PropertyTaxReceiptPdf._amount(totalDemand),
        monthlyInterest = PropertyTaxReceiptPdf._amount(monthlyInterest),
        discount = PropertyTaxReceiptPdf._amount(discount),
        advance = PropertyTaxReceiptPdf._amount(advance),
        payable = PropertyTaxReceiptPdf._amount(payable),
        deposited = PropertyTaxReceiptPdf._amount(deposited);

  final String title;
  final String annualDemand;
  final String arrear;
  final String interest;
  final String totalDemand;
  final String monthlyInterest;
  final String discount;
  final String advance;
  final String payable;
  final String deposited;

  final double annualDemandValue;
  final double discountValue;
  final double depositedValue;

  /// The portal's discount note lists every head except जल शुल्क.
  final bool showsDiscountPercent;

  String get discountPercent {
    if (annualDemandValue <= 0) return '0.0%';
    return '${(discountValue / annualDemandValue * 100).toStringAsFixed(1)}%';
  }
}
