import 'package:enagarsewa/services/api_service.dart';
import 'package:enagarsewa/utils/property_tax_bill_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sample data mirrors a real "सम्पति कर बिल" print-out from the portal so the
/// tax-head mapping, the Grand Total and the deposits table stay pinned to it.
/// [apiIds] off stands for a ULB whose propertydetails response leaves the ids,
/// the assessment date and the receipt's book number blank.
Future<String> _billHtml({
  bool paid = true,
  String? ulbType = 'Nagar Palika Parishad',
  bool apiIds = true,
}) {
  return PropertyTaxBillPdf.buildHtml(
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
      otherTaxPayable: '0.0',
      netDemand: '1161.0',
      netPayble: '1161.0',
    ),
    owner: OwnerDetails(ownerName: 'Sudhar Singh', mobileNo: '9876596788'),
    property: PropertyInfo(
      wardName: 'WARD-15N',
      zoneName: 'Loni',
      mohallaName: '02-RAHUL GARDEN-II',
      houseNo: '355',
      propertyType: 'RES-ResidentialSelf',
      oldPropertyId: apiIds ? '05601011022018' : null,
      existingPropertyId: apiIds ? '22018' : null,
      dateOfAssessment: apiIds ? '01-04-2014' : null,
    ),
    ulbName: 'Loni',
    ulbType: ulbType,
    currReceipts: paid
        ? [
            ReceiptDetailsItem(
              receiptNo: 'R05626272040303',
              billNo: 'B05626270073709',
              receiptDate: '18-AUG-2026 13:26',
              paymentMode: 'Cash Payment',
              propertyTaxPaidAmount: '551.0',
              sewerTaxPaidAmount: '130.0',
              otherTaxPaidAmount: '480.0',
              bookNo: apiIds ? '56001' : null,
            ),
          ]
        : const [],
    arv: '2600.00',
    isKrutidev: false,
  );
}

void main() {
  test('bill prints the portal heading, title and property block', () async {
    final html = await _billHtml();

    expect(html, contains('सम्पति कर बिल'));
    expect(html, contains('नगर पालिका परिषद, Loni'));
    expect(html, contains('B05626270073709'));
    expect(html, contains('05601011022018'));
    expect(html, contains('RES-ResidentialSelf'));
    // Mobile numbers are masked the way the portal masks them.
    expect(html, contains('#####96788'));
    expect(html, isNot(contains('9876596788')));
  });

  test('ids and assessment date come from the propertydetails API', () async {
    final html = await _billHtml();

    expect(html, contains('पुरानी प्रापर्टी आईडी0</td>\n    <td class="val">05601011022018'));
    expect(html, contains('पुरानी आईडी0</td>\n    <td class="val">22018'));
    expect(html, contains('Date of Assessment</td>\n    <td class="val">01-04-2014'));
  });

  test('the API is the only source for the ids and the assessment date',
      () async {
    final html = await _billHtml(apiIds: false);

    expect(html, contains('पुरानी प्रापर्टी आईडी0</td>\n    <td class="val">-'));
    expect(html, contains('पुरानी आईडी0</td>\n    <td class="val">-'));
    expect(html, contains('Date of Assessment</td>\n    <td class="val">-'));
  });

  test('बुक संख्या is the receipt\'s own, and blank when the API omits it',
      () async {
    // The API's book number is unrelated to the financial year.
    expect(await _billHtml(), contains('>56001</td>'));

    final noBookNo = await _billHtml(apiIds: false);
    expect(noBookNo, contains('<td style="text-align:center"></td>'));
    // No stand-in derived from the financial year.
    expect(noBookNo, isNot(contains('>2026</td>')));
  });

  test('Grand Total is the sum of the देय धनराशि row', () async {
    // 551 + 0 + 0 + 130 + 0 = 681, the portal's Grand Total for this bill.
    expect(
      await _billHtml(),
      contains('सम्पूर्ण देय धनराशि योग (Grand Total) : 681.00'),
    );
  });

  test('deposits table is printed above and below the bill', () async {
    final html = await _billHtml();

    // 551 + 130 + 480 = 1161, the portal's "कुल जमा".
    expect(html, contains('R05626272040303'));
    expect(html, contains('1,161.00'));
    // The portal repeats the whole section either side of the bill.
    expect(
      'वित्तीय वर्ष 2026-27 में पूर्व जमा धनराशि के विवरण'.allMatches(html).length,
      2,
    );
  });

  test('deposits cover the payable, so nothing is left to pay', () async {
    expect(await _billHtml(), isNot(contains('भुगतान हेतु शेष राशि</td><td class="n">551.00')));
    expect(await _billHtml(), contains('भुगतान हेतु शेष राशि</td><td class="n">0.00'));
  });

  test('unpaid bill leaves the full payable outstanding', () async {
    final html = await _billHtml(paid: false);

    expect(html, contains('भुगतान हेतु शेष राशि</td><td class="n">551.00'));
    expect(
      html,
      contains('No Payment Transaction Done Through '
          'https://e-nagarsewaup.gov.in in the Financial Year 2026-27'),
    );
  });

  test('page margins are declared in CSS', () async {
    // The WebView print path only insets the page when @page carries a margin;
    // without this the bill is printed edge to edge.
    expect(await _billHtml(), contains('@page { size: A4; margin: 8mm; }'));
  });
}
