import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// ── Shared picker theme — white background, black text, emerald selection ──────
ThemeData _pickerTheme(BuildContext context) => ThemeData(
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF10B981),
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: Color(0xFF111827),
        secondary: Color(0xFF10B981),
        onSecondary: Colors.white,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF10B981),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: Colors.white,
        headerBackgroundColor: const Color(0xFF10B981),
        headerForegroundColor: Colors.white,
        dayForegroundColor: WidgetStateColor.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? Colors.white
                : const Color(0xFF111827)),
        dayBackgroundColor: WidgetStateColor.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? const Color(0xFF10B981)
                : Colors.transparent),
        todayForegroundColor: WidgetStateColor.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? Colors.white
                : const Color(0xFF10B981)),
        todayBackgroundColor: WidgetStateColor.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? const Color(0xFF10B981)
                : Colors.transparent),
        todayBorder: const BorderSide(color: Color(0xFF10B981), width: 1),
        weekdayStyle: const TextStyle(
            color: Color(0xFF4B5563), fontWeight: FontWeight.w600),
        dayStyle: const TextStyle(color: Color(0xFF111827)),
        yearForegroundColor: WidgetStateColor.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? Colors.white
                : const Color(0xFF111827)),
        yearBackgroundColor: WidgetStateColor.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? const Color(0xFF10B981)
                : Colors.transparent),
      ),
    );

// ── Filter data model ─────────────────────────────────────────────────────────
class EventFilters {
  String? category;
  String? city;
  bool? freeOnly;
  double? maxPrice;
  DateTime? dateFrom;
  DateTime? dateTo;

  bool get hasActiveFilters =>
      category != null ||
      city != null ||
      freeOnly == true ||
      maxPrice != null ||
      dateFrom != null ||
      dateTo != null;

  int get activeCount {
    int count = 0;
    if (category != null) count++;
    if (city != null) count++;
    if (freeOnly == true) count++;
    if (maxPrice != null) count++;
    if (dateFrom != null || dateTo != null) count++;
    return count;
  }

  EventFilters clone() => EventFilters()
    ..category = category
    ..city = city
    ..freeOnly = freeOnly
    ..maxPrice = maxPrice
    ..dateFrom = dateFrom
    ..dateTo = dateTo;
}

// ── Filter bottom sheet ───────────────────────────────────────────────────────
class FilterBottomSheet extends StatefulWidget {
  final EventFilters filters;
  final ValueChanged<EventFilters> onApply;

  const FilterBottomSheet({
    super.key,
    required this.filters,
    required this.onApply,
  });

  static void show({
    required BuildContext context,
    required EventFilters filters,
    required ValueChanged<EventFilters> onApply,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterBottomSheet(filters: filters, onApply: onApply),
    );
  }

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late EventFilters _local;
  final _priceController = TextEditingController();

  static const _kCategories = [
    'Music', 'Tech', 'Sports', 'Art', 'Food', 'Networking',
    'Gaming', 'Fitness', 'Comedy', 'Workshop', 'Party', 'Social', 'Adult Party', 'Other',
  ];

  static const _kCities = [
    'Mumbai', 'Delhi', 'Bangalore', 'Hyderabad', 'Chennai',
    'Kolkata', 'Pune', 'Ahmedabad', 'Jaipur', 'Lucknow',
    'Kochi', 'Goa', 'Surat', 'Chandigarh', 'Indore',
  ];

  @override
  void initState() {
    super.initState();
    _local = widget.filters.clone();
    if (_local.maxPrice != null) {
      _priceController.text = _local.maxPrice!.toInt().toString();
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  // ── Date pickers — light theme for full visibility ────────────────────────
  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _local.dateFrom ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) =>
          Theme(data: _pickerTheme(ctx), child: child!),
    );
    if (picked != null) setState(() => _local.dateFrom = picked);
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _local.dateTo ??
          (_local.dateFrom ?? DateTime.now())
              .add(const Duration(days: 1)),
      firstDate: _local.dateFrom ?? DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) =>
          Theme(data: _pickerTheme(ctx), child: child!),
    );
    if (picked != null) setState(() => _local.dateTo = picked);
  }

  void _clearAll() {
    setState(() {
      _local = EventFilters();
      _priceController.clear();
    });
  }

  void _apply() {
    final priceText = _priceController.text.trim();
    if (priceText.isNotEmpty) {
      _local.maxPrice = double.tryParse(priceText);
    } else {
      _local.maxPrice = null;
    }
    widget.onApply(_local);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // ── Handle ──
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Text('Filters',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827))),
                  const Spacer(),
                  if (_local.hasActiveFilters)
                    GestureDetector(
                      onTap: _clearAll,
                      child: const Text('Clear all',
                          style: TextStyle(
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFE5E7EB)),

            // ── Scrollable content ──
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [

                  // ── Category ──────────────────────────────────────────────
                  _SectionLabel('Category'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _kCategories.map((cat) {
                      final selected = _local.category == cat;
                      return GestureDetector(
                        onTap: () => setState(() =>
                            _local.category = selected ? null : cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF374151),
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // ── City ──────────────────────────────────────────────────
                  _SectionLabel('City'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _local.city,
                        hint: const Text('All cities',
                            style: TextStyle(
                                color: Color(0xFF9CA3AF), fontSize: 14)),
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        icon: const Icon(Icons.keyboard_arrow_down,
                            color: Color(0xFF9CA3AF)),
                        style: const TextStyle(
                            color: Color(0xFF111827), fontSize: 14),
                        items: [
                          const DropdownMenuItem(
                              value: null,
                              child: Text('All cities')),
                          ..._kCities.map((c) => DropdownMenuItem(
                              value: c, child: Text(c))),
                        ],
                        onChanged: (v) => setState(() => _local.city = v),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Price ─────────────────────────────────────────────────
                  _SectionLabel('Price'),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _local.freeOnly = false),
                        child: _TogglePill(
                          label: 'Any price',
                          selected: _local.freeOnly != true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(
                            () => _local.freeOnly = true),
                        child: _TogglePill(
                          label: 'Free only',
                          selected: _local.freeOnly == true,
                        ),
                      ),
                    ),
                  ]),

                  if (_local.freeOnly != true) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                          color: Color(0xFF111827), fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Max price (₹)',
                        hintStyle: const TextStyle(
                            color: Color(0xFF9CA3AF), fontSize: 14),
                        prefixIcon: const Icon(Icons.currency_rupee,
                            color: Color(0xFF9CA3AF), size: 18),
                        filled: true,
                        fillColor: const Color(0xFFF3F4F6),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFFE5E7EB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFFE5E7EB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF10B981), width: 1.5),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ── Date range ────────────────────────────────────────────
                  _SectionLabel('Date range'),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: _DateTile(
                        label: 'From',
                        date: _local.dateFrom,
                        onTap: _pickFrom,
                        onClear: _local.dateFrom != null
                            ? () => setState(() {
                                  _local.dateFrom = null;
                                  _local.dateTo = null;
                                })
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DateTile(
                        label: 'To',
                        date: _local.dateTo,
                        onTap: _local.dateFrom != null ? _pickTo : null,
                        onClear: _local.dateTo != null
                            ? () => setState(() => _local.dateTo = null)
                            : null,
                      ),
                    ),
                  ]),

                  const SizedBox(height: 32),
                ],
              ),
            ),

            // ── Apply button ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF34D399)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextButton(
                    onPressed: _apply,
                    child: Text(
                      _local.hasActiveFilters
                          ? 'Apply Filters (${_local.activeCount})'
                          : 'Apply Filters',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small helper widgets ──────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF111827),
        ),
      );
}

class _TogglePill extends StatelessWidget {
  final String label;
  final bool selected;
  const _TogglePill({required this.label, required this.selected});
  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF10B981) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? const Color(0xFF10B981)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF374151),
              fontWeight:
                  selected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      );
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  const _DateTile({
    required this.label,
    required this.date,
    required this.onTap,
    this.onClear,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: date != null
              ? const Color(0xFFECFDF5)
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: date != null
                ? const Color(0xFF10B981)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 15,
              color: date != null
                  ? const Color(0xFF10B981)
                  : const Color(0xFF9CA3AF),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                date != null
                    ? DateFormat('d MMM').format(date!)
                    : label,
                style: TextStyle(
                  color: date != null
                      ? const Color(0xFF111827)
                      : const Color(0xFF9CA3AF),
                  fontSize: 13,
                  fontWeight: date != null
                      ? FontWeight.w500
                      : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close,
                    size: 14, color: Color(0xFF9CA3AF)),
              ),
          ],
        ),
      ),
    );
  }
}