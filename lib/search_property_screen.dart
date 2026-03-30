import 'package:flutter/material.dart';
import 'package:enagarsewa/services/api_service.dart';

class SearchPropertyScreen extends StatefulWidget {
  const SearchPropertyScreen({super.key});

  @override
  State<SearchPropertyScreen> createState() => _SearchPropertyScreenState();
}

class _SearchPropertyScreenState extends State<SearchPropertyScreen> {
  final _ownerController = TextEditingController();
  final _fatherController = TextEditingController();
  final _propertyIdController = TextEditingController();
  final _houseNoController = TextEditingController();
  final _mobileController = TextEditingController();

  String _searchMode = 'By Owner';
  
  List<UlbData> _ulbList = [];
  UlbData? _selectedUlb;
  
  List<ZoneData> _zoneList = [];
  ZoneData? _selectedZone;
  
  List<WardData> _wardList = [];
  WardData? _selectedWard;
  
  List<MohallaData> _mohallaList = [];
  MohallaData? _selectedMohalla;
  
  bool _isLoadingUlbs = true;
  bool _isLoadingZones = false;
  bool _isLoadingWards = false;
  bool _isLoadingMohallas = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUlbData();
  }

  Future<void> _loadUlbData() async {
    setState(() {
      _isLoadingUlbs = true;
      _errorMessage = null;
    });
    try {
      final data = await ApiService.getUlbData();
      setState(() {
        _ulbList = data;
        _isLoadingUlbs = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingUlbs = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadZoneData(String ulbId) async {
    setState(() {
      _isLoadingZones = true;
      _zoneList = [];
      _selectedZone = null;
      _wardList = [];
      _selectedWard = null;
      _mohallaList = [];
      _selectedMohalla = null;
    });
    try {
      final data = await ApiService.getZoneData(ulbId);
      setState(() {
        _zoneList = data;
        _isLoadingZones = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingZones = false;
        _errorMessage = 'Failed to load zones';
      });
    }
  }

  Future<void> _loadWardData(String ulbId, String zoneId) async {
    setState(() {
      _isLoadingWards = true;
      _wardList = [];
      _selectedWard = null;
      _mohallaList = [];
      _selectedMohalla = null;
    });
    try {
      final data = await ApiService.getWardData(ulbId, zoneId);
      setState(() {
        _wardList = data;
        _isLoadingWards = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingWards = false;
        _errorMessage = 'Failed to load wards';
      });
    }
  }

  Future<void> _loadMohallaData(String ulbId, String zoneId, String wardId) async {
    setState(() {
      _isLoadingMohallas = true;
      _mohallaList = [];
      _selectedMohalla = null;
    });
    try {
      final data = await ApiService.getMohallaData(ulbId, zoneId, wardId);
      setState(() {
        _mohallaList = data;
        _isLoadingMohallas = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMohallas = false;
        _errorMessage = 'Failed to load mohallas';
      });
    }
  }

  void _showUlbSelection() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SelectionSheet(
        title: 'Select ULB',
        items: _ulbList.map((ulb) => '${ulb.ulbName} (${ulb.ulbType ?? ""})').toList(),
        onSelected: (index) {
          setState(() {
            _selectedUlb = _ulbList[index];
          });
          _loadZoneData(_selectedUlb!.ulbId);
        },
      ),
    );
  }

  void _showZoneSelection() {
    if (_selectedUlb == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select ULB first')));
      return;
    }
    if (_isLoadingZones) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SelectionSheet(
        title: 'Select Zone',
        items: _zoneList.map((z) => z.zoneName).toList(),
        onSelected: (index) {
          setState(() {
            _selectedZone = _zoneList[index];
          });
          _loadWardData(_selectedUlb!.ulbId, _selectedZone!.zoneId);
        },
      ),
    );
  }

  void _showWardSelection() {
    if (_selectedZone == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select Zone first')));
      return;
    }
    if (_isLoadingWards) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SelectionSheet(
        title: 'Select Ward',
        items: _wardList.map((w) => w.wardName).toList(),
        onSelected: (index) {
          setState(() {
            _selectedWard = _wardList[index];
          });
          _loadMohallaData(_selectedUlb!.ulbId, _selectedZone!.zoneId, _selectedWard!.wardId);
        },
      ),
    );
  }

  void _showMohallaSelection() {
    if (_selectedWard == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select Ward first')));
      return;
    }
    if (_isLoadingMohallas) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SelectionSheet(
        title: 'Select Mohalla',
        items: _mohallaList.map((m) => m.mohallaName).toList(),
        onSelected: (index) {
          setState(() {
            _selectedMohalla = _mohallaList[index];
          });
        },
      ),
    );
  }

  @override
  void dispose() {
    _ownerController.dispose();
    _fatherController.dispose();
    _propertyIdController.dispose();
    _houseNoController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Search Property For Login',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade300),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/background_pattern.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.white.withOpacity(0.9),
              BlendMode.lighten,
            ),
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: _buildModeButton('By Owner')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildModeButton('By Property ID')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildModeButton('By House No')),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(child: SizedBox(), flex: 1),
                    Expanded(flex: 5, child: _buildModeButton('By Location')),
                    const SizedBox(width: 8),
                    Expanded(flex: 5, child: _buildModeButton('By Mobile No')),
                    const Expanded(child: SizedBox(), flex: 1),
                  ],
                ),
                const SizedBox(height: 40),

                // Common ULB Picker
                _buildSelectableField(
                  hint: _isLoadingUlbs ? 'Loading ULBs...' : (_selectedUlb?.ulbName ?? 'Choose ULB'),
                  isSelected: _selectedUlb != null,
                  onTap: _isLoadingUlbs ? null : _showUlbSelection,
                ),
                
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                // Dynamic Fields based on Search Mode
                if (_searchMode == 'By Owner') ...[
                  _buildTextField('Enter owner name', _ownerController),
                  const SizedBox(height: 16),
                  _buildTextField('Enter father name', _fatherController),
                ] else if (_searchMode == 'By Property ID') ...[
                  _buildTextField('Enter property ID', _propertyIdController),
                ] else if (_searchMode == 'By House No') ...[
                  _buildSelectableField(
                    hint: _isLoadingZones ? 'Loading Zones...' : (_selectedZone?.zoneName ?? 'Choose Zone'),
                    isSelected: _selectedZone != null,
                    onTap: _showZoneSelection,
                  ),
                  const SizedBox(height: 16),
                  _buildSelectableField(
                    hint: _isLoadingWards ? 'Loading Wards...' : (_selectedWard?.wardName ?? 'Choose Ward'),
                    isSelected: _selectedWard != null,
                    onTap: _showWardSelection,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField('Enter house number', _houseNoController),
                ] else if (_searchMode == 'By Location') ...[
                  _buildSelectableField(
                    hint: _isLoadingZones ? 'Loading Zones...' : (_selectedZone?.zoneName ?? 'Choose Zone'),
                    isSelected: _selectedZone != null,
                    onTap: _showZoneSelection,
                  ),
                  const SizedBox(height: 16),
                  _buildSelectableField(
                    hint: _isLoadingWards ? 'Loading Wards...' : (_selectedWard?.wardName ?? 'Choose Ward'),
                    isSelected: _selectedWard != null,
                    onTap: _showWardSelection,
                  ),
                  const SizedBox(height: 16),
                  _buildSelectableField(
                    hint: _isLoadingMohallas ? 'Loading Mohallas...' : (_selectedMohalla?.mohallaName ?? 'Choose Mohalla'),
                    isSelected: _selectedMohalla != null,
                    onTap: _showMohallaSelection,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField('Enter house number', _houseNoController),
                ] else if (_searchMode == 'By Mobile No') ...[
                  _buildTextField('Enter mobile number', _mobileController),
                ],

                const SizedBox(height: 30),

                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE67514),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Search',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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

  Widget _buildModeButton(String title) {
    final isSelected = _searchMode == title;
    return GestureDetector(
      onTap: () => setState(() {
        _searchMode = title;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFBB017) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.grey.shade300,
          ),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.black87 : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectableField({required String hint, required bool isSelected, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                hint,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.grey.shade700,
                  fontSize: 16
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.grey.shade700),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: hint.contains('mobile') ? TextInputType.phone : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade700, fontSize: 16),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
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
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                  title: Text(item, style: const TextStyle(fontSize: 15)),
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
