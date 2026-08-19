import 'package:enagarsewa/services/api_service.dart';
import 'package:enagarsewa/utils/property_tax_receipt_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sample data mirrors a real "संपत्ति कर रसीद" print-out from the portal so the
/// tax-head mapping and the amount-in-words line stay pinned to it.
Future<String> _receiptHtml({bool paid = true, String? ulbType = 'Nagar Palika Parishad'}) {
  return PropertyTaxReceiptPdf.buildHtml(
    propertyId: '0905601012137596R',
    bill: BillDetails(
      billNo: 'B05626270073709',
      billDate: '17-04-2026',
      finYear: '2026-27',
      houseCurrentTax: '260.0',
      houseTaxArrear: '260.0',
      houseTaxInterest: '31.0',
      houseTaxNetAmount: '551.0',
      houseTaxPayable: '551.0',
      sewerCurrentTax: '65.0',
      sewerTaxArrear: '65.0',
      sewerTaxNetAmount: '130.0',
      sewerTaxPayable: '130.0',
      otherCurrentTax: '240.0',
      otherTaxArrear: '240.0',
      othertaxNetAmount: '480.0',
      netDemand: '1161.0',
      netPayble: '1161.0',
    ),
    owner: OwnerDetails(ownerName: 'Sudhar Singh', mobileNo: '9876596788'),
    property: PropertyInfo(wardName: 'WARD-15N'),
    ulbName: 'Loni',
    ulbType: ulbType,
    currReceipts: paid
        ? [
            ReceiptDetailsItem(
              receiptNo: 'R05626272040303',
              billNo: 'B05626270073709',
              receiptDate: '18-08-2026 13:26',
              paymentMode: 'Cash Payment',
              propertyTaxPaidAmount: '551.0',
              sewerTaxPaidAmount: '130.0',
              otherTaxPaidAmount: '480.0',
            ),
          ]
        : const [],
    arv: '2600.00',
    isKrutidev: false,
  );
}

void main() {
  test('ULB type is printed in Hindi next to the ULB name', () async {
    expect(await _receiptHtml(), contains('नगर पालिका परिषद, Loni'));
    // Signup codes come back from the same API.
    expect(await _receiptHtml(ulbType: 'NN'), contains('नगर निगम, Loni'));
    // Anything unmapped is printed as received rather than dropped.
    expect(await _receiptHtml(ulbType: 'Cantonment Board'), contains('Cantonment Board, Loni'));
    expect(await _receiptHtml(ulbType: null), contains('>Loni</td>'));
  });

  test('page margins are declared in CSS', () async {
    // The WebView print path only insets the page when @page carries a margin;
    // without this the receipt is printed edge to edge.
    expect(await _receiptHtml(), contains('@page { size: A4; margin: 8mm; }'));
  });

  test('paid bill prints the receipt header, totals and amount in words', () async {
    final html = await _receiptHtml();

    expect(html, contains('संपत्ति कर रसीद'));
    expect(html, contains('R05626272040303'));
    expect(html, contains('Cash Payment'));
    // 551 + 130 + 480 = 1161, the portal's "कुल जमा की गई धनराशि".
    expect(html, contains('अंको मे: <b>1161.00</b>'));
    expect(html, contains('One Thousand One Hundred and Sixty One Rupees Only'));
    // Mobile numbers are masked the way the portal masks them.
    expect(html, contains('#####96788'));
    expect(html, isNot(contains('9876596788')));
  });

  test('unpaid bill prints the bill title with nothing deposited', () async {
    final html = await _receiptHtml(paid: false);

    expect(html, contains('संपत्ति कर बिल'));
    expect(html, contains('अंको मे: <b>0.00</b>'));
    expect(html, contains('Zero Rupees Only'));
    expect(
      html,
      contains('No Previous Payment Transaction Done Through '
          'https://e-nagarsewaup.gov.in in the Financial Year 2026-27'),
    );
  });
}
