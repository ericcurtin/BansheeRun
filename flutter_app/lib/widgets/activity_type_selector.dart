import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/activity.dart';
import '../theme/app_theme.dart';
import '../services/haptic_service.dart';

class ActivityTypeSelector extends StatefulWidget {
  final ActivityType selectedType;
  final ValueChanged<ActivityType> onTypeChanged;
  final bool showAll;

  const ActivityTypeSelector({
    super.key,
    required this.selectedType,
    required this.onTypeChanged,
    this.showAll = false,
  });

  @override
  State<ActivityTypeSelector> createState() => _ActivityTypeSelectorState();
}

class _ActivityTypeSelectorState extends State<ActivityTypeSelector>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final types = ActivityType.values;

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.textMuted.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: types.map((type) {
          final isSelected = type == widget.selectedType;
          return Expanded(
            child: _ActivityTypeButton(
              type: type,
              isSelected: isSelected,
              glowController: _glowController,
              onTap: () {
                HapticService.instance.selectionClick();
                widget.onTypeChanged(type);
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ActivityTypeButton extends StatelessWidget {
  final ActivityType type;
  final bool isSelected;
  final AnimationController glowController;
  final VoidCallback onTap;

  const _ActivityTypeButton({
    required this.type,
    required this.isSelected,
    required this.glowController,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: glowController,
        builder: (context, child) {
          final glowValue = isSelected ? glowController.value : 0.0;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        type.color,
                        type.color.withOpacity(0.7),
                      ],
                    )
                  : null,
              color: isSelected ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: type.color.withOpacity(0.4 + glowValue * 0.2),
                        blurRadius: 12 + glowValue * 6,
                        spreadRadius: glowValue * 2,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedScale(
                    scale: isSelected ? 1.2 : 1.0,
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      type.emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(height: 2),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 250),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? AppColors.darkBackground
                          : AppColors.textMuted,
                    ),
                    child: Text(type.displayName),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class FilterChips extends StatelessWidget {
  final List<String> options;
  final String selectedOption;
  final ValueChanged<String> onSelected;

  const FilterChips({
    super.key,
    required this.options,
    required this.selectedOption,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = options[index];
          final isSelected = option == selectedOption;

          return _FilterChip(
            label: option,
            isSelected: isSelected,
            onTap: () {
              HapticService.instance.selectionClick();
              onSelected(option);
            },
            index: index,
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int index;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.index,
  });

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()..scale(_isPressed ? 0.95 : 1.0),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          gradient: widget.isSelected
              ? AppColors.primaryGradient
              : null,
          color: widget.isSelected ? null : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: widget.isSelected
                ? Colors.transparent
                : AppColors.textMuted.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: widget.isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryCyan.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          widget.label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.normal,
            color: widget.isSelected
                ? AppColors.darkBackground
                : AppColors.textSecondary,
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: 50 * widget.index))
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.2, end: 0, duration: 300.ms);
  }
}
