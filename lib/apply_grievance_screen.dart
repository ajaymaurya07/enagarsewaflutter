import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'services/api_service.dart';
import 'services/database_service.dart';

class ApplyGrievanceScreen extends StatefulWidget {
  const ApplyGrievanceScreen({super.key});

  @override
  State<ApplyGrievanceScreen> createState() => _ApplyGrievanceScreenState();
}

class _ApplyGrievanceScreenState extends State<ApplyGrievanceScreen> {
  static const Color _primaryColor = Color(0xFFE67514);
  static const Color _backgroundColor = Color(0xFFF8F9FB);
  static const Color _surfaceColor = Colors.white;
  static const Color _softPrimaryColor = Color(0xFFFFF3E8);
  static const Color _borderColor = Color(0xFFE4E8F0);
  static const Color _textPrimaryColor = Color(0xFF111827);
  static const Color _hintColor = Color(0xFF6B7280);

  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isSubmitting = false;

  // Personal Info Controllers
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _fatherNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // Location Details
  UlbData? _selectedUlb;
  ZoneData? _selectedZone;
  WardData? _selectedWard;
  MohallaData? _selectedMohalla;
  final TextEditingController _landmarkController = TextEditingController();

  // Grievance Details
  GrievanceCategory? _selectedCategory;
  GrievanceSubCategory? _selectedSubCategory;
  final TextEditingController _descriptionController = TextEditingController();

  List<UlbData> _ulbList = [];
  List<ZoneData> _zoneList = [];
  List<WardData> _wardList = [];
  List<MohallaData> _mohallaList = [];
  List<GrievanceCategory> _grievanceCategories = [];
  List<PropertyEntity> _savedProperties = [];
  PropertyEntity? _selectedProperty;
  
  bool _isLoadingUlbs = true;
  bool _isLoadingZones = false;
  bool _isLoadingWards = false;
  bool _isLoadingMohallas = false;
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    _fetchUlbs();
    _fetchGrievanceCategories();
    _loadSavedProperties();
  }

  Future<void> _loadSavedProperties() async {
    final properties = await DatabaseService.getAllProperties();
    setState(() {
      _savedProperties = properties;
    });
  }

  Future<void> _fetchUlbs() async {
    try {
      final ulbs = await ApiService.getUlbData();
      setState(() {
        _ulbList = ulbs;
        _isLoadingUlbs = false;
      });
    } catch (e) {
      setState(() => _isLoadingUlbs = false);
    }
  }

  Future<void> _fetchGrievanceCategories() async {
    try {
      final categories = await ApiService.getGrievanceCategories();
      setState(() {
        _grievanceCategories = categories;
        _isLoadingCategories = false;
      });
    } catch (e) {
      setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _fetchZones(String ulbId) async {
    setState(() => _isLoadingZones = true);
    try {
      final zones = await ApiService.getZoneData(ulbId);
      setState(() {
        _zoneList = zones;
        _isLoadingZones = false;
      });
    } catch (e) {
      setState(() => _isLoadingZones = false);
    }
  }

  Future<void> _fetchWards(String ulbId, String zoneId) async {
    setState(() => _isLoadingWards = true);
    try {
      final wards = await ApiService.getWardData(ulbId, zoneId);
      setState(() {
        _wardList = wards;
        _isLoadingWards = false;
      });
    } catch (e) {
      setState(() => _isLoadingWards = false);
    }
  }

  Future<void> _fetchMohallas(String ulbId, String zoneId, String wardId) async {
    setState(() => _isLoadingMohallas = true);
    try {
      final mohallas = await ApiService.getMohallaData(ulbId, zoneId, wardId);
      setState(() {
        _mohallaList = mohallas;
        _isLoadingMohallas = false;
      });
    } catch (e) {
      setState(() => _isLoadingMohallas = false);
    }
  }

  void _onPropertySelected(PropertyEntity property) {
    setState(() {
      _selectedProperty = property;
      _fullNameController.text = property.ownerName;
      _mobileController.text = property.phoneNumber;
      _emailController.text = property.email ?? "";
      _fatherNameController.text = property.fatherName ?? "N/A";
      _addressController.text = property.address ?? "N/A";
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final fileSizeInBytes = await file.length();
        if (fileSizeInBytes > 200 * 1024) {
          final sizeInKB = (fileSizeInBytes / 1024).toStringAsFixed(1);
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 28),
                    const SizedBox(width: 10),
                    Text('Image Too Large', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ],
                ),
                content: Text(
                  'Selected image size is ${sizeInKB}KB which exceeds the 200KB limit.\n\nPlease select a smaller image.',
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('OK', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _primaryColor)),
                  ),
                ],
              ),
            );
          }
          return;
        }
        setState(() {
          _selectedImage = file;
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Image Source',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSourceOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                _buildSourceOption(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceOption({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _softPrimaryColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _primaryColor, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _showSelectionSheet({
    required String title,
    required List<String> items,
    required Function(int) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SelectionSheet(
        title: title,
        items: items,
        onSelected: onSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          'Apply Grievance',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: _primaryColor),
        ),
        backgroundColor: _surfaceColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _primaryColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Property Information'),
                  const SizedBox(height: 12),
                  _buildSelectableField(
                    hint: _selectedProperty?.propertyId ?? 'Select Property ID',
                    onTap: _savedProperties.isEmpty 
                      ? null 
                      : () => _showSelectionSheet(
                        title: 'Select Property',
                        items: _savedProperties.map((e) => e.propertyId).toList(),
                        onSelected: (index) => _onPropertySelected(_savedProperties[index]),
                      ),
                  ),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Personal Information'),
                  const SizedBox(height: 12),
                  _buildTextField('Full Name', _fullNameController, icon: Icons.person_outline, enabled: false),
                  _buildTextField('Mobile Number', _mobileController, icon: Icons.phone_android_outlined, keyboardType: TextInputType.phone, enabled: false),
                  _buildTextField('Email ID', _emailController, icon: Icons.email_outlined, enabled: false),
                  _buildTextField('Father/Husband Name', _fatherNameController, icon: Icons.family_restroom_outlined, enabled: false),
                  _buildTextField('Address', _addressController, icon: Icons.location_on_outlined, maxLines: 2, enabled: false),
                  
                  const SizedBox(height: 24),
                  _buildSectionTitle('Location Details'),
                  const SizedBox(height: 12),
                  
                  // Select ULB
                  _buildSelectableField(
                    hint: _isLoadingUlbs ? 'Loading ULBs...' : (_selectedUlb?.toString() ?? 'Select ULB'),
                    onTap: _isLoadingUlbs ? null : () => _showSelectionSheet(
                      title: 'Select ULB',
                      items: _ulbList.map((e) => e.toString()).toList(),
                      onSelected: (index) {
                        setState(() {
                          _selectedUlb = _ulbList[index];
                          _selectedZone = null;
                          _selectedWard = null;
                          _selectedMohalla = null;
                          _zoneList = [];
                          _wardList = [];
                          _mohallaList = [];
                        });
                        _fetchZones(_selectedUlb!.ulbId!);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Select Zone
                  _buildSelectableField(
                    hint: _isLoadingZones ? 'Loading Zones...' : (_selectedZone?.zoneName ?? 'Select Zone'),
                    onTap: (_selectedUlb == null || _isLoadingZones) ? null : () => _showSelectionSheet(
                      title: 'Select Zone',
                      items: _zoneList.map((e) => e.zoneName).toList(),
                      onSelected: (index) {
                        setState(() {
                          _selectedZone = _zoneList[index];
                          _selectedWard = null;
                          _selectedMohalla = null;
                          _wardList = [];
                          _mohallaList = [];
                        });
                        _fetchWards(_selectedUlb!.ulbId!, _selectedZone!.zoneId);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Select Ward
                  _buildSelectableField(
                    hint: _isLoadingWards ? 'Loading Wards...' : (_selectedWard?.wardName ?? 'Select Ward'),
                    onTap: (_selectedZone == null || _isLoadingWards) ? null : () => _showSelectionSheet(
                      title: 'Select Ward',
                      items: _wardList.map((e) => e.wardName).toList(),
                      onSelected: (index) {
                        setState(() {
                          _selectedWard = _wardList[index];
                          _selectedMohalla = null;
                          _mohallaList = [];
                        });
                        _fetchMohallas(_selectedUlb!.ulbId!, _selectedZone!.zoneId, _selectedWard!.wardId);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Select Mohalla
                  _buildSelectableField(
                    hint: _isLoadingMohallas ? 'Loading Mohallas...' : (_selectedMohalla?.mohallaName ?? 'Select Mohalla'),
                    onTap: (_selectedWard == null || _isLoadingMohallas) ? null : () => _showSelectionSheet(
                      title: 'Select Mohalla',
                      items: _mohallaList.map((e) => e.mohallaName).toList(),
                      onSelected: (index) {
                        setState(() {
                          _selectedMohalla = _mohallaList[index];
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildTextField('Landmark', _landmarkController, icon: Icons.pin_drop_outlined, isRequired: true),

                  const SizedBox(height: 24),
                  _buildSectionTitle('Grievance Details'),
                  const SizedBox(height: 12),
                  
                  // Select Category
                  _buildSelectableField(
                    hint: _isLoadingCategories ? 'Loading Categories...' : (_selectedCategory?.serviceName ?? 'Select Category'),
                    onTap: _isLoadingCategories ? null : () => _showSelectionSheet(
                      title: 'Select Category',
                      items: _grievanceCategories.map((e) => e.serviceName ?? '').toList(),
                      onSelected: (index) {
                        setState(() {
                          _selectedCategory = _grievanceCategories[index];
                          _selectedSubCategory = null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Select Sub Category
                  _buildSelectableField(
                    hint: _selectedCategory == null ? 'Select Category First' : (_selectedSubCategory?.subName ?? 'Select Sub Category'),
                    onTap: _selectedCategory == null ? null : () => _showSelectionSheet(
                      title: 'Select Sub Category',
                      items: _selectedCategory!.subCategories!.map((e) => e.subName ?? '').toList(),
                      onSelected: (index) {
                        setState(() {
                          _selectedSubCategory = _selectedCategory!.subCategories![index];
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildTextField('Grievance Description', _descriptionController, maxLines: 4, isRequired: true),
                  
                  const SizedBox(height: 16),
                  _buildPhotoUploadSection(),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitGrievance,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isSubmitting 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Submit Grievance',
                            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          if (_isSubmitting)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(color: _primaryColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: _primaryColor,
      ),
    );
  }

  Widget _buildSelectableField({required String hint, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: const Border.fromBorderSide(BorderSide(color: _borderColor)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                hint,
                style: GoogleFonts.poppins(
                  color: hint.contains('Select') || hint.contains('Loading') ? _hintColor : _textPrimaryColor,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: _hintColor),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {IconData? icon, TextInputType keyboardType = TextInputType.text, int maxLines = 1, bool enabled = true, bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        enabled: enabled,
        style: GoogleFonts.poppins(fontSize: 14, color: enabled ? _textPrimaryColor : _hintColor),
        validator: isRequired ? (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter $label';
          }
          return null;
        } : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(color: _hintColor, fontSize: 14),
          prefixIcon: icon != null ? Icon(icon, color: _primaryColor, size: 20) : null,
          filled: true,
          fillColor: enabled ? _surfaceColor : const Color(0xFFF3F4F6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _primaryColor),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _borderColor),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoUploadSection() {
    return GestureDetector(
      onTap: _showImageSourceSheet,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: const Border.fromBorderSide(BorderSide(color: _borderColor)),
        ),
        child: _selectedImage != null
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _selectedImage!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedImage = null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  const Icon(Icons.camera_alt_outlined, color: _hintColor, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    'Upload Related Photo',
                    style: GoogleFonts.poppins(fontSize: 14, color: _hintColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '(Optional)',
                    style: GoogleFonts.poppins(fontSize: 12, color: _hintColor.withOpacity(0.8)),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _submitGrievance() async {
    // 1. Validate Form Fields (Edittexts)
    if (!_formKey.currentState!.validate()) return;

    // 2. Validate Custom Selectable Fields
    String? errorMessage;
    if (_selectedProperty == null) {
      errorMessage = 'Please select Property ID';
    } else if (_selectedUlb == null) errorMessage = 'Please select ULB';
    else if (_selectedZone == null) errorMessage = 'Please select Zone';
    else if (_selectedWard == null) errorMessage = 'Please select Ward';
    else if (_selectedMohalla == null) errorMessage = 'Please select Mohalla';
    else if (_selectedCategory == null) errorMessage = 'Please select Category';
    else if (_selectedSubCategory == null) errorMessage = 'Please select Sub Category';

    if (errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final response = await ApiService.saveGrievance(
        ulbId: _selectedUlb!.ulbId!,
        zoneId: _selectedZone!.zoneId,
        wardId: _selectedWard!.wardId,
        mohallaId: _selectedMohalla!.mohallaId,
        categoryId: _selectedCategory!.serviceCode.toString(),
        subCategoryId: _selectedSubCategory!.subCatCode.toString(),
        landmark: _landmarkController.text.trim(),
        description: _descriptionController.text.trim(),
        name: _fullNameController.text.trim(),
        fatherName: _fatherNameController.text.trim(),
        mobileNo: _mobileController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        propertyId: _selectedProperty!.propertyId,
        imageFile: _selectedImage,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (response.success && response.data?.grievanceId != null) {
          // Open OTP Bottom Sheet on Success
          _showOtpVerificationSheet(_mobileController.text.trim(), response.data!.grievanceId!);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.message), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showOtpVerificationSheet(String mobileNo, String grievanceId) {
    final TextEditingController otpController = TextEditingController();
    bool isVerifying = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
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
              Text(
                'Verify OTP',
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the OTP sent to $mobileNo to complete your grievance registration.',
                style: GoogleFonts.poppins(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                onChanged: (_) {
                  if (errorText != null) setModalState(() => errorText = null);
                },
                decoration: InputDecoration(
                  hintText: '000000',
                  counterText: "",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          errorText!,
                          style: GoogleFonts.poppins(color: Colors.red.shade700, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: isVerifying ? null : () async {
                  if (otpController.text.length < 4) return;
                  
                  setModalState(() {
                    isVerifying = true;
                    errorText = null;
                  });
                  try {
                    final res = await ApiService.registerGrievanceVerifyOtp(
                      mobileNo: mobileNo,
                      otp: otpController.text,
                      grievanceId: grievanceId,
                    );
                    debugPrint('OTP Verify Response => success: ${res.success}, message: ${res.message}, responseCode: ${res.responseCode}, data: ${res.data}');
                    if (res.success == true) {
                      if (!mounted) return;
                      Navigator.pop(sheetContext); // Close OTP sheet
                      _showSuccessDialog(res.message ?? 'Grievance Registered Successfully!', res.data ?? grievanceId);
                    } else {
                      if (!mounted) return;
                      setModalState(() => errorText = res.message ?? 'Invalid OTP');
                    }
                  } catch (e) {
                    if (!mounted) return;
                    setModalState(() => errorText = e.toString());
                  } finally {
                    if (mounted) setModalState(() => isVerifying = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isVerifying 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Verify & Register', style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog(String message, String? grievanceId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 28),
            const SizedBox(width: 10),
            Text('Success', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: GoogleFonts.poppins()),
            if (grievanceId != null) ...[
              const SizedBox(height: 12),
              Text('Grievance ID:', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(grievanceId, style: GoogleFonts.poppins(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back from Apply Screen
            },
            child: Text('OK', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class SelectionSheet extends StatefulWidget {
  final String title;
  final List<String> items;
  final Function(int) onSelected;

  const SelectionSheet({
    super.key, 
    required this.title,
    required this.items, 
    required this.onSelected
  });

  @override
  State<SelectionSheet> createState() => _SelectionSheetState();
}

class _SelectionSheetState extends State<SelectionSheet> {
  late List<String> filteredList;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    filteredList = widget.items;
  }

  void _filterSearch(String query) {
    setState(() {
      filteredList = widget.items
          .where((item) => item.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterSearch,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              itemCount: filteredList.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = filteredList[index];
                return ListTile(
                  title: Text(item, style: GoogleFonts.poppins(fontSize: 15)),
                  onTap: () {
                    final originalIndex = widget.items.indexOf(item);
                    widget.onSelected(originalIndex);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
