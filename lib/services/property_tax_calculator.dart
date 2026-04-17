import 'dart:convert';
import 'package:flutter/services.dart';

class PropertyTaxCalculation {
  final double mrvOwner;
  final double mrvRented;
  final double arvOwner;
  final double arvRented;
  final double depreciation;
  final double appreciation;
  final double finalArvOwner;
  final double finalArvRented;
  final double ownerTax;
  final double rentedTax;
  final double totalTax;

  PropertyTaxCalculation({
    required this.mrvOwner,
    required this.mrvRented,
    required this.arvOwner,
    required this.arvRented,
    required this.depreciation,
    required this.appreciation,
    required this.finalArvOwner,
    required this.finalArvRented,
    required this.ownerTax,
    required this.rentedTax,
    required this.totalTax,
  });
}

class PropertyDetails {
  final String propertyId;
  final String ownerName;
  final String mobileNo;

  PropertyDetails({
    required this.propertyId,
    required this.ownerName,
    required this.mobileNo,
  });
}

class AreaAndStructureDetails {
  final String areaRate;
  final String constructionYear;
  final String ageOfStructure;

  AreaAndStructureDetails({
    required this.areaRate,
    required this.constructionYear,
    required this.ageOfStructure,
  });
}

class DepreciationAppreciation {
  final double depreciation;
  final double appreciation;

  DepreciationAppreciation(this.depreciation, this.appreciation);
}

class PropertyTaxCalculator {
  static PropertyTaxCalculation calculate({
    required double areaOwn,
    required double areaRent,
    required double rate,
    required int age,
  }) {
    final depApp = getDepreciationAppreciationByAge(age);

    final effectiveOwnArea = areaOwn * 0.80;
    final effectiveRentArea = areaRent * 0.80;

    final mrvOwner = effectiveOwnArea * rate;
    final mrvRented = effectiveRentArea * rate;

    final arvOwner = mrvOwner * 12;
    final arvRented = mrvRented * 12;

    final depreciation = arvOwner * depApp.depreciation / 100;
    final appreciation = arvRented * depApp.appreciation / 100;

    final finalArvOwner = arvOwner - depreciation;
    final finalArvRented = arvRented + appreciation;

    final ownerTax = finalArvOwner * 0.15;
    final rentedTax = finalArvRented * 0.15;

    return PropertyTaxCalculation(
      mrvOwner: mrvOwner,
      mrvRented: mrvRented,
      arvOwner: arvOwner,
      arvRented: arvRented,
      depreciation: depreciation,
      appreciation: appreciation,
      finalArvOwner: finalArvOwner,
      finalArvRented: finalArvRented,
      ownerTax: ownerTax,
      rentedTax: rentedTax,
      totalTax: ownerTax + rentedTax,
    );
  }

  static DepreciationAppreciation getDepreciationAppreciationByAge(int age) {
    if (age <= 5) return DepreciationAppreciation(0, 0);
    if (age <= 10) return DepreciationAppreciation(10, 10);
    if (age <= 15) return DepreciationAppreciation(20, 20);
    if (age <= 20) return DepreciationAppreciation(30, 30);
    if (age <= 25) return DepreciationAppreciation(40, 40);
    if (age <= 30) return DepreciationAppreciation(50, 50);
    return DepreciationAppreciation(50, 50);
  }
}

class RateMasterService {
  static List<Map<String, dynamic>>? _rateData;

  static Future<void> loadRateData() async {
    if (_rateData != null) return;
    final jsonString = await rootBundle.loadString('assets/rate_master.json');
    final List<dynamic> jsonList = jsonDecode(jsonString);
    _rateData = jsonList.cast<Map<String, dynamic>>();
  }

  /// roadWidth: 3 => >24m, 2 => 12-24m, 1 => <12m
  /// constructionType: RCC, OTHER, KACHA, PLOT
  static double getBaseRate({
    required String wardNo,
    required String constructionType,
    required int roadWidth,
  }) {
    if (_rateData == null) return 0.0;

    for (final obj in _rateData!) {
      if (obj['WardNo'] == wardNo) {
        switch (constructionType) {
          case 'RCC':
            switch (roadWidth) {
              case 3:
                return double.tryParse(obj['Pakka Bhawan RCC or RBC >24m road']?.toString() ?? '') ?? 0.0;
              case 2:
                return double.tryParse(obj['Pakka Bhawan RCC or RBC 12 to 24m road']?.toString() ?? '') ?? 0.0;
              default:
                return double.tryParse(obj['Pakka Bhawan RCC or RBC <12m road']?.toString() ?? '') ?? 0.0;
            }
          case 'OTHER':
            switch (roadWidth) {
              case 3:
                return double.tryParse(obj['Other Pakka Bhawan >24m road']?.toString() ?? '') ?? 0.0;
              case 2:
                return double.tryParse(obj['Other Pakka Bhawan 12 to 24m road']?.toString() ?? '') ?? 0.0;
              default:
                return double.tryParse(obj['Other Pakka Bhawan <12m road']?.toString() ?? '') ?? 0.0;
            }
          case 'KACHA':
            switch (roadWidth) {
              case 3:
                return double.tryParse(obj['Kacha Bhawan >24m road']?.toString() ?? '') ?? 0.0;
              case 2:
                return double.tryParse(obj['Kacha Bhawan 12 to 24m road']?.toString() ?? '') ?? 0.0;
              default:
                return double.tryParse(obj['Kacha Bhawan <12m road']?.toString() ?? '') ?? 0.0;
            }
          case 'PLOT':
            switch (roadWidth) {
              case 3:
                return double.tryParse(obj['Residential Plot In Which Building is Not Constructed >24m road']?.toString() ?? '') ?? 0.0;
              case 2:
                return double.tryParse(obj['Residential Plot In Which Building is Not Constructed 12 to 24m road']?.toString() ?? '') ?? 0.0;
              default:
                return double.tryParse(obj['Residential Plot In Which Building is Not Constructed <12m road']?.toString() ?? '') ?? 0.0;
            }
          default:
            return 0.0;
        }
      }
    }
    return 0.0;
  }

  static List<Map<String, String>> getWardList() {
    if (_rateData == null) return [];
    return _rateData!.map((e) => {
      'WardNo': e['WardNo']?.toString() ?? '',
      'WardName': e['WardName']?.toString() ?? '',
    }).toList();
  }
}
