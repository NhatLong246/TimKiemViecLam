import '/data/models/address_model.dart';
import '/data/services/address_service.dart';

class AddressController {
  final AddressService _service = AddressService();

  Stream<List<AddressModel>> getAddresses() {
    return _service.getAddresses();
  }

  Future<void> addAddress(AddressModel address) async {
    await _service.addAddress(address);
  }

  Future<void> updateAddress(AddressModel address) async {
    await _service.updateAddress(address);
  }

  Future<void> setDefaultAddress(String id) async {
    await _service.setDefaultAddress(id);
  }

  Future<void> deleteAddress(String id) async {
    await _service.deleteAddress(id);
  }
}
