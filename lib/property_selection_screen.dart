import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  void _handlePropertySelection(String propertyId) async {
    setState(() => _isLoading = true);
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 24, left: 24, right: 24
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Verify OTP',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the code sent to your mobile number ending in ${mobileNo.length > 4 ? mobileNo.substring(mobileNo.length - 4) : mobileNo}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: '000000',
                  counterText: "",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: isVerifying ? null : () async {
                  if (otpController.text.length < 4) return;
                  
                  setModalState(() => isVerifying = true);
                  try {
                    final res = await ApiService.verifyOtp(mobileNo, otpController.text);
                    if (res.success == true) {
                      // --- Database Storage Logic ---
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
                        ),
                      );

                      // Set verification flag for future app opens
                      await StorageService.setPropertyVerified(true);

                      if (!mounted) return;
                      Navigator.pop(context); // Close sheet
                      
                      // Navigate to Dashboard
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const DashboardScreen()),
                        (route) => false,
                      );
                    } else {
                      if (!mounted) return;
                      _showSnackBar(res.message ?? 'Invalid OTP');
                    }
                  } catch (e) {
                    if (!mounted) return;
                    _showSnackBar(e.toString());
                  } finally {
                    if (mounted) setModalState(() => isVerifying = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE67514),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isVerifying 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Verify OTP', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFE67514) : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Select Property',
              style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(height: 1, color: Colors.grey.shade300),
            ),
          ),
          body: widget.properties.isEmpty 
            ? const Center(child: Text('No properties found.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: widget.properties.length,
                itemBuilder: (context, index) {
                  final property = widget.properties[index];
                  return _buildPropertyCard(context, property);
                },
              ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black26,
            child: const Center(child: CircularProgressIndicator(color: Color(0xFFE67514))),
          ),
      ],
    );
  }

  Widget _buildPropertyCard(BuildContext context, PropertyData property) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'PID: ${property.propertyId ?? "N/A"}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: () => _handlePropertySelection(property.propertyId ?? ""),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE67514),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('Select', style: TextStyle(color: Colors.white, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade300),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Owner Name', property.ownerName),
                const SizedBox(height: 8),
                _buildDetailRow('Father/Husband Name', property.fatherHusbandName),
                const SizedBox(height: 8),
                _buildDetailRow('House Number', property.houseNo),
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
    return Text('$label: ${value ?? "N/A"}', style: TextStyle(fontSize: 14, color: Colors.grey.shade700, fontWeight: FontWeight.w500));
  }
}
