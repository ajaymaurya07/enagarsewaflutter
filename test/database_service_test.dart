import 'package:enagarsewa/services/api_service.dart';
import 'package:enagarsewa/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The bill print reads `oldPropertyId` and `arvValue` back out of the local DB,
/// so a field that is added to [PropertyEntity] but missed in `toMap` /
/// `fromMap` would silently print "-" on the bill instead of failing loudly.
void main() {
  test('propertysearch response carries the old property id and ARV', () {
    final property = PropertyData.fromJson({
      'propertyId': '0905601012137596R',
      'oldPropertyId': '05601011022018',
      'totalArv': 2600.0,
    });

    expect(property.oldPropertyId, '05601011022018');
    expect(property.totalArv, 2600.0);
  });

  test('old property id and ARV survive the toMap/fromMap round trip', () {
    final saved = PropertyEntity(
      propertyId: '0905601012137596R',
      ownerName: 'Sudhar Singh',
      ward: 'WARD-15N',
      mohalla: '02-RAHUL GARDEN-II',
      phoneNumber: '9876596788',
      oldPropertyId: '05601011022018',
      arvValue: '2600.0',
    );

    final row = saved.toMap();
    // The column has to exist in `property_table` under exactly this key,
    // otherwise `insertProperty` throws on every save.
    expect(row['oldPropertyId'], '05601011022018');

    final loaded = PropertyEntity.fromMap(row);
    expect(loaded.oldPropertyId, '05601011022018');
    expect(loaded.arvValue, '2600.0');
  });
}
