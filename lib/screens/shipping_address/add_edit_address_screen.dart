import 'package:flutter/material.dart';
import '/data/models/address_model.dart';
import '/controller/address_controller.dart';
import '../../data/services/list_location_service.dart';

class EditAddressScreen extends StatefulWidget {
  final AddressModel? address;

  const EditAddressScreen({super.key, this.address});

  @override
  State<EditAddressScreen> createState() => _EditAddressScreenState();
}

class _EditAddressScreenState extends State<EditAddressScreen> {
  final AddressController _controller = AddressController();
  final LocationService _locationService = LocationService();
  final _formKey = GlobalKey<FormState>();
  List<dynamic> _cities = [];
  List<dynamic> _wards = [];
  String? _selectedCity;
  String? _selectedWard;
  bool _isDefault = false;
  bool _isLoadingLocation = true;
  bool _isSaving = false;
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  // --- LOGIC GIỮ NGUYÊN ---
  Future<void> _loadCities() async {
    try {
      final cities = await _locationService.fetchCities();
      if (mounted) {
        setState(() {
          _cities = cities;
          _isLoadingLocation = false;
        });
        if (widget.address != null) {
          _selectedCity = widget.address!.city;
          _selectedWard = widget.address!.ward;
          _streetController.text = widget.address!.street;
          _numberController.text = widget.address!.number;
          _isDefault = widget.address!.isDefault;
          _loadWardsFromCity(_selectedCity);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _loadWardsFromCity(String? cityName) {
    if (cityName == null) return;
    final city = _cities.firstWhere(
      (c) => c['name'] == cityName,
      orElse: () => null,
    );
    if (city != null) setState(() => _wards = city['wards']);
  }

  void _onCityChanged(String? value) {
    setState(() {
      _selectedCity = value;
      _selectedWard = null;
      _wards = [];
    });
    _loadWardsFromCity(value);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final address = AddressModel(
      id: widget.address?.id ?? '',
      city: _selectedCity!,
      ward: _selectedWard!,
      street: _streetController.text.trim(),
      number: _numberController.text.trim(),
      isDefault: _isDefault,
      latitude: 0.0,
      longitude: 0.0,
    );
    try {
      if (widget.address == null) {
        await _controller.addAddress(address);
      } else {
        await _controller.updateAddress(address);
      }
      if (_isDefault && widget.address != null) {
        await _controller.setDefaultAddress(widget.address!.id);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- GIAO DIỆN MỚI ---
  @override
  Widget build(BuildContext context) {
    if (_isLoadingLocation) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return Scaffold(
      backgroundColor: Colors.grey[50], // Màu nền hơi xám cho nổi bật các card
      appBar: AppBar(
        title: Text(
          widget.address == null ? 'New Shipping Address' : 'Edit Address',
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle("Location Details"),
                const SizedBox(height: 12),
                // Dropdown Thành phố
                _buildDropdownContainer(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    // Chống tràn
                    value: _selectedCity,
                    hint: const Text("Select Province/City"),
                    decoration: _inputDecoration(Icons.location_city_outlined),
                    items: _cities
                        .map(
                          (city) => DropdownMenuItem(
                            value: city['name'] as String,
                            child: Text(
                              city['name'],
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _onCityChanged,
                    validator: (v) => v == null ? 'Please select a city' : null,
                  ),
                ),
                const SizedBox(height: 16),
                // Dropdown Phường xã
                _buildDropdownContainer(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    // Chống tràn
                    value: _selectedWard,
                    hint: const Text("Select Ward/Commune"),
                    decoration: _inputDecoration(Icons.map_outlined),
                    items: _wards
                        .map(
                          (ward) => DropdownMenuItem(
                            value: ward['name'] as String,
                            child: Text(
                              ward['name'],
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedWard = v),
                    validator: (v) => v == null ? 'Please select a ward' : null,
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle("Address Details"),
                const SizedBox(height: 12),
                // Đường
                TextFormField(
                  controller: _streetController,
                  decoration: _inputDecoration(
                    Icons.signpost_outlined,
                    label: "Street Name",
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Enter street name' : null,
                ),
                const SizedBox(height: 16),
                // Số nhà
                TextFormField(
                  controller: _numberController,
                  decoration: _inputDecoration(
                    Icons.home_outlined,
                    label: "House Number / Building",
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Enter house number' : null,
                ),
                const SizedBox(height: 16),
                // Switch Set Default (Nhìn sang chảnh hơn Checkbox)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _isDefault,
                    activeColor: Colors.blue,
                    title: const Text(
                      'Set as default address',
                      style: TextStyle(fontSize: 15),
                    ),
                    onChanged: (v) => setState(() => _isDefault = v),
                  ),
                ),
                const SizedBox(height: 40),
                // Nút Save
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Save Address',
                            style: TextStyle(
                              fontSize: 16,
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

  // --- HELPER WIDGETS ---
  InputDecoration _inputDecoration(IconData icon, {String? label}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.blue[400], size: 22),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.blue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.grey[600],
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildDropdownContainer({required Widget child}) {
    // Dùng container này để đồng bộ shadow và bo góc nếu cần
    return child;
  }

  @override
  void dispose() {
    _streetController.dispose();
    _numberController.dispose();
    super.dispose();
  }
}
