import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/api_service.dart';
import 'services/database_service.dart';

class PaymentGrievanceScreen extends StatefulWidget {
  final String propertyId;
  final PropertyDetailsData? propertyDetails;

  const PaymentGrievanceScreen({
    super.key,
    required this.propertyId,
    this.propertyDetails,
  });

  @override
  State<PaymentGrievanceScreen> createState() => _PaymentGrievanceScreenState();
}

class _PaymentGrievanceScreenState extends State<PaymentGrievanceScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  // Grievance category options
  final List<String> _grievanceCategories = [
    'Payment Tax',
    'Payment Not Uploaded',
    'Other',
  ];
  String? _selectedCategory;

  // Property selection
  List<PropertyEntity> _savedProperties = [];
  PropertyEntity? _selectedProperty;

  // Auto-filled fields
  final TextEditingController _zoneController = TextEditingController();
  final TextEditingController _wardController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedProperties();
  }

  @override
  void dispose() {
    _zoneController.dispose();
    _wardController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedProperties() async {
    final properties = await DatabaseService.getAllProperties();
    setState(() {
      _savedProperties = properties;
    });

    // Auto-select current property if available
    final match = properties.where((p) => p.propertyId == widget.propertyId);
    if (match.isNotEmpty) {
      _onPropertySelected(match.first);
    }
  }

  void _onPropertySelected(PropertyEntity property) {
    setState(() {
      _selectedProperty = property;
    });

    // Try to fill from API data if property matches the one passed in
    if (property.propertyId == widget.propertyId && widget.propertyDetails != null) {
      final prop = widget.propertyDetails!.propertyDetailsInfo;
      final owner = widget.propertyDetails!.ownerDetails;
      _zoneController.text = prop?.zoneName ?? '';
      _wardController.text = prop?.wardName ?? '';
      _nameController.text = owner?.ownerName ?? property.ownerName;
      _mobileController.text = owner?.mobileNo ?? property.phoneNumber;
      _addressController.text = prop?.address ?? property.address ?? '';
    } else {
      // Fill from DB entity
      _zoneController.text = '';
      _wardController.text = property.ward;
      _nameController.text = property.ownerName;
      _mobileController.text = property.phoneNumber;
      _addressController.text = property.address ?? '';
    }
  }

  void _showPropertySelectionSheet() {
    if (_savedProperties.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SelectionSheet(
        title: 'Select Property',
        items: _savedProperties.map((e) => e.propertyId).toList(),
        onSelected: (index) => _onPropertySelected(_savedProperties[index]),
      ),
    );
  }

  void _showCategorySelectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SelectionSheet(
        title: 'Select Grievance Category',
        items: _grievanceCategories,
        onSelected: (index) {
          setState(() {
            _selectedCategory = _grievanceCategories[index];
          });
        },
      ),
    );
  }

  Future<void> _submitGrievance() async {
    if (!_formKey.currentState!.validate()) return;

    String? errorMessage;
    if (_selectedCategory == null) {
      errorMessage = 'Please select a grievance category';
    } else if (_selectedProperty == null) {
      errorMessage = 'Please select a property';
    }

    if (errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
      return;
    }

    _showSuccessDialog('Grievance Saved Successfully!', null);
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
              Text(grievanceId,
                  style: GoogleFonts.poppins(
                      color: const Color(0xFF0E3B90), fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back from grievance screen
            },
            child: Text('OK', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(
          'Payment Grievance',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
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
                  // 1. Grievance Category
                  _buildSectionTitle('Grievance Category'),
                  const SizedBox(height: 12),
                  _buildSelectableField(
                    hint: _selectedCategory ?? 'Select Grievance Category',
                    onTap: _showCategorySelectionSheet,
                  ),

                  const SizedBox(height: 24),

                  // 2. Property Selection
                  _buildSectionTitle('Property Information'),
                  const SizedBox(height: 12),
                  _buildSelectableField(
                    hint: _selectedProperty?.propertyId ?? 'Select Property ID',
                    onTap: _savedProperties.isEmpty ? null : _showPropertySelectionSheet,
                  ),

                  const SizedBox(height: 24),

                  // 3. Auto-filled fields
                  _buildSectionTitle('Details'),
                  const SizedBox(height: 12),
                  _buildTextField('Zone', _zoneController, enabled: false),
                  _buildTextField('Ward', _wardController, enabled: false),
                  _buildTextField('Name', _nameController, enabled: false),
                  _buildTextField('Mobile Number', _mobileController, enabled: false),
                  _buildTextField('Address', _addressController, maxLines: 2, enabled: false),

                  const SizedBox(height: 24),

                  // 4. Describe Issue
                  _buildSectionTitle('Describe Issue'),
                  const SizedBox(height: 12),
                  _buildTextField(
                    'Describe your issue',
                    _descriptionController,
                    maxLines: 5,
                    isRequired: true,
                  ),

                  const SizedBox(height: 32),

                  // 5. Submit
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitGrievance,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0E3B90),
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
                child: CircularProgressIndicator(color: Color(0xFF0E3B90)),
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
        color: const Color(0xFF0E3B90),
      ),
    );
  }

  Widget _buildSelectableField({required String hint, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                hint,
                style: GoogleFonts.poppins(
                  color: hint.contains('Select') ? Colors.grey.shade600 : Colors.black,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool enabled = true,
    bool isRequired = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        enabled: enabled,
        style: GoogleFonts.poppins(fontSize: 14, color: enabled ? Colors.black : Colors.grey),
        validator: isRequired
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter $label';
                }
                return null;
              }
            : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14),
          prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF0E3B90), size: 20) : null,
          filled: true,
          fillColor: enabled ? Colors.white : Colors.grey.shade100,
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
            borderSide: const BorderSide(color: Color(0xFF0E3B90)),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
        ),
      ),
    );
  }
}

class _SelectionSheet extends StatefulWidget {
  final String title;
  final List<String> items;
  final Function(int) onSelected;

  const _SelectionSheet({
    required this.title,
    required this.items,
    required this.onSelected,
  });

  @override
  State<_SelectionSheet> createState() => _SelectionSheetState();
}

class _SelectionSheetState extends State<_SelectionSheet> {
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
      height: MediaQuery.of(context).size.height * 0.5,
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
                Text(widget.title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          if (widget.items.length > 5)
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
