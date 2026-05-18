import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'job_criteria_options.dart';

class SalaryPickerResult {
  final double? min;
  final double? max;
  final bool negotiable;

  const SalaryPickerResult({
    this.min,
    this.max,
    this.negotiable = false,
  });
}

/// Bottom sheet chọn nhiều mục (ngành nghề / địa điểm).
Future<List<String>?> showJobCriteriaCheckboxSheet({
  required BuildContext context,
  required String title,
  required String searchHint,
  required String primaryButtonLabel,
  required List<String> options,
  required List<String> initialSelected,
  required int maxItems,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _CheckboxPickerSheet(
      title: title,
      searchHint: searchHint,
      primaryButtonLabel: primaryButtonLabel,
      options: options,
      initialSelected: initialSelected,
      maxItems: maxItems,
    ),
  );
}

class _CheckboxPickerSheet extends StatefulWidget {
  final String title;
  final String searchHint;
  final String primaryButtonLabel;
  final List<String> options;
  final List<String> initialSelected;
  final int maxItems;

  const _CheckboxPickerSheet({
    required this.title,
    required this.searchHint,
    required this.primaryButtonLabel,
    required this.options,
    required this.initialSelected,
    required this.maxItems,
  });

  @override
  State<_CheckboxPickerSheet> createState() => _CheckboxPickerSheetState();
}

class _CheckboxPickerSheetState extends State<_CheckboxPickerSheet> {
  static const Color _primary = JobCriteriaOptions.primary;

  late List<String> _selected;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = List<String>.from(widget.initialSelected);
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _filtered {
    if (_query.isEmpty) return widget.options;
    return widget.options
        .where((o) => o.toLowerCase().contains(_query))
        .toList();
  }

  void _toggle(String item) {
    setState(() {
      if (_selected.contains(item)) {
        _selected.remove(item);
      } else if (_selected.length < widget.maxItems) {
        _selected.add(item);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.88;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
            child: Row(
              children: [
                const SizedBox(width: 48),
                Expanded(
                  child: Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF222222),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Đóng',
                    style: TextStyle(
                      color: _primary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: widget.searchHint,
                hintStyle: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 16),
                prefixIcon: const Icon(Icons.search, color: _primary),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _selected
                      .map(
                        (item) => _PinnedChip(
                          label: item,
                          onRemove: () => setState(() => _selected.remove(item)),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Đã chọn ${_selected.length}/${widget.maxItems}',
                style: const TextStyle(color: Color(0xFF888888), fontSize: 14),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                color: Color(0xFFF0F0F0),
              ),
              itemBuilder: (context, index) {
                final item = _filtered[index];
                final checked = _selected.contains(item);
                final disabled =
                    !checked && _selected.length >= widget.maxItems;
                return InkWell(
                  onTap: disabled ? null : () => _toggle(item),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item,
                            style: TextStyle(
                              fontSize: 17,
                              color: disabled
                                  ? const Color(0xFFBDBDBD)
                                  : const Color(0xFF333333),
                            ),
                          ),
                        ),
                        _RoundedCheckbox(checked: checked),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    widget.primaryButtonLabel,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet nhập khoảng lương.
Future<SalaryPickerResult?> showSalaryPickerSheet({
  required BuildContext context,
  double? initialMin,
  double? initialMax,
  bool initialNegotiable = false,
}) {
  return showModalBottomSheet<SalaryPickerResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _SalaryPickerSheet(
      initialMin: initialMin,
      initialMax: initialMax,
      initialNegotiable: initialNegotiable,
    ),
  );
}

class _SalaryPickerSheet extends StatefulWidget {
  final double? initialMin;
  final double? initialMax;
  final bool initialNegotiable;

  const _SalaryPickerSheet({
    this.initialMin,
    this.initialMax,
    this.initialNegotiable = false,
  });

  @override
  State<_SalaryPickerSheet> createState() => _SalaryPickerSheetState();
}

class _SalaryPickerSheetState extends State<_SalaryPickerSheet> {
  static const Color _primary = JobCriteriaOptions.primary;

  late final TextEditingController _minController;
  late final TextEditingController _maxController;
  late bool _negotiable;

  @override
  void initState() {
    super.initState();
    _minController = TextEditingController(
      text: widget.initialMin != null
          ? widget.initialMin!.toInt().toString()
          : '',
    );
    _maxController = TextEditingController(
      text: widget.initialMax != null
          ? widget.initialMax!.toInt().toString()
          : '',
    );
    _negotiable = widget.initialNegotiable;
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  void _clear() {
    setState(() {
      _minController.clear();
      _maxController.clear();
      _negotiable = false;
    });
  }

  void _apply() {
    if (_negotiable) {
      Navigator.pop(
        context,
        const SalaryPickerResult(negotiable: true),
      );
      return;
    }

    final min = double.tryParse(_minController.text.trim());
    final max = double.tryParse(_maxController.text.trim());

    if (min == null && max == null) {
      Navigator.pop(context, const SalaryPickerResult());
      return;
    }

    if (min != null && max != null && min > max) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mức tối thiểu không được lớn hơn mức tối đa'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      SalaryPickerResult(min: min, max: max),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                children: [
                  const SizedBox(width: 48),
                  const Expanded(
                    child: Text(
                      'Mức lương',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Đóng',
                      style: TextStyle(
                        color: _primary,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Nhập mức lương mong muốn:',
                  style: TextStyle(fontSize: 17, color: Color(0xFF333333)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(child: _buildSalaryBox(_minController, 'Tối thiểu')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSalaryBox(_maxController, 'Tối đa')),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 20, 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _negotiable,
                      activeColor: _primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (v) => setState(() {
                        _negotiable = v ?? false;
                        if (_negotiable) {
                          _minController.clear();
                          _maxController.clear();
                        }
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Lương thoả thuận',
                    style: TextStyle(fontSize: 16, color: Color(0xFF333333)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _clear,
                    child: const Text(
                      'Xóa',
                      style: TextStyle(
                        color: Color(0xFF333333),
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 140,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _apply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Áp dụng',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalaryBox(TextEditingController controller, String hint) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE4E4E4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !_negotiable,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Color(0xFFB0B0B0)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
              ),
            ),
          ),
          Container(
            width: 72,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF3F3F3),
              border: Border(left: BorderSide(color: Color(0xFFE4E4E4))),
            ),
            child: const Text(
              'Triệu',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF888888),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinnedChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _PinnedChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    const primary = JobCriteriaOptions.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: primary, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: primary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: primary, width: 1.2),
              ),
              child: const Icon(Icons.close, size: 12, color: primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundedCheckbox extends StatelessWidget {
  final bool checked;

  const _RoundedCheckbox({required this.checked});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: checked ? JobCriteriaOptions.primary : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: checked ? JobCriteriaOptions.primary : const Color(0xFFD0D0D0),
          width: 1.5,
        ),
      ),
      child: checked
          ? const Icon(Icons.check, size: 18, color: Colors.white)
          : null,
    );
  }
}
