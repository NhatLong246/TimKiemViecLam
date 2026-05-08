import '/data/models/bank_account_model.dart';
import '/data/services/bank_account_service.dart';

class BankAccountController {
  final BankAccountService _service = BankAccountService();

  Stream<List<BankAccountModel>> getBanks() {
    return _service.getBanks();
  }

  Future<void> addBank(BankAccountModel bank) async {
    await _service.addBank(bank);
  }

  Future<void> updateBank(BankAccountModel bank) async {
    await _service.updateBank(bank);
  }

  Future<void> deleteBank(String id) async {
    await _service.deleteBank(id);
  }
}
