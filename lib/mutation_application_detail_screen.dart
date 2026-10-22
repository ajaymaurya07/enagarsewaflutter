import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:payu_checkoutpro_flutter/payu_checkoutpro_flutter.dart';
import 'package:payu_checkoutpro_flutter/PayUConstantKeys.dart';

import 'payment_result_screen.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';
import 'utils/mutation_ui.dart';

/// PayU CheckoutPro callbacks for the mutation fee payment. Hash generation
/// mirrors the property-tax flow; every terminal callback is handed back to
/// the screen, which cross-verifies with `api/mutation/verify-payment`.
class _MutationPayuDelegate implements PayUCheckoutProProtocol {
  final void Function(String unableToVerifyMessage) onFinished;
  PayUCheckoutProFlutter? _payu;

  _MutationPayuDelegate({required this.onFinished});

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
        for (final k in response.keys) {
          hashName = k?.toString();
          hashString = response[k]?.toString();
          break;
        }
      }

      debugPrint('[MutationPayU] generateHash -> hashName=$hashName');
      if (hashName == null || hashString == null) return;

      final hashRes = await ApiService.generateHash(hashName, hashString);
      final hash = hashRes.data;
      if (hash == null || hash.isEmpty) {
        debugPrint('[MutationPayU] generateHash -> empty hash from server');
        return;
      }

      await _payu?.hashGenerated(hash: {hashName: hash});
    } catch (e) {
      debugPrint('[MutationPayU] generateHash error -> $e');
    }
  }

  @override
  onError(Map? response) {
    debugPrint('[MutationPayU] onError -> $response');
    onFinished(_unableToVerify);
  }

  @override
  onPaymentCancel(Map? response) {
    debugPrint('[MutationPayU] onPaymentCancel -> $response');
    onFinished('Payment Cancelled. $_unableToVerify');
  }

  @override
  onPaymentFailure(response) {
    debugPrint('[MutationPayU] onPaymentFailure -> $response');
    onFinished(_unableToVerify);
  }

  @override
  onPaymentSuccess(response) {
    debugPrint('[MutationPayU] onPaymentSuccess -> $response');
    onFinished(_unableToVerify);
  }

  static const _unableToVerify =
      'Payment verification could not be completed. Please check your application status to confirm.';
}

/// Read-only view of a single mutation application, looked up by
/// acknowledgement number (Mutation Application Detail API).
class MutationApplicationDetailScreen extends StatefulWidget {
  final String ackNo;

  const MutationApplicationDetailScreen({super.key, required this.ackNo});

  @override
  State<MutationApplicationDetailScreen> createState() =>
      _MutationApplicationDetailScreenState();
}

class _MutationApplicationDetailScreenState
    extends State<MutationApplicationDetailScreen> {
  static const Color _primaryColor = MutationUi.primaryColor;
  static const Color _textColor = MutationUi.textColor;

  bool _isLoading = true;
  String? _errorMessage;
  MutationApplicationDetail? _details;
  bool _isPaying = false;
  String? _pendingTxnId;
  String? _pendingAmount;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await ApiService.getMutationApplicationDetail(
        ackNo: widget.ackNo,
      );
      if (!mounted) return;
      if (!response.success || response.data == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = response.message.isNotEmpty
              ? response.message
              : 'No mutation application found for this acknowledgement number.';
        });
        return;
      }
      setState(() {
        _details = response.data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage: 'Unable to fetch application details. Please try again.',
        );
      });
    }
  }

  bool _hasAmountToPay(MutationApplicationDetail details) =>
      (num.tryParse(details.amountToPayNow.trim()) ?? 0) > 0;

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Same gate as property-tax payment: send an OTP to the applicant's
  /// mobile and only open the payment once it is verified.
  Future<void> _handlePayNow() async {
    final details = _details;
    if (details == null || _isPaying) return;

    final mobileNo = details.mobileNo.trim();
    if (mobileNo.isEmpty) {
      _showSnackBar('Mobile number not available for OTP');
      return;
    }

    setState(() => _isPaying = true);
    try {
      debugPrint(
        '[MutationOtp] sendOtp -> mobileNo=$mobileNo, propertyId=${details.propertyId}',
      );
      final otpRes = await ApiService.sendOtp(mobileNo, details.propertyId);
      debugPrint(
        '[MutationOtp] sendOtp response -> success=${otpRes.success}, '
        'message=${otpRes.message}, maskedMobile=${otpRes.maskedMobile}',
      );
      if (!mounted) return;
      setState(() => _isPaying = false);

      if (otpRes.success == true) {
        final maskedNumber = otpRes.maskedMobile ??
            'XXXXXX${mobileNo.length > 4 ? mobileNo.substring(mobileNo.length - 4) : mobileNo}';
        _showOtpSheet(mobileNo, maskedNumber);
      } else {
        _showSnackBar(otpRes.message ?? 'Failed to send OTP');
      }
    } catch (e) {
      debugPrint('[MutationOtp] sendOtp error -> $e');
      if (!mounted) return;
      setState(() => _isPaying = false);
      _showSnackBar(
        ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage: 'Unable to send OTP right now. Please try again.',
        ),
      );
    }
  }

  void _showOtpSheet(String mobileNo, String maskedNumber) {
    final otpController = TextEditingController();
    bool isVerifying = false;
    String? sheetError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
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
                    'Verification Required',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Enter the OTP sent to $maskedNumber to proceed with payment.',
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade500),
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
                      prefixIcon: const Icon(Icons.pin_outlined, color: _primaryColor, size: 20),
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
                        borderSide: const BorderSide(color: _primaryColor, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isVerifying
                          ? null
                          : () async {
                              final otp = otpController.text.trim();
                              if (otp.isEmpty) {
                                setModalState(() => sheetError = 'Please enter OTP');
                                return;
                              }
                              if (otp.length < 4) {
                                setModalState(() => sheetError = 'Please enter valid OTP');
                                return;
                              }
                              final sheetNavigator = Navigator.of(context);
                              setModalState(() {
                                isVerifying = true;
                                sheetError = null;
                              });
                              try {
                                debugPrint('[MutationOtp] verifyOtp -> mobileNo=$mobileNo');
                                final res = await ApiService.verifyOtp(mobileNo, otp);
                                debugPrint(
                                  '[MutationOtp] verifyOtp response -> '
                                  'success=${res.success}, message=${res.message}',
                                );
                                if (res.success == true) {
                                  sheetNavigator.pop();
                                  _payNow();
                                } else {
                                  setModalState(() => sheetError = res.message ?? 'Invalid OTP');
                                }
                              } catch (e) {
                                debugPrint('[MutationOtp] verifyOtp error -> $e');
                                setModalState(
                                  () => sheetError = ApiService.getUserFriendlyErrorMessage(
                                    e,
                                    fallbackMessage:
                                        'Unable to verify OTP right now. Please try again.',
                                  ),
                                );
                              } finally {
                                if (context.mounted) {
                                  setModalState(() => isVerifying = false);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        disabledBackgroundColor: _primaryColor.withValues(alpha: 0.6),
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

  Future<void> _payNow() async {
    final details = _details;
    if (details == null || _isPaying) return;

    setState(() => _isPaying = true);
    try {
      final ulbId = await StorageService.getUlbCache() ?? await StorageService.getUlbId();
      final userId = await StorageService.getUserId();
      final ackNo = details.ackNo.isNotEmpty ? details.ackNo : widget.ackNo;
      debugPrint(
        '[MutationPayU] payNow -> ackNo=$ackNo, ulbId=$ulbId, userId=$userId, '
        'amountToPayNow=${details.amountToPayNow}',
      );

      if (ulbId == null || ulbId.isEmpty || userId == null || userId.isEmpty) {
        if (!mounted) return;
        _showSnackBar('Unable to start payment. Please login again and retry.');
        return;
      }

      final response = await ApiService.createMutationPayment(
        ackNo: ackNo,
        ulbId: ulbId,
        userId: userId,
      );
      if (!mounted) return;

      final txn = response.data;
      if (!response.success || txn == null) {
        _showSnackBar(
          response.message.isNotEmpty
              ? response.message
              : 'Unable to create payment right now. Please try again.',
        );
        return;
      }

      _pendingTxnId = txn.txnid;
      _pendingAmount = txn.amount;
      // PayU reports back through the delegate callbacks and
      // `openCheckoutScreen` may never complete, so release the button
      // before handing over to the checkout instead of waiting on it.
      setState(() => _isPaying = false);
      await _startPayuFlow(txn);
    } catch (e) {
      debugPrint('[MutationPayU] payNow error -> $e');
      if (!mounted) return;
      _showSnackBar(
        ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage: 'Unable to create payment right now. Please try again.',
        ),
      );
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  Future<void> _startPayuFlow(Transaction txn) async {
    final key = txn.key ?? '';
    final email = txn.email ?? '';

    final delegate = _MutationPayuDelegate(onFinished: _verifyPayment);
    final payu = PayUCheckoutProFlutter(delegate);
    delegate.setPayuInstance(payu);

    final payUPaymentParams = <String, dynamic>{
      PayUPaymentParamKey.key: key,
      PayUPaymentParamKey.amount: txn.amount ?? '',
      PayUPaymentParamKey.transactionId: txn.txnid ?? '',
      PayUPaymentParamKey.productInfo: txn.productinfo ?? '',
      PayUPaymentParamKey.firstName: txn.firstname ?? '',
      PayUPaymentParamKey.email: email,
      PayUPaymentParamKey.phone: txn.phone ?? '',
      PayUPaymentParamKey.android_surl: txn.surl ?? '',
      PayUPaymentParamKey.android_furl: txn.furl ?? '',
      PayUPaymentParamKey.ios_surl: txn.surl ?? '',
      PayUPaymentParamKey.ios_furl: txn.furl ?? '',
      PayUPaymentParamKey.environment: txn.resolvedPayuEnvironment,
      PayUPaymentParamKey.userCredential: '$key:$email',
      PayUPaymentParamKey.additionalParam: {
        PayUAdditionalParamKeys.udf1: txn.ulbId ?? '',
      },
    };
    final payUCheckoutProConfig = <String, dynamic>{
      PayUCheckoutProConfigKeys.merchantName: txn.merchantName ?? '',
    };

    debugPrint('[MutationPayU] openCheckout params -> $payUPaymentParams');
    debugPrint('[MutationPayU] openCheckout config -> $payUCheckoutProConfig');

    try {
      await payu.openCheckoutScreen(
        payUPaymentParams: payUPaymentParams,
        payUCheckoutProConfig: payUCheckoutProConfig,
      );
    } catch (e) {
      debugPrint('[MutationPayU] openCheckout error -> $e');
      if (!mounted) return;
      _showSnackBar(
        ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage: 'Unable to start PayU payment right now. Please try again.',
        ),
      );
    }
  }

  Future<void> _verifyPayment(String unableToVerifyMessage) async {
    final txnId = _pendingTxnId;
    final amount = _pendingAmount;
    if (!mounted) return;
    if (_isPaying) setState(() => _isPaying = false);

    if (txnId == null || txnId.isEmpty) {
      await _openResult(PaymentStatus.pending, message: unableToVerifyMessage);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator(color: _primaryColor)),
      ),
    );

    MutationVerifyPaymentResponse? res;
    try {
      res = await ApiService.verifyMutationPayment(txnid: txnId);
      debugPrint(
        '[MutationPayU] verify -> success=${res.success}, '
        'status=${res.paymentStatus}, data=${res.data}',
      );
    } catch (e) {
      debugPrint('[MutationPayU] verify error -> $e');
    }
    if (!mounted) return;
    Navigator.of(context).pop();

    // `success` is false for PENDING/FAILED too, so trust `payment_status`
    // whenever the server sent one; only fall back when there is none.
    final statusStr = res?.paymentStatus ?? '';
    if (res == null || statusStr.isEmpty) {
      await _openResult(
        PaymentStatus.pending,
        txnId: txnId,
        amount: amount,
        message: res != null && res.message.isNotEmpty
            ? res.message
            : unableToVerifyMessage,
      );
      return;
    }

    _pendingTxnId = null;
    final status = statusStr == 'SUCCESS'
        ? PaymentStatus.success
        : statusStr == 'FAILED' || statusStr == 'FAILURE'
            ? PaymentStatus.failure
            : PaymentStatus.pending;

    final details = <String, String>{};
    void add(String label, String? value) {
      if (value != null && value.isNotEmpty) details[label] = value;
    }

    add('Acknowledgement No.', res.field('ackNo') ?? _details?.ackNo ?? widget.ackNo);
    add('Property ID', res.field('propertyId') ?? _details?.propertyId);
    add('Payment Mode', res.field('paymentMode') ?? res.field('mode'));
    add('Bank Ref No.', res.field('bankRefNo') ?? res.field('bank_ref_num'));
    add('Payment Date', res.field('paymentDate') ?? res.field('addedon'));

    await _openResult(
      status,
      txnId: res.field('txnid') ?? txnId,
      amount: res.field('amount') ?? amount,
      message: res.message.isNotEmpty ? res.message : null,
      details: details,
    );
  }

  Future<void> _openResult(
    PaymentStatus status, {
    String? txnId,
    String? amount,
    String? message,
    Map<String, String> details = const {},
  }) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PaymentResultScreen(
        status: status,
        txnId: txnId,
        amount: amount,
        message: message,
        details: details,
      ),
    ));
    if (mounted) _fetchDetails();
  }

  void _copyAckNo() {
    Clipboard.setData(ClipboardData(text: widget.ackNo));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Acknowledgement number copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MutationUi.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _primaryColor,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Mutation Application',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: _textColor,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: _primaryColor,
        onRefresh: _fetchDetails,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _primaryColor));
    }

    if (_errorMessage != null || _details == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF4E8),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_off_rounded, size: 44, color: _primaryColor),
          ),
          const SizedBox(height: 20),
          Text(
            'Something went wrong',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Application details are not available.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _fetchDetails,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  'Retry',
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final details = _details!;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _buildHeaderCard(details),
        const SizedBox(height: 16),
        _buildSection(
          icon: Icons.home_work_outlined,
          title: 'Property & Previous Owner',
          rows: [
            ('Property ID', details.propertyId),
            ('Previous Owner', details.oldOwnerName),
            ("Father/Husband Name", details.oldFatherHusbandName),
            ('Mobile No.', details.oldMobileNo),
            ('Address', details.oldAddress),
            ('Zone / Ward / Mohalla',
                '${details.zoneName} / ${details.wardName} / ${details.mohallaName}'),
            ('Mutation Cause', MutationUi.prettify(details.mutationCauseString)),
            ('Property Occupied By', details.propertyOccupiedBy),
          ],
        ),
        const SizedBox(height: 16),
        _buildSection(
          icon: Icons.person_outline_rounded,
          title: 'New Owner / Applicant',
          rows: [
            ('Occupier Name', details.occupierName),
            ("Father/Husband Name", details.fatherHusbandName),
            ('Mobile No.', details.mobileNo),
            ('Alternate Mobile', details.alternateMobileNo),
            ('Email', details.emailId),
            ('Communication Address', details.communicationAddress),
            ('PIN Code', details.occPinCode),
          ],
        ),
        const SizedBox(height: 16),
        _buildFeesSection(details),
        if (_hasAmountToPay(details)) ...[
          const SizedBox(height: 16),
          _buildPayNowCard(details),
        ],
      ],
    );
  }

  Widget _buildPayNowCard(MutationApplicationDetail details) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Amount to Pay Now',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textColor,
                ),
              ),
              Text(
                '₹${MutationUi.formatAmount(details.amountToPayNow)}',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isPaying ? null : _handlePayNow,
              icon: _isPaying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.payment_rounded, size: 20),
              label: Text(
                _isPaying ? 'Please wait...' : 'Pay with PayU',
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _primaryColor.withValues(alpha: 0.6),
                disabledForegroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(MutationApplicationDetail details) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Acknowledgement No.',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  details.ackNo.isNotEmpty ? details.ackNo : widget.ackNo,
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _textColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: _copyAckNo,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.all(3),
                  child: Icon(Icons.copy_rounded, size: 16, color: _primaryColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Applied ${MutationUi.formatDate(details.ackDate)}',
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeesSection(MutationApplicationDetail details) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.receipt_long_rounded, 'Fees & Registry'),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Column(
              children: [
                _buildInfoRow('Property Cost', '₹${MutationUi.formatAmount(details.propertyCost)}'),
                _buildInfoRow('Registry Date', MutationUi.formatDate(details.registryDate)),
                _buildInfoRow('Current ARV', '₹${MutationUi.formatAmount(details.currentArv)}'),
                _buildInfoRow('Mutation Fees', '₹${MutationUi.formatAmount(details.mutationFees)}'),
                _buildInfoRow('Late Fees', '₹${MutationUi.formatAmount(details.lateFees)}'),
                _buildInfoRow('Publication Fees', '₹${MutationUi.formatAmount(details.publicationFees)}'),
                _buildInfoRow('Processing Fees', '₹${MutationUi.formatAmount(details.processingFees)}'),
                _buildInfoRow('ULB Processing Fees', '₹${MutationUi.formatAmount(details.ulbProcessingFees)}'),
                _buildInfoRow('Residual Fees', '₹${MutationUi.formatAmount(details.residualFees)}'),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Fees',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _textColor,
                  ),
                ),
                Text(
                  '₹${MutationUi.formatAmount(details.totalFees)}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required List<(String, String)> rows,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(icon, title),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [for (final (label, value) in rows) _buildInfoRow(label, value)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E8),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: _primaryColor),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: _textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isNotEmpty ? value.trim() : '-',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _textColor,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
