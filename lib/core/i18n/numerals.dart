const _arabicIndic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

/// Converts ASCII digits in [input] to Arabic-Indic digits when [rtl] is true;
/// otherwise returns [input] unchanged. Non-digit characters are preserved.
String localizeDigits(String input, {required bool rtl}) {
  if (!rtl) return input;
  final sb = StringBuffer();
  for (final ch in input.runes) {
    if (ch >= 0x30 && ch <= 0x39) {
      sb.write(_arabicIndic[ch - 0x30]);
    } else {
      sb.writeCharCode(ch);
    }
  }
  return sb.toString();
}
