import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:viecnow/controller/login_controller.dart';
import 'package:viecnow/controller/update_account_controller.dart';

class ChangeDateOfBirthScreen extends StatefulWidget {
  const ChangeDateOfBirthScreen({super.key});

  @override
  State<ChangeDateOfBirthScreen> createState() =>
      _ChangeDateOfBirthScreenState();
}

class _ChangeDateOfBirthScreenState extends State<ChangeDateOfBirthScreen> {
  final TextEditingController _dateController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final UpdateAccountController _controller = Get.put(UpdateAccountController());
  bool _isLoading = false;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    final user = Get.find<AuthController>().currentUser;
    if (user != null && user.dateOfBirth != null) {
      _selectedDate = user.dateOfBirth;
      _dateController.text = DateFormat('dd/MM/yyyy').format(user.dateOfBirth!);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF2E7D32);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF666666)),
        ),
        title: const Text(
          'Cập nhật ngày sinh',
          style: TextStyle(
            color: Color(0xFF222222),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Vui lòng chọn ngày sinh của bạn:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF444444),
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _pickDate,
                  child: AbsorbPointer(
                    child: TextFormField(
                      controller: _dateController,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF222222),
                      ),
                      decoration: InputDecoration(
                        labelText: 'Ngày sinh',
                        hintText: 'Chọn ngày sinh (ngày/tháng/năm)',
                        prefixIcon: const Icon(Icons.calendar_today_rounded, color: primaryColor),
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: primaryColor, width: 1.8),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.redAccent),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.redAccent, width: 1.8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng chọn ngày sinh';
                        }
                        if (_selectedDate != null) {
                          final now = DateTime.now();
                          int age = now.year - _selectedDate!.year;
                          if (now.month < _selectedDate!.month ||
                              (now.month == _selectedDate!.month && now.day < _selectedDate!.day)) {
                            age--;
                          }
                          if (age < 18) {
                            return 'Bạn phải từ 18 tuổi trở lên';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            if (_formKey.currentState!.validate()) {
                              if (_selectedDate == null) return;
                              setState(() {
                                _isLoading = true;
                              });
                              try {
                                await _controller.updateDateOfBirth(_selectedDate!);
                                // Cập nhật local
                                final auth = Get.find<AuthController>();
                                if (auth.currentUser != null) {
                                  auth.currentUser = auth.currentUser!.copyWith(
                                    dateOfBirth: _selectedDate,
                                  );
                                  auth.update();
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Cập nhật ngày sinh thành công'),
                                      backgroundColor: primaryColor,
                                    ),
                                  );
                                  Navigator.pop(context);
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Lỗi: ${e.toString()}'),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    _isLoading = false;
                                  });
                                }
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Lưu thay đổi',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
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

  /// ===== Date Picker =====
  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime maxDate = DateTime(now.year - 18, now.month, now.day);
    
    // Nếu _selectedDate lớn hơn maxDate (người dùng chưa đủ 18 tuổi, do dữ liệu cũ),
    // chúng ta sẽ dùng maxDate làm initialDate để tránh lỗi date picker.
    DateTime initial = _selectedDate ?? maxDate;
    if (initial.isAfter(maxDate)) {
      initial = maxDate;
    }

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: maxDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2E7D32), // header background color
              onPrimary: Colors.white, // header text color
              onSurface: Color(0xFF222222), // body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2E7D32), // button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
        _dateController.text = DateFormat('dd/MM/yyyy').format(pickedDate);
      });
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }
}
