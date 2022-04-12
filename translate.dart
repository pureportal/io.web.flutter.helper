import 'package:flutter_translate/flutter_translate.dart';

translateWithBackup(String key, String backup) {
  final String translatedText = translate(key);
  if (translatedText == key) {
    return backup;
  }
  return translatedText;
}

translatePluralWithBackup(String key, num value, String backup) {
  final String translatedText = translatePlural(key, value);
  if (translatedText == key) {
    return backup;
  }
  return translatedText;
}
