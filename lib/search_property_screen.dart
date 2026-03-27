import 'package:flutter/material.dart';

class SearchPropertyScreen extends StatefulWidget {
  const SearchPropertyScreen({super.key});

  @override
  State<SearchPropertyScreen> createState() => _SearchPropertyScreenState();
}

class _SearchPropertyScreenState extends State<SearchPropertyScreen> {
  final _ulbController = TextEditingController();
  final _ownerController = TextEditingController();
  final _fatherController = TextEditingController();
  String _searchMode = 'By Owner';

  @override
  void dispose() {
    _ulbController.dispose();
    _ownerController.dispose();
    _fatherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFCEFD8), Color(0xFFFFFFFF)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Search Mode Section
                  const Text(
                    'Search Method',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildModeChip('By Owner'),
                        const SizedBox(width: 8),
                        _buildModeChip('By Property ID'),
                        const SizedBox(width: 8),
                        _buildModeChip('By House No'),
                        const SizedBox(width: 8),
                        _buildModeChip('By Location'),
                        const SizedBox(width: 8),
                        _buildModeChip('By Mobile No'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Input Fields Section
                  const Text(
                    'Property Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInputField(
                    controller: _ulbController,
                    label: 'Choose ULB',
                    hint: 'Select urban local body',
                    icon: Icons.location_city_outlined,
                  ),
                  const SizedBox(height: 14),
                  _buildInputField(
                    controller: _ownerController,
                    label: 'Owner Name',
                    hint: 'Enter property owner name',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 14),
                  _buildInputField(
                    controller: _fatherController,
                    label: 'Father Name',
                    hint: 'Enter father name',
                    icon: Icons.family_restroom_outlined,
                  ),
                  const SizedBox(height: 32),

                  // Search Button
                  _buildSearchButton(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeChip(String title) {
    final isSelected = title == _searchMode;
    return ChoiceChip(
      label: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : Colors.grey.shade700,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFFE67514),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected
            ? const Color(0xFFE67514)
            : Colors.grey.shade300,
        width: 1.5,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      onSelected: (_) {
        setState(() {
          _searchMode = title;
        });
      },
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Icon(
                icon,
                color: const Color(0xFFE67514),
                size: 20,
              ),
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.grey.shade200,
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.grey.shade200,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE67514),
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE67514), Color(0xFFff9c3d)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE67514).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: MaterialButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Searching by $_searchMode...',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: const Color(0xFFE67514),
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        },
        minWidth: double.infinity,
        height: 56,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.search, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text(
              'Search Property',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
