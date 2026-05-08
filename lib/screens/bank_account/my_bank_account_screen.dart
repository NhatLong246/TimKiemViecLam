import 'package:flutter/material.dart';
import '/controller/bank_account_controller.dart';
import '/data/models/bank_account_model.dart';
import 'add_edit_bank_account_screen.dart';

class MyBankAccountScreen extends StatelessWidget {
  final BankAccountController _controller = BankAccountController();

  MyBankAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE), // Nền xám nhạt cực sang
      appBar: AppBar(
        title: const Text(
          'My Bank Accounts',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
            onPressed: () => (context as Element).markNeedsBuild(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EditBankAccountScreen()),
          );
        },
        label: const Text(
          'Add Bank',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.blueAccent,
      ),
      body: StreamBuilder<List<BankAccountModel>>(
        stream: _controller.getBanks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final banks = snapshot.data ?? [];
          if (banks.isEmpty) {
            return _buildEmptyState(context);
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemCount: banks.length,
            itemBuilder: (context, index) {
              final bank = banks[index];
              return _buildBankCard(context, bank);
            },
          );
        },
      ),
    );
  }

  // 1. Widget cho từng thẻ ngân hàng
  Widget _buildBankCard(BuildContext context, BankAccountModel bank) {
    // Xử lý che số tài khoản an toàn
    String maskedNumber = bank.accountNumber.length > 4
        ? '**** **** ${bank.accountNumber.substring(bank.accountNumber.length - 4)}'
        : bank.accountNumber;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Thanh màu bên trái để tạo điểm nhấn
              Container(width: 6, color: Colors.blueAccent),
              const SizedBox(width: 12),
              // Logo ngân hàng
              Container(
                padding: const EdgeInsets.all(8),
                child: Image.network(
                  bank.logo,
                  width: 50,
                  height: 50,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.account_balance, size: 40),
                ),
              ),
              const SizedBox(width: 8),
              // Thông tin tài khoản
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bank.shortName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      maskedNumber,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              // Nút hành động
              _buildActionButtons(context, bank),
            ],
          ),
        ),
      ),
    );
  }

  // 2. Cụm nút bấm Edit/Delete
  Widget _buildActionButtons(BuildContext context, BankAccountModel bank) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.edit_note_rounded, color: Colors.blue),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditBankAccountScreen(bank: bank),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: Colors.redAccent,
          ),
          onPressed: () => _confirmDelete(context, bank),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // 3. Widget khi chưa có ngân hàng nào
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            'No bank account linked yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditBankAccountScreen()),
            ),
            child: const Text('Add your first account'),
          ),
        ],
      ),
    );
  }

  // 4. Dialog xác nhận xóa kiểu hiện đại
  Future<void> _confirmDelete(
    BuildContext context,
    BankAccountModel bank,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete account?'),
        content: Text(
          'Do you really want to remove ${bank.shortName} from your list?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _controller.deleteBank(bank.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed ${bank.shortName}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
