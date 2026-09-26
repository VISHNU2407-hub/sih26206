import 'package:flutter/services.dart';

class PickedContact {
  final String name;
  final String phone;

  const PickedContact({
    required this.name,
    required this.phone,
  });

  factory PickedContact.fromMap(Map<dynamic, dynamic> map) {
    return PickedContact(
      name: (map['name'] as String? ?? '').trim(),
      phone: (map['phone'] as String? ?? '').trim(),
    );
  }
}

class ContactPickerService {
  static const MethodChannel _channel =
      MethodChannel('village_verse/contact_picker');

  Future<PickedContact?> pickPhoneContact() async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'pickPhoneContact',
    );

    if (result == null) {
      return null;
    }

    return PickedContact.fromMap(result);
  }
}
