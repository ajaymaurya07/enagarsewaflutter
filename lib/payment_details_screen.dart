import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';
import 'services/database_service.dart';
import 'package:payu_checkoutpro_flutter/payu_checkoutpro_flutter.dart';
import 'package:payu_checkoutpro_flutter/PayUConstantKeys.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'payment_result_screen.dart';
import 'payment_history_screen.dart';
import 'apply_grievance_screen.dart';
import 'tour_guides/payment_details_tour.dart';
import 'utils/property_tax_bill_pdf.dart';
import 'utils/ulb_language_helper.dart';

class PaymentDetailsScreen extends StatefulWidget {
  final String propertyId;

  const PaymentDetailsScreen({super.key, required this.propertyId});

  @override
  State<PaymentDetailsScreen> createState() => _PaymentDetailsScreenState();
}

class _PayuDelegate implements PayUCheckoutProProtocol {
  final BuildContext context;
  PayUCheckoutProFlutter? _payu;
  _PayuDelegate(this.context);

  void setPayuInstance(PayUCheckoutProFlutter payu) {
    _payu = payu;
  }

  @override
  generateHash(Map response) async {
    try {
      String? hashName;
      String? hashString;

      if (response.containsKey('hashName') && response.containsKey('hashString')) {
        hashName = response['hashName']?.toString();
        hashString = response['hashString']?.toString();
      } else {
        // Sometimes map is like {"payment_hash": null} or {hashName:..., hashString:...}
        for (final k in response.keys) {
          hashName = k?.toString();
          final v = response[k];
          hashString = v?.toString();
          break;
        }
      }

      if (hashName == null || hashString == null) {
        return;
      }

      final hashRes = await ApiService.generateHash(hashName, hashString);
      final hash = hashRes.data;

      if (hash == null || hash.isEmpty) {
        return;
      }

      // send back to native SDK via plugin
      await _payu?.hashGenerated(hash: {hashName: hash});
    } catch (_) {}
  }


  @override
  onError(Map? response) {
    _verifyPayment();
  }

  @override
  onPaymentCancel(Map? response) {
    _verifyPaymentCancelled();
  }

  @override
  onPaymentFailure(response) {
    _verifyPayment();
  }

  @override
  onPaymentSuccess(response) {
    _verifyPayment();
  }

  void _verifyPayment() => _verify(
        'Payment verification could not be completed. Please check your Bill Receipt to confirm the status.',
      );

  void _verifyPaymentCancelled() => _verify(
        'Payment Cancelled. Verification could not be completed. Please check your Bill Receipt to confirm the status.',
      );

  void _verify(String unableToVerifyMessage) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _PayUVerifyingDialog(),
    );

    StorageService.getPayuMobileTransactionId().then((mobileTxnId) {
      if (mobileTxnId == null || mobileTxnId.isEmpty) {
        if (!context.mounted) return;
        Navigator.of(context).pop();
        _navigateUnableToVerify(unableToVerifyMessage);
        return;
      }
      ApiService.getTransactionDetails(mobileTxnId).then((res) {
        if (!context.mounted) return;
        Navigator.of(context).pop();
        if (res.status == true && res.data != null) {
          StorageService.clearPayuMobileTransactionId();
          _navigateFromVerify(res.data!);
        } else {
          _navigateUnableToVerify(unableToVerifyMessage);
        }
      }).catchError((e) {
        if (!context.mounted) return;
        Navigator.of(context).pop();
        _navigateUnableToVerify(unableToVerifyMessage);
      });
    }).catchError((e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      _navigateUnableToVerify(unableToVerifyMessage);
    });
  }

  void _navigateUnableToVerify(String message) {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => PaymentResultScreen(
        status: PaymentStatus.pending,
        message: message,
      ),
    ));
  }

  void _navigateFromVerify(PayUTransactionDetails data) {
    final statusStr = data.paymentStatus?.toUpperCase() ?? '';
    final PaymentStatus status;
    if (statusStr == 'SUCCESS') {
      status = PaymentStatus.success;
    } else if (statusStr == 'PENDING') {
      status = PaymentStatus.pending;
    } else if (statusStr == 'FAILED') {
      status = PaymentStatus.failure;
    } else {
      status = PaymentStatus.pending;
    }

    final details = <String, String>{};
    void add(String k, String? v) {
      if (v != null && v.isNotEmpty) details[k] = v;
    }
    void addAmt(String k, String? v) {
      if (v != null && v.isNotEmpty && v != '0.00' && v != '0') {
        details[k] = '₹ $v';
      }
    }

    add('Bill No', data.billNo);
    add('Property ID', data.propertyId);
    add('Financial Year', data.financialYear);
    add('Payment Mode', data.paymentMode?.toString());
    add('Owner Name', data.ownerName);
    add('Mobile', data.mobileNo);
    addAmt('Property Tax', data.propertyTaxPaid);
    addAmt('Water Tax', data.waterTaxPaid);
    addAmt('Sewer Tax', data.sewerTaxPaid);
    addAmt('Other Tax', data.otherTaxPaid);
    addAmt('Water Charge', data.waterChargePaid);

    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => PaymentResultScreen(
        status: status,
        txnId: data.txnid,
        amount: data.netPayable,
        details: details,
      ),
    ));
  }

}

class _PayUVerifyingDialog extends StatelessWidget {
  const _PayUVerifyingDialog();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(Color(0xFFE67514)),
                strokeWidth: 3,
              ),
              const SizedBox(height: 24),
              Text(
                'Verifying Payment…',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please wait while we confirm\nyour payment with the server.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentDetailsScreenState extends State<PaymentDetailsScreen> {
  final _keyPayTaxButton = GlobalKey();
  final _keyPrintPropertyButton = GlobalKey();
  final _keyAddGrievanceButton = GlobalKey();
  final _keyArvHistoryButton = GlobalKey();
  final _keyPaymentHistoryButton = GlobalKey();

  bool _isLoading = true;
  PropertyDetailsData? _details;
  String? _errorMessage;
  bool _showPropertyDetails = false;
  TutorialCoachMark? _tutorialCoachMark;
  bool _isKrutidev = false;
  String? _ulbName;
  String? _ulbType;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
    _loadUlbLanguagePreference();
    _loadUlbInfo();
  }

  /// ULB naam/type Receipt Details screen ki tarah nikalta hai — property ke
  /// `ulbId` ko ULB data list se match karke. Sirf print header ke liye chahiye,
  /// isliye fail hone par screen chupchaap chalti rahti hai.
  Future<void> _loadUlbInfo() async {
    try {
      final property = await DatabaseService.getPropertyById(widget.propertyId);
      final ulbId = property?.ulbId;
      if (ulbId == null || ulbId.isEmpty) return;

      final ulbList = await ApiService.getUlbData();
      final match = ulbList.where((u) => u.ulbId == ulbId).firstOrNull;
      if (match == null || !mounted) return;

      setState(() {
        _ulbName = match.ulbName;
        _ulbType = match.ulbType;
      });
    } catch (_) {
      // Print header propertydetails ke ulbName par fallback kar lega.
    }
  }

  Future<void> _loadUlbLanguagePreference() async {
    final isKrutidev = await UlbLanguageHelper.isKrutidev();
    if (!mounted) return;
    setState(() => _isKrutidev = isKrutidev);
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} "
           "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await ApiService.getPropertyDetails(widget.propertyId);
      if (response.success == true && response.data != null) {
        // Dashboard ka payment-status card ab DB se padhta hai, isliye is
        // property ki bill date aur net payable yahin cache kar dete hain.
        await _cacheBillInfo(response.data!);

        if (!mounted) return;

        setState(() {
          _details = response.data;
          _isLoading = false;
        });

        await WidgetsBinding.instance.endOfFrame;
        await _autoStartTourIfFirstVisit();
      } else {
        if (!mounted) return;

        setState(() {
          _errorMessage = response.message ?? "Failed to load details";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage:
              'Unable to load payment details right now. Please try again.',
        );
        _isLoading = false;
      });
    }
  }

  /// Is property id ke liye bill date + net payable local DB me likhta hai.
  /// Multiple properties saved ho sakti hain, isliye update hamesha
  /// `widget.propertyId` wali row par hi hota hai.
  Future<void> _cacheBillInfo(PropertyDetailsData data) async {
    try {
      await DatabaseService.updatePropertyBillInfo(
        propertyId: widget.propertyId,
        billDate: data.billDetails?.billDate,
        netPayable: data.billDetails?.netPayble,
      );
    } catch (_) {
      // Cache likhna optional hai — fail hone par screen normal chalti rahe.
    }
  }

  Future<void> _autoStartTourIfFirstVisit() async {
    if (_details == null) return;

    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('tour_payment_details') ?? false;
    if (!seen && mounted) {
      await prefs.setBool('tour_payment_details', true);
      await _startTour();
    }
  }

  void _showTourSegment({
    required TargetFocus target,
    VoidCallback? onFinish,
  }) {
    _tutorialCoachMark = PaymentDetailsTourGuide.createCoachMark(
      targets: [target],
      onAdvance: () => _tutorialCoachMark?.next(),
      onFinish: onFinish,
    )..show(context: context);
  }

  Future<void> _scrollToTourTarget(GlobalKey keyTarget) async {
    final targetContext = keyTarget.currentContext;
    if (targetContext == null) {
      return;
    }

    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
      alignment: 0.18,
    );
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<void> _showTourStep(
    List<PaymentDetailsTourStep> steps,
    int index,
  ) async {
    if (!mounted || index >= steps.length) {
      return;
    }

    final step = steps[index];
    await _scrollToTourTarget(step.keyTarget);
    if (!mounted) {
      return;
    }

    _showTourSegment(
      target: step.target,
      onFinish: () {
        _showTourStep(steps, index + 1);
      },
    );
  }

  Future<void> _startTour() async {
    if (_isLoading || _details == null || !mounted) return;

    final steps = PaymentDetailsTourGuide.buildSteps(
      payTaxButtonKey: _keyPayTaxButton,
      printPropertyButtonKey: _keyPrintPropertyButton,
      addGrievanceButtonKey: _keyAddGrievanceButton,
      arvHistoryButtonKey: _keyArvHistoryButton,
      paymentHistoryButtonKey: _keyPaymentHistoryButton,
    );

    await _showTourStep(steps, 0);
  }

  void _handleTourTap() {
    if (_isLoading) {
      _showSnackBar('Tour will be available after payment details are loaded.');
      return;
    }

    if (_details == null) {
      _showSnackBar('Payment details are not available right now.');
      return;
    }

    _startTour();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.poppins())),
    );
  }

  void _handlePayTax() async {
    final netPayable = double.tryParse(_details?.billDetails?.netPayble ?? '0') ?? 0.0;
    if (netPayable <= 0) {
      _showZeroPayableDialog();
      return;
    }

    final mobileNo = _details?.ownerDetails?.mobileNo;
    if (mobileNo == null || mobileNo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mobile number not available for OTP')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final otpRes = await ApiService.sendOtp(mobileNo, widget.propertyId);
      if (!mounted) return;

      setState(() => _isLoading = false);

      if (otpRes.success == true) {
        final maskedNumber = otpRes.maskedMobile ?? 'XXXXXX${mobileNo.length > 4 ? mobileNo.substring(mobileNo.length - 4) : mobileNo}';
        _showOtpAndPaymentDialog(mobileNo, maskedNumber);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(otpRes.message ?? 'Failed to send OTP')),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiService.getUserFriendlyErrorMessage(
              e,
              fallbackMessage:
                  'Unable to send OTP right now. Please try again.',
            ),
          ),
        ),
      );
    }
  }

  void _showZeroPayableDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFFE67514)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Nothing to Pay',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF333333),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'You cannot proceed with payment. Net Payable amount is ₹0.',
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE67514),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOtpAndPaymentDialog(String mobileNo, String maskedNumber) {
    final otpController = TextEditingController();
    bool isVerifying = false;
    String? sheetError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Verification Required',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enter the OTP sent to $maskedNumber to proceed with payment.',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 16),
                if (sheetError != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade600, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            sheetError!,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Enter OTP',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: GoogleFonts.poppins(fontSize: 14, letterSpacing: 4),
                  decoration: InputDecoration(
                    hintText: '------',
                    hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
                    prefixIcon: const Icon(Icons.pin_outlined, color: Color(0xFFE67514), size: 20),
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xFFF8F9FB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE67514), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isVerifying ? null : () async {
                      if (otpController.text.trim().isEmpty) {
                        setModalState(() => sheetError = 'Please enter OTP');
                        return;
                      }
                      if (otpController.text.length < 4) {
                        setModalState(() => sheetError = 'Please enter valid OTP');
                        return;
                      }
                      final sheetNavigator = Navigator.of(context);
                      setModalState(() {
                        isVerifying = true;
                        sheetError = null;
                      });
                      try {
                        final res = await ApiService.verifyOtp(mobileNo, otpController.text);
                        if (res.success == true) {
                          sheetNavigator.pop();
                          _showAmountSelectionSheet();
                        } else {
                          setModalState(() => sheetError = res.message ?? 'Invalid OTP');
                        }
                      } catch (e) {
                        setModalState(
                          () =>
                              sheetError = ApiService.getUserFriendlyErrorMessage(
                            e,
                            fallbackMessage:
                                'Unable to verify OTP right now. Please try again.',
                          ),
                        );
                      } finally {
                        if (mounted) setModalState(() => isVerifying = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE67514),
                      disabledBackgroundColor: const Color(0xFFE67514).withValues(alpha: 0.6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: isVerifying
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Verify & Proceed',
                            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: isVerifying ? null : () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ),
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }

  Future<InitiateTransactionRequest> _buildTransactionRequest({String? customAmount}) async {
    final propertyEntity = await DatabaseService.getPropertyById(widget.propertyId);

    final String ulbId = propertyEntity?.ulbId ?? "0";
    final String totalArvValue = propertyEntity?.arvValue ?? "0.0";
    final String userId = propertyEntity?.userId ?? "0";
    final String? email = await StorageService.getEmailId();

    // debugPrint(
      // '[PaymentTxn] propertyId=${widget.propertyId}, propertyFoundInDb=${propertyEntity != null}, '
      // 'ulbId=$ulbId, userId=$userId, totalArv=$totalArvValue, email=$email',
    // );

    final bill = _details?.billDetails;
    final owner = _details?.ownerDetails;

    final String mobileId = "MOBTXN${DateTime.now().millisecondsSinceEpoch}";
    final String timestamp = _getCurrentTime();

    return InitiateTransactionRequest(
      mobileTransactionId: mobileId,
      mobileTransactionTimestamp: timestamp,
      billNo: bill?.billNo ?? "",
      propertyId: widget.propertyId,
      ulbId: ulbId,
      financialYear: bill?.finYear ?? "",
      ownerName: owner?.ownerName ?? "",
      fatherName: owner?.fatherName ?? "",
      mobileNo: owner?.mobileNo ?? "",
      propertyTax: bill?.houseTaxNetAmount ?? "0",
      waterTax: bill?.waterTaxNetAmount ?? "0",
      sewerTax: bill?.sewerTaxNetAmount ?? "0",
      otherTax: bill?.othertaxNetAmount ?? "0",
      waterCharge: bill?.waterChargeNetAmount ?? "0",
      netDemand: bill?.netDemand ?? "0",
      netPayable: customAmount ?? bill?.netPayble ?? "0",
      totalArv: totalArvValue,
      userId: userId,
      emailId: email ?? "",
    );
  }

  Future<void> _handlePayuTransaction({String? customAmount}) async {
    setState(() => _isLoading = true);
    try {
      final request = await _buildTransactionRequest(customAmount: customAmount);
      final response = await ApiService.initiateTransaction(request);
      if (!mounted) return;

      setState(() => _isLoading = false);

      // debugPrint('[PaymentTxnAjay] _handlePayuTransaction error -> $response');

      if (response.status == true) {
        await StorageService.savePayuMobileTransactionId(
          request.mobileTransactionId,
        );
        _startPayuFlow(response.data);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message ?? 'Transaction failed')),
        );
      }
    } catch (e) {
      // debugPrint('[PaymentTxn] _handlePayuTransaction error -> $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiService.getUserFriendlyErrorMessage(
              e,
              fallbackMessage: 'Unable to create transaction right now. Please try again.',
            ),
          ),
        ),
      );
    }
  }

  void _showAmountSelectionSheet() {
    final bill = _details?.billDetails;
    final fullAmount = double.tryParse(bill?.netPayble ?? '0') ?? 0.0;
    final fullAmountStr = bill?.netPayble ?? '0';

    bool isPartial = false;
    final amountController = TextEditingController(text: fullAmountStr);
    String? amountError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Select Payment Amount',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pay the full amount or choose a partial payment.',
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 20),
                  // Full payment option
                  GestureDetector(
                    onTap: () => setSheetState(() {
                      isPartial = false;
                      amountError = null;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: !isPartial ? const Color(0xFFFFF4E5) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: !isPartial ? const Color(0xFFE67514) : Colors.grey.shade200,
                          width: !isPartial ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            !isPartial ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                            color: const Color(0xFFE67514),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Full Payment',
                                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  'Pay the complete due amount',
                                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₹ $fullAmountStr',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFE67514),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Partial payment option
                  GestureDetector(
                    onTap: () => setSheetState(() {
                      isPartial = true;
                      amountError = null;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isPartial ? const Color(0xFFFFF4E5) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPartial ? const Color(0xFFE67514) : Colors.grey.shade200,
                          width: isPartial ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isPartial ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                            color: const Color(0xFFE67514),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Partial Payment',
                                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  'Pay a custom amount (min ₹1)',
                                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isPartial) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Enter Amount',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      readOnly: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Enter amount',
                        hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 14, right: 8, top: 14, bottom: 14),
                          child: Text(
                            '₹',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFE67514),
                            ),
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                        suffixText: '/ ₹$fullAmountStr',
                        suffixStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade400),
                        errorText: amountError,
                        filled: true,
                        fillColor: const Color(0xFFF8F9FB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE67514), width: 1.5),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red, width: 1.5),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        String chosenAmount;
                        if (isPartial) {
                          final input = amountController.text.trim();
                          final parsed = double.tryParse(input);
                          if (input.isEmpty || parsed == null) {
                            setSheetState(() => amountError = 'Please enter a valid amount');
                            return;
                          }
                          if (parsed <= 0) {
                            setSheetState(() => amountError = 'Amount must be greater than ₹0');
                            return;
                          }
                          if (parsed > fullAmount) {
                            setSheetState(() => amountError = 'Amount cannot exceed ₹$fullAmountStr');
                            return;
                          }
                          chosenAmount = parsed.toStringAsFixed(2);
                        } else {
                          chosenAmount = fullAmountStr;
                        }
                        Navigator.pop(context);
                        _showPaymentMethodSelection(chosenAmount);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE67514),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        'Proceed to Payment',
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPaymentMethodSelection(String amount) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Select Payment Gateway',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Paying: ₹$amount',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE67514),
              ),
            ),
            const SizedBox(height: 20),
            _buildPaymentOptionCard('Pay with PayU', 'Safe & Secure', Icons.payment_rounded, () {
              Navigator.pop(context);
              _handlePayuTransaction(customAmount: amount);
            }),
            // const SizedBox(height: 12),
            // _buildPaymentOptionCard('Pay with SBI', 'Official SBI Gateway', Icons.account_balance_rounded, () {
            //   Navigator.pop(context);
            //   _handleSbiTransaction(customAmount: amount);
            // }),
            // const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }


  Future<void> _startPayuFlow(Transaction? txnData) async {
    if (txnData == null) return;
    setState(() => _isLoading = true);
    try {
      final key = txnData.key;
      final txnid = txnData.txnid;
      final amount = txnData.amount;
      final productinfo = txnData.productinfo;
      final firstname = txnData.firstname;
      final email = txnData.email;
      final surl = txnData.surl;
      final furl = txnData.furl;

      try {
        // Use the PayU plugin's actual API: PayUCheckoutProFlutter with a delegate.
        final delegate = _PayuDelegate(context);
        final payu = PayUCheckoutProFlutter(delegate);
        delegate.setPayuInstance(payu);

        final payUPaymentParams = <String, dynamic>{
          PayUPaymentParamKey.key: key,
          PayUPaymentParamKey.amount: amount,
          PayUPaymentParamKey.transactionId: txnid,
          PayUPaymentParamKey.productInfo: productinfo,
          PayUPaymentParamKey.firstName: firstname,
          PayUPaymentParamKey.email: email,
          PayUPaymentParamKey.phone: txnData.phone ?? '',
          PayUPaymentParamKey.android_surl: surl,
          PayUPaymentParamKey.android_furl: furl,
          PayUPaymentParamKey.ios_surl: surl,
          PayUPaymentParamKey.ios_furl: furl,
          PayUPaymentParamKey.environment: txnData.resolvedPayuEnvironment,
          PayUPaymentParamKey.userCredential: '$key:$email',
          PayUPaymentParamKey.additionalParam: {
            PayUAdditionalParamKeys.udf1: txnData.ulbId ?? '',
          },
        };

        final payUCheckoutProConfig = <String, dynamic>{
          PayUCheckoutProConfigKeys.merchantName: txnData.merchantName ?? '',
        };

        await payu.openCheckoutScreen(
          payUPaymentParams: payUPaymentParams,
          payUCheckoutProConfig: payUCheckoutProConfig,
        );
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ApiService.getUserFriendlyErrorMessage(
                e,
                fallbackMessage:
                    'Unable to start PayU payment right now. Please try again.',
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiService.getUserFriendlyErrorMessage(
              e,
              fallbackMessage:
                  'Unable to start payment right now. Please try again.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildPaymentOptionCard(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFE67514), size: 28),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold)),
                Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showPaymentHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentHistoryScreen(
          propertyId: widget.propertyId,
          currReceiptDetails: _details?.currReceiptDetails ?? [],
          prevReceiptDetails: _details?.prevReceiptDetails ?? [],
          ownerDetails: _details?.ownerDetails,
          propertyDetails: _details?.propertyDetailsInfo,
        ),
      ),
    );
  }

  /// Purani property id aur ARV, dono propertysearch API se aati hain aur
  /// property verify hote waqt DB me cache hoti hain. Us se pehle save hui
  /// properties me ye columns khaali reh jate hain, isliye print se pehle ek
  /// baar bhar dete hain — warna bill par "-" chhap jayega.
  Future<PropertyEntity?> _cacheSearchInfoIfMissing(PropertyEntity? property) async {
    final ulbId = property?.ulbId;
    if (property == null || ulbId == null || ulbId.isEmpty) return property;

    final needsOldId = !_hasValue(property.oldPropertyId);
    final needsArv = !_hasValue(property.arvValue) || _number(property.arvValue) <= 0;
    if (!needsOldId && !needsArv) return property;

    try {
      final results = await ApiService.searchProperty(
        ulbId: ulbId,
        searchType: 'PID',
        propertyId: widget.propertyId,
      );
      final match =
          results.where((p) => p.propertyId == widget.propertyId).firstOrNull ??
              results.firstOrNull;
      if (match == null) return property;

      await DatabaseService.updatePropertySearchInfo(
        propertyId: widget.propertyId,
        oldPropertyId: needsOldId ? match.oldPropertyId : null,
        arvValue: needsArv ? match.totalArv?.toString() : null,
      );
      return await DatabaseService.getPropertyById(widget.propertyId) ?? property;
    } catch (_) {
      // Search fail ho to bill in dono ke bina bhi print ho jaye.
      return property;
    }
  }

  static bool _hasValue(String? value) {
    final trimmed = value?.trim();
    return trimmed != null && trimmed.isNotEmpty && trimmed != 'null' && trimmed != '-';
  }

  static double _number(String? value) => double.tryParse(value?.trim() ?? '') ?? 0.0;

  Future<void> _printProperty() async {
    try {
      if (_ulbName == null) await _loadUlbInfo();
      final property = await _cacheSearchInfoIfMissing(
        await DatabaseService.getPropertyById(widget.propertyId),
      );
      final bytes = await PropertyTaxBillPdf.buildBytes(
        propertyId: widget.propertyId,
        bill: _details?.billDetails,
        owner: _details?.ownerDetails,
        property: _details?.propertyDetailsInfo,
        currReceipts: _details?.currReceiptDetails ?? const [],
        arv: property?.arvValue,
        ulbName: _ulbName,
        ulbType: _ulbType,
        oldPropertyId: property?.oldPropertyId,
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: 'property_tax_bill_${widget.propertyId}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiService.getUserFriendlyErrorMessage(
              e,
              fallbackMessage: 'Unable to print the bill right now. Please try again.',
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFFF5F5F5),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                color: const Color(0xFFF5F5F5),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Color(0xFFE67514), size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment Details',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF333333),
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'PID: ${widget.propertyId}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.help_outline_rounded,
                        color: Color(0xFFE67514),
                      ),
                      tooltip: 'Tour Guide',
                      onPressed: _handleTourTap,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFE67514)))
                      : _errorMessage != null
                          ? _buildErrorState()
                          : _buildContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.black87),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchDetails,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE67514)),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final bill = _details?.billDetails;
    final prop = _details?.propertyDetailsInfo;
    final owner = _details?.ownerDetails;

    final houseTaxAdvance = double.tryParse(bill?.houseTaxAdvance ?? '0') ?? 0.0;
    final waterTaxAdvance = double.tryParse(bill?.waterTaxAdvance ?? '0') ?? 0.0;
    final sewerTaxAdvance = double.tryParse(bill?.sewerTaxAdvance ?? '0') ?? 0.0;
    final otherTaxAdvance = double.tryParse(bill?.otherTaxAdvance ?? '0') ?? 0.0;
    final waterChargeAdvance = double.tryParse(bill?.waterChargeAdvance ?? '0') ?? 0.0;
    final totalAdvancePay = (houseTaxAdvance + waterTaxAdvance + sewerTaxAdvance + otherTaxAdvance + waterChargeAdvance).toStringAsFixed(2);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 1. Tax Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4E5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: Color(0xFFE67514), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Tax Summary',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF333333),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSummaryRow('Bill Date', bill?.billDate),
                _buildSummaryRow('Bill Number', bill?.billNo),
                _buildSummaryRow('Financial Year', bill?.finYear),
                FutureBuilder<PropertyEntity?>(
                  future: DatabaseService.getPropertyById(widget.propertyId),
                  builder: (context, snapshot) {
                    return _buildSummaryRow('Total Arv', snapshot.data?.arvValue ?? '0.0');
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, thickness: 0.8),
                ),
                _buildSummaryRow('House Tax Net Amount', bill?.houseTaxNetAmount),
                _buildSummaryRow('Water Tax Net Amount', bill?.waterTaxNetAmount),
                _buildSummaryRow('Sewer Tax Net Amount', bill?.sewerTaxNetAmount),
                _buildSummaryRow('Other Tax Net Amount', bill?.othertaxNetAmount),
                _buildSummaryRow('Water Charge Net Amount', bill?.waterChargeNetAmount),
                _buildSummaryRow('Net Demand', bill?.netDemand),
                _buildSummaryRow('Total Advance Tax Pay', totalAdvancePay),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFE0B2), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Net Payable',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFE67514),
                        ),
                      ),
                      Text(
                        '₹ ${bill?.netPayble ?? "0.0"}',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFE67514),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),

          // 2. Main Action Buttons (Moved inside scroll view)
          _buildPrimaryButton(
            'Pay Your Tax Online',
            _handlePayTax,
            key: _keyPayTaxButton,
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildSecondaryButton(
                      'Print Property',
                      Icons.print_outlined,
                      _printProperty,
                      key: _keyPrintPropertyButton,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSecondaryButton(
                      'Receipt Details',
                      Icons.payment_rounded,
                      _showPaymentHistory,
                      key: _keyPaymentHistoryButton,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildSecondaryButton(
                      'Apply Grievance',
                      Icons.add_comment_outlined,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ApplyGrievanceScreen(
                              preselectedPropertyId: widget.propertyId,
                              preselectedCategoryName:
                                  ApplyGrievanceScreen.propertyTaxCategoryName,
                              preselectedSubCategoryName: ApplyGrievanceScreen
                                  .assessmentSubCategoryName,
                            ),
                          ),
                        );
                      },
                      key: _keyAddGrievanceButton,
                    ),
                  ),
                ],
              ),
              // ARV History commented out
              // const SizedBox(height: 12),
              // Row(
              //   children: [
              //     Expanded(
              //       child: _buildSecondaryButton(
              //         'ARV History',
              //         Icons.history_rounded,
              //         () {},
              //         key: _keyArvHistoryButton,
              //       ),
              //     ),
              //     const SizedBox(width: 12),
              //     Expanded(
              //       child: _buildSecondaryButton(
              //         'Payment History',
              //         Icons.payment_rounded,
              //         _showPaymentHistory,
              //         key: _keyPaymentHistoryButton,
              //       ),
              //     ),
              //   ],
              // ),
            ],
          ),

          const SizedBox(height: 20),

          // 3. Property Details Card (Moved below buttons)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                ListTile(
                  onTap: () => setState(() => _showPropertyDetails = !_showPropertyDetails),
                  title: Text(
                    'Property Details',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF333333),
                    ),
                  ),
                  trailing: Icon(
                    _showPropertyDetails ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFFE67514),
                  ),
                ),
                if (_showPropertyDetails)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: [
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        _buildSummaryRow('Property/House Id', widget.propertyId),
                        _buildSummaryRow('Zone Name', prop?.zoneName),
                        _buildSummaryRow('Ward Name', prop?.wardName),
                        _buildSummaryRow('Mohalla Name', prop?.mohallaName),
                        _buildSummaryRow('House No.', prop?.houseNo),
                        _buildSummaryRow('Property Address', prop?.address, isLanguageSensitive: true),
                        _buildSummaryRow('Owner/Occupier Name', owner?.ownerName, isLanguageSensitive: true),
                        _buildSummaryRow('Owner Mobile Number', owner?.mobileNo),
                        _buildSummaryRow('Owner Father Name', owner?.fatherName, isLanguageSensitive: true),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String? value, {bool isLanguageSensitive = false}) {
    final useKrutidev = isLanguageSensitive && _isKrutidev;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Text(
              value ?? "N/A",
              textAlign: TextAlign.right,
              style: useKrutidev
                  ? const TextStyle(
                      fontFamily: UlbLanguageHelper.krutidevFontFamily,
                      fontSize: 13,
                      color: Color(0xFF444444),
                      fontWeight: FontWeight.w600,
                    )
                  : GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF444444),
                      fontWeight: FontWeight.w600,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(String text, VoidCallback onTap, {Key? key}) {
    return Container(
      key: key,
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFFE67514), Color(0xFFF0852D)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE67514).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(
    String text,
    IconData icon,
    VoidCallback onTap, {
    Key? key,
  }) {
    return SizedBox(
      key: key,
      height: 50,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE67514),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: EdgeInsets.zero,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
