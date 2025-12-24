import 'package:flutter/material.dart';
import 'package:banshee_run_app/src/utils/constants.dart';
import 'package:banshee_run_app/src/utils/formatters.dart';

class PaceSelector extends StatefulWidget {
  final double initialPaceSecPerKm;
  final ValueChanged<double> onPaceChanged;

  const PaceSelector({
    super.key,
    required this.initialPaceSecPerKm,
    required this.onPaceChanged,
  });

  @override
  State<PaceSelector> createState() => _PaceSelectorState();
}

class _PaceSelectorState extends State<PaceSelector> {
  late double _paceSecPerKm;

  @override
  void initState() {
    super.initState();
    _paceSecPerKm = widget.initialPaceSecPerKm;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Target Pace',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSizes.paddingMedium),

          // Current pace display
          Center(
            child: Text(
              '${Formatters.formatPace(_paceSecPerKm)} /km',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.paddingMedium),

          // Slider
          Slider(
            value: _paceSecPerKm,
            min: 180.0, // 3:00/km
            max: 720.0, // 12:00/km
            divisions: 54, // 10 second increments
            activeColor: AppColors.primary,
            inactiveColor: AppColors.surfaceLight,
            onChanged: (value) {
              setState(() => _paceSecPerKm = value);
              widget.onPaceChanged(value);
            },
          ),

          // Min/max labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '3:00/km',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              Text(
                '12:00/km',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
