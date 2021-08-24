import 'package:flutter/foundation.dart';

debug(Object? object) {
  if (kDebugMode) {
    var now = DateTime.now();
    print("[DEBUG  ][${now.year}-${now.month}-${now.day} ${now.hour}:${now.minute}:${now.second}] $object");
  }
}

warn(Object? object) {
  var now = DateTime.now();
  print("[WARN  ][${now.year}-${now.month}-${now.day} ${now.hour}:${now.minute}:${now.second}] $object");
}

error(Object? object) {
  var now = DateTime.now();
  print("[ERROR  ][${now.year}-${now.month}-${now.day} ${now.hour}:${now.minute}:${now.second}] $object");
}

critical(Object? object) {
  var now = DateTime.now();
  print("[CRITICAL][${now.year}-${now.month}-${now.day} ${now.hour}:${now.minute}:${now.second}] $object");
}
