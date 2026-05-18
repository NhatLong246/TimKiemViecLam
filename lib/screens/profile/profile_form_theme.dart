import 'package:flutter/material.dart';

/// Giao diện form hồ sơ (tím) theo thiết kế mẫu.
class ProfileFormTheme {
  ProfileFormTheme._();

  static const Color primary = Color(0xFF5E35B1);
  static const Color required = Color(0xFFE64A4A);
  static const Color border = Color(0xFFD0D0D0);
  static const Color hint = Color(0xFFB0B0B0);

  static AppBar buildAppBar(BuildContext context, String title) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF666666)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF222222),
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static Widget requiredLabel(String text, {bool required = true}) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF222222),
        ),
        children: required
            ? const [
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: ProfileFormTheme.required),
                ),
              ]
            : const [],
      ),
    );
  }

  static InputDecoration fieldDecoration({
    required String hintText,
    int maxLines = 1,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: hint, fontSize: 15),
      contentPadding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: maxLines > 1 ? 14 : 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: required),
      ),
    );
  }

  static Widget saveBar({
    required bool saving,
    required bool enabled,
    required VoidCallback? onSave,
    String label = 'Lưu thông tin',
  }) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: SizedBox(
          height: 54,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: saving || !enabled ? null : onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              disabledBackgroundColor: const Color(0xFFD8D8D8),
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: saving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  static Widget selectField({
    required String value,
    required String placeholder,
    required VoidCallback onTap,
  }) {
    final hasValue = value.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                hasValue ? value : placeholder,
                style: TextStyle(
                  fontSize: 15,
                  color: hasValue ? const Color(0xFF222222) : hint,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF888888),
            ),
          ],
        ),
      ),
    );
  }

  static Widget dateField({
    required String value,
    required String placeholder,
    required VoidCallback? onTap,
    bool disabled = false,
  }) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: disabled ? const Color(0xFFF5F5F5) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value.isEmpty ? placeholder : value,
                style: TextStyle(
                  fontSize: 15,
                  color: value.isEmpty
                      ? (disabled ? const Color(0xFFCCCCCC) : hint)
                      : const Color(0xFF222222),
                ),
              ),
            ),
            Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: disabled ? const Color(0xFFCCCCCC) : const Color(0xFF888888),
            ),
          ],
        ),
      ),
    );
  }

  static Widget levelPills({
    required List<String> options,
    required String? selected,
    required ValueChanged<String> onSelect,
  }) {
    return Row(
      children: options.map((opt) {
        final active = selected == opt;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: opt != options.last ? 8 : 0),
            child: GestureDetector(
              onTap: () => onSelect(opt),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: active ? primary : border,
                    width: active ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  opt,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: active ? primary : const Color(0xFF555555),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  static Widget tipBox({required String title, required List<String> bullets}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F4FC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A4A6E),
              height: 1.35,
            ),
          ),
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(fontSize: 13, color: Color(0xFF1A4A6E)),
                  ),
                  Expanded(
                    child: Text(
                      b,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1A4A6E),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void showSnack(BuildContext context, String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.redAccent : primary,
      ),
    );
  }
}
