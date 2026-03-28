import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final deviceIdentityProvider = FutureProvider<String>((ref) async {
  return await DeviceIdentity.getDeviceId();
});

class DeviceIdentity {
  static const String _deviceIdKey = 'device_id';
  static const String _appInstallKey = 'app_install_id';

  /// Securely pull or initialize a permanent Device UUID tied to this install
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    
    var deviceId = prefs.getString(_deviceIdKey);
    
    // Fallback: Check physical OS directory which survives SharedPreferences wipes
    if (deviceId == null) {
      final directory = await getApplicationDocumentsDirectory();
      final backupFile = File('${directory.path}/kvm_device_id.sys');
      
      if (await backupFile.exists()) {
         deviceId = await backupFile.readAsString();
      } else {
         deviceId = const Uuid().v4();
         await backupFile.writeAsString(deviceId);
      }
      
      await prefs.setString(_deviceIdKey, deviceId);
      await prefs.setString(_appInstallKey, const Uuid().v4());
    }

    return deviceId;
  }
}

