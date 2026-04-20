import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';
import 'services/database_service.dart';
import 'dashboard_screen.dart';

class PropertySelectionScreen extends StatefulWidget {
  final List<PropertyData> properties;

  const PropertySelectionScreen({super.key, required this.properties});

  @override
  State<PropertySelectionScreen> createState() => _PropertySelectionScreenState();
}

class _PropertySelectionScreenState extends State<PropertySelectionScreen> {
  bool _isLoading = false;
  PropertyDetailsData? _currentPropertyDetails;
  PropertyData? _selectedProperty;

  void _handlePropertySelection(PropertyData property) async {
    final propertyId = property.propertyId;
    if (propertyId == null) return;

    setState(() {
      _isLoading = true;
      _selectedProperty = property;
    });
    
    try {
      // 1. Get Property Details
      final res = await ApiService.getPropertyDetails(propertyId);
      _currentPropertyDetails = res.data;
      
      final mobileNo = _currentPropertyDetails?.ownerDetails?.mobileNo;

      if (mobileNo == null || mobileNo.isEmpty) {
        throw Exception('Mobile number not found for this property');
      }

      // 2. Send OTP
      final otpRes = await ApiService.sendOtp(mobileNo, propertyId);
      
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (otpRes.success == true) {
        _showOtpBottomSheet(mobileNo, propertyId);
      } else {
        _showSnackBar(otpRes.message ?? 'Failed to send OTP');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showOtpBottomSheet(String mobileNo, String propertyId) {
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
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
                  'Verify OTP',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enter the code sent to your mobile number ending in ${mobileNo.length > 4 ? mobileNo.substring(mobileNo.length - 4) : mobileNo}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 16),

                // Inline error
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

                // OTP Field
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

                // Verify Button
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

                      setModalState(() {
                        isVerifying = true;
                        sheetError = null;
                      });
                      try {
                        final res = await ApiService.verifyOtp(mobileNo, otpController.text);
                        if (res.success == true) {
                          final ulbId = await StorageService.getUlbId();
                          final totalArv = _selectedProperty?.totalArv?.toString() ?? "0.0";
                          final userId = res.userId?.toString() ?? "0";

                          await StorageService.saveTotalArv(totalArv);

                          final email = await StorageService.getEmailId();
                          final userType = await StorageService.getUserType();

                          await DatabaseService.insertProperty(
                            PropertyEntity(
                              propertyId: propertyId,
                              ownerName: _currentPropertyDetails?.ownerDetails?.ownerName ?? "N/A",
                              ward: _currentPropertyDetails?.propertyDetailsInfo?.wardName ?? "N/A",
                              mohalla: _currentPropertyDetails?.propertyDetailsInfo?.mohallaName ?? "N/A",
                              phoneNumber: mobileNo,
                              email: email,
                              userType: userType,
                              ulbId: ulbId,
                              arvValue: totalArv,
                              userId: userId,
                              fatherName: _selectedProperty?.fatherHusbandName ?? "N/A",
                              address: _selectedProperty?.address ?? "N/A",
                            ),
                          );

                          await StorageService.setPropertyVerified(true);

                          if (!mounted) return;
                          Navigator.pop(context); // Close sheet

                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (context) => const DashboardScreen()),
                            (route) => false,
                          );
                        } else {
                          if (!mounted) return;
                          setModalState(() => sheetError = res.message ?? 'Invalid OTP');
                        }
                      } catch (e) {
                        if (!mounted) return;
                        setModalState(() => sheetError = e.toString().replaceFirst('Exception: ', ''));
                      } finally {
                        if (mounted) setModalState(() => isVerifying = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE67514),
                      disabledBackgroundColor: const Color(0xFFE67514).withOpacity(0.6),
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
                            'Verify OTP',
                            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
                const SizedBox(height: 12),

                // Cancel
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
    );
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFCEFD8), Color(0xFFF8F9FB)],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // AppBar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Color(0xFFE67514), size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Text(
                          'Select Property',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF333333),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: widget.properties.isEmpty
                        ? Center(
                            child: Text(
                              'No properties found.',
                              style: GoogleFonts.poppins(
                                  fontSize: 14, color: Colors.grey.shade500),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: widget.properties.length,
                            itemBuilder: (context, index) {
                              final property = widget.properties[index];
                              return _buildPropertyCard(context, property);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black26,
            child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFE67514))),
          ),
      ],
    );
  }

  Widget _buildPropertyCard(BuildContext context, PropertyData property) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'PID: ${property.propertyId ?? "N/A"}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF333333),
                    ),
                  ),
                ),
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: () => _handlePropertySelection(property),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE67514),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: Text('Select',
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Owner Name', property.ownerName),
                const SizedBox(height: 8),
                _buildDetailRow('Father/Husband', property.fatherHusbandName),
                const SizedBox(height: 8),
                _buildDetailRow('House No', property.houseNo),
                const SizedBox(height: 8),
                _buildDetailRow('Address', property.address),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        Expanded(
          child: Text(
            value ?? 'N/A',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF333333),
            ),
          ),
        ),
      ],
    );
  }
}
