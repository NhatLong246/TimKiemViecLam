import 'package:flutter/material.dart';
import 'profile_form_theme.dart';

Future<String?> showProfileMonthYearPicker(BuildContext context) async {
  final now = DateTime.now();
  final result = await showDialog<DateTime>(
    context: context,
    builder: (ctx) => _MonthYearPickerDialog(initial: DateTime(now.year, now.month)),
  );
  if (result == null) return null;
  return '${result.month.toString().padLeft(2, '0')}/${result.year}';
}

Future<String?> showProfileYearPicker(BuildContext context) async {
  final now = DateTime.now();
  int year = now.year;

  final picked = await showDialog<int>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() => year--),
                ),
                Text(
                  '$year',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() => year++),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, year),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ProfileFormTheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Chọn'),
              ),
            ],
          );
        },
      );
    },
  );

  return picked?.toString();
}

Future<String?> showProfileOptionSheet(
  BuildContext context, {
  required String title,
  required List<String> options,
  String? selected,
}) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'Đóng',
                      style: TextStyle(color: ProfileFormTheme.primary),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (_, i) {
                  final opt = options[i];
                  final active = opt == selected;
                  return ListTile(
                    title: Text(opt),
                    trailing: active
                        ? const Icon(Icons.check, color: ProfileFormTheme.primary)
                        : null,
                    onTap: () => Navigator.pop(ctx, opt),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _MonthYearPickerDialog extends StatefulWidget {
  final DateTime initial;
  const _MonthYearPickerDialog({required this.initial});

  @override
  State<_MonthYearPickerDialog> createState() => _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<_MonthYearPickerDialog> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    _year = widget.initial.year;
    _month = widget.initial.month;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() => _year--),
          ),
          Text(
            '$_year',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() => _year++),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.2,
          children: List.generate(12, (i) {
            final m = i + 1;
            final selected = m == _month;
            return GestureDetector(
              onTap: () => setState(() => _month = m),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? ProfileFormTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? ProfileFormTheme.primary
                        : const Color(0xFFD0D0D0),
                  ),
                ),
                child: Text(
                  'T$m',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : const Color(0xFF333333),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, DateTime(_year, _month)),
          style: ElevatedButton.styleFrom(
            backgroundColor: ProfileFormTheme.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Chọn'),
        ),
      ],
    );
  }
}
