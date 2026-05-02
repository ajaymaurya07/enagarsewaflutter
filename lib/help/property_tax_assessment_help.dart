/// Help content constants for the Property Tax Assessment screen fields.
class PropertyTaxAssessmentHelp {
  PropertyTaxAssessmentHelp._();

  static const String ownerNameTitle = 'Owner Name';
  static const String ownerNameMessage =
      'Enter the full name of the property owner.\n\n'
      'This should match the name on your official property documents.';

  static const String fatherNameTitle = 'Father/Husband Name';
  static const String fatherNameMessage =
      'Enter the father\'s or husband\'s name of the property owner.\n\n'
      'This is used for identification in the assessment records.';

  static const String houseNoTitle = 'House No.';
  static const String houseNoMessage =
      'Enter your house or plot number.\n\n'
      'Example: 12, 4B, Plot-7.\n\n'
      'This can be found on your previous tax receipts or address documents.';

  static const String propertyIdTitle = 'Property ID';
  static const String propertyIdMessage =
      'Enter the unique Property ID assigned by the municipality.\n\n'
      'You can find this on your previous tax receipts or municipal documents.';

  static const String mobileNoTitle = 'Mobile No.';
  static const String mobileNoMessage =
      'Enter your 10-digit mobile number.\n\n'
      'This will be used for communications regarding your property assessment.';

  static const String rentAreaTitle = 'Rent Area';
  static const String rentAreaMessage =
      'Enter the area of the property that is rented out, in square feet.\n\n'
      'Enter 0 if no part of the property is rented.';

  static const String ownAreaTitle = 'Own Area';
  static const String ownAreaMessage =
      'Enter the area of the property used for self-occupation, in square feet.\n\n'
      'Total tax is calculated based on the combined rent and own area.';

  static const String constructionYearTitle = 'Construction Year';
  static const String constructionYearMessage =
      'Enter the year in which the property was constructed.\n\n'
      'Example: 1998, 2005.\n\n'
      'The age of the structure is calculated from this year and affects the tax rate.';
}
