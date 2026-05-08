import 'package:flutter/material.dart';
import '/data/models/bank_account_model.dart';
import '/controller/bank_account_controller.dart';
import '/data/services/list_bank_api_service.dart';

class EditBankAccountScreen extends StatefulWidget {
  final BankAccountModel? bank;

  const EditBankAccountScreen({super.key, this.bank});

  @override
  State<EditBankAccountScreen> createState() => _EditBankAccountScreenState();
}

class _EditBankAccountScreenState extends State<EditBankAccountScreen> {
  final _controller = BankAccountController();
  final _bankApiService = BankApiService();
  List<dynamic> _banks = [];
  dynamic _selectedBank;
  final _accountNumber = TextEditingController();
  final _accountHolderName = TextEditingController();

  // Thêm biến để theo dõi trạng thái đang xử lý
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBanks();
    if (widget.bank != null) {
      _accountNumber.text = widget.bank!.accountNumber;
      _accountHolderName.text = widget.bank!.accountHolderName;
    }
  }

  Future<void> _loadBanks() async {
    try {
      final banks = await _bankApiService.fetchBanks();
      if (mounted) {
        setState(() {
          _banks = banks;
          if (widget.bank != null) {
            // Tìm ngân hàng đã chọn dựa trên shortName hoặc code
            _selectedBank = _banks.firstWhere(
              (b) => b['shortName'] == widget.bank!.shortName,
              orElse: () => null,
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading banks: $e');
    }
  }

  Future<void> _save() async {
    // 1. Kiểm tra tính hợp lệ của dữ liệu (Validation)
    if (_selectedBank == null) {
      _showError('Please select a bank');
      return;
    }
    if (_accountNumber.text.trim().isEmpty) {
      _showError('Please enter account number');
      return;
    }
    if (_accountHolderName.text.trim().isEmpty) {
      _showError('Please enter account holder name');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final bank = BankAccountModel(
        id: widget.bank?.id ?? '',
        accountNumber: _accountNumber.text.trim(),
        accountHolderName: _accountHolderName.text.trim().toUpperCase(),
        // Tên thường viết hoa
        bankName: _selectedBank['name'],
        shortName: _selectedBank['shortName'],
        bankCode: _selectedBank['code'],
        bin: _selectedBank['bin'],
        logo: _selectedBank['logo'],
      );
      if (widget.bank == null) {
        await _controller.addBank(bank);
      } else {
        await _controller.updateBank(bank);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.bank == null
                  ? 'Bank account added'
                  : 'Bank account updated',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _bankInfo() {
    if (_selectedBank == null) return const SizedBox();
    return Card(
      elevation: 0,
      color: Colors.blue.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade100),
      ),
      margin: const EdgeInsets.only(top: 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          // Chuyển sang Row để tối ưu không gian chiều ngang
          children: [
            Image.network(
              _selectedBank['logo'],
              height: 40,
              width: 80,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 16),
            Expanded(
              // Expanded ở đây cực kỳ quan trọng để chống tràn chữ
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedBank['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Code: ${_selectedBank['code']} - BIN: ${_selectedBank['bin']}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.bank == null ? 'Add Bank Account' : 'Edit Bank Account',
        ),
        elevation: 0,
      ),
      body: GestureDetector(
        onTap: () =>
            FocusScope.of(context).unfocus(), // Chạm ra ngoài để tắt bàn phím
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Select Bank",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),

              /// Dropdown Bank - FIX OVERFLOW Ở ĐÂY
              DropdownButtonFormField<dynamic>(
                isExpanded: true,
                // Ép dropdown không được vượt quá chiều ngang màn hình
                value: _selectedBank,
                icon: const Icon(Icons.keyboard_arrow_down),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                hint: const Text("Choose a bank"),
                items: _banks.map((bank) {
                  return DropdownMenuItem(
                    value: bank,
                    child: Text(
                      bank['name'],
                      overflow: TextOverflow
                          .ellipsis, // Nếu tên quá dài sẽ hiện dấu "..."
                      maxLines: 1,
                    ),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedBank = value),
              ),
              _bankInfo(),
              const SizedBox(height: 24),
              const Text(
                "Account Details",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _accountNumber,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Account Number',
                  prefixIcon: const Icon(Icons.numbers),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _accountHolderName,
                textCapitalization:
                    TextCapitalization.characters, // Tự động viết hoa
                decoration: InputDecoration(
                  labelText: 'Account Holder Name',
                  prefixIcon: const Icon(Icons.person_outline),
                  helperText: "Example: NGUYEN VAN A",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              /// Nút bấm rộng đầy màn hình
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Save Bank Account',
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
    );
  }
}
