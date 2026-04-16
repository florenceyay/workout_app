import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class PlateCalculatorWidget extends StatefulWidget {
  final String unit;
  const PlateCalculatorWidget({super.key, required this.unit});

  @override
  State<PlateCalculatorWidget> createState() => _PlateCalculatorWidgetState();
}

class _PlateCalculatorWidgetState extends State<PlateCalculatorWidget> {
  final _controller = TextEditingController();
  bool _useKgBar = true; // 20kg vs 45lb bar
  List<_PlateResult> _results = [];

  static const _kgPlates = [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25];
  static const _lbPlates = [45.0, 35.0, 25.0, 10.0, 5.0, 2.5];

  void _calculate() {
    final target = double.tryParse(_controller.text);
    if (target == null || target <= 0) {
      setState(() => _results = []);
      return;
    }

    final barWeight = _useKgBar ? 20.0 : 45.0;
    final plates = widget.unit == 'kg' ? _kgPlates : _lbPlates;
    final perSide = (target - barWeight) / 2;

    if (perSide < 0) {
      setState(() => _results = []);
      return;
    }

    final results = <_PlateResult>[];
    var remaining = perSide;

    for (final plate in plates) {
      if (remaining <= 0) break;
      final count = (remaining / plate).floor();
      if (count > 0) {
        results.add(_PlateResult(weight: plate, count: count));
        remaining -= count * plate;
      }
    }

    setState(() => _results = results);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barLabel = _useKgBar ? '20 kg bar' : '45 lb bar';

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Plate Calculator',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Bar selector
          Row(
            children: [
              Text('Bar: ', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              GestureDetector(
                onTap: () => setState(() { _useKgBar = true; _calculate(); }),
                child: _BarChip(label: '20 kg', selected: _useKgBar),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() { _useKgBar = false; _calculate(); }),
                child: _BarChip(label: '45 lb', selected: !_useKgBar),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Target weight input
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            autofocus: true,
            onChanged: (_) => _calculate(),
            style: TextStyle(color: AppColors.textPrimary, fontSize: 20),
            decoration: InputDecoration(
              hintText: 'Target weight (${widget.unit})',
              hintStyle: TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.accent),
              ),
              suffixText: widget.unit,
              suffixStyle: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 16),

          // Results
          if (_controller.text.isNotEmpty) ...[
            if (_results.isEmpty)
              Text('Target weight is less than bar weight or invalid.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14))
            else ...[
              Text('Plates per side ($barLabel):',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _results.map((r) => _PlateChip(result: r, unit: widget.unit)).toList(),
              ),
            ],
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _PlateResult {
  final double weight;
  final int count;
  _PlateResult({required this.weight, required this.count});
}

class _PlateChip extends StatelessWidget {
  final _PlateResult result;
  final String unit;
  const _PlateChip({required this.result, required this.unit});

  @override
  Widget build(BuildContext context) {
    final wLabel = result.weight % 1 == 0
        ? result.weight.toStringAsFixed(0)
        : result.weight.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent.withOpacity(0.4)),
      ),
      child: Text(
        '${result.count}× $wLabel $unit',
        style: TextStyle(
            color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 16),
      ),
    );
  }
}

class _BarChip extends StatelessWidget {
  final String label;
  final bool selected;
  const _BarChip({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? AppColors.accent : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? AppColors.accent : AppColors.divider),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : AppColors.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          fontSize: 13,
        ),
      ),
    );
  }
}
