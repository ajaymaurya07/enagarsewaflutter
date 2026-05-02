/// Help content constants for the Search Property screen fields.
class SearchPropertyHelp {
  SearchPropertyHelp._();

  static const String ulbTitle = 'Select ULB';
  static const String ulbMessage =
      'Select the Urban Local Body (ULB) — the municipality or town council '
      'under which your property is registered.\n\n'
      'If you are unsure, contact your local municipal office.';

  static const String ownerNameTitle = 'Owner Name';
  static const String ownerNameMessage =
      'Enter the full name of the property owner as registered '
      'in the municipal records.\n\nPartial names are also accepted.';

  static const String fatherNameTitle = 'Father Name';
  static const String fatherNameMessage =
      'Enter the father\'s or husband\'s name of the property owner '
      'as recorded in municipal records.\n\nUsed to narrow down search results.';

  static const String propertyIdTitle = 'Property ID';
  static const String propertyIdMessage =
      'Enter the unique Property ID assigned to your property by the municipality.\n\n'
      'You can find this ID on your previous tax receipts or municipal documents.';

  static const String zoneTitle = 'Zone';
  static const String zoneMessage =
      'Select the zone in which your property is located.\n\n'
      'Zones are administrative divisions used by the municipality '
      'to manage property records.';

  static const String wardTitle = 'Ward';
  static const String wardMessage =
      'Select the ward number or name for your property area.\n\n'
      'Wards are smaller divisions within a zone. '
      'Check your tax receipt or address documents for your ward.';

  static const String houseNumberTitle = 'House Number';
  static const String houseNumberMessage =
      'Enter the house/plot number as it appears on your property documents.\n\n'
      'Example: 12, 4B, or Plot-7.';

  static const String mohallaTitle = 'Mohalla';
  static const String mohallaMessage =
      'Select the mohalla (locality/neighbourhood) where your property is located.\n\n'
      'This helps narrow down the search within the selected ward.';

  static const String mobileNumberTitle = 'Mobile Number';
  static const String mobileNumberMessage =
      'Enter the 10-digit mobile number registered with the municipality '
      'for your property.\n\nExample: 9876543210';
}
