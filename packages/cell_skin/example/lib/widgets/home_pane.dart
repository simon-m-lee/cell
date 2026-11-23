// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The Home pane: smart-home cards bound to the domain cells through
/// `cell_flutter`'s widget layer — `CellBuilder` for the state cells,
/// `CellValueBuilder` for the pulse cells, and `CellListener` for the
/// door's one-shot rejection beat.
library;

import 'dart:async';

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';

import '../mock/mock_home.dart';
import '../state/demo_state.dart';
import '../theme/app_theme.dart';

class HomePane extends StatelessWidget {
  final MockHome home;
  final DemoState state;

  const HomePane({required this.home, required this.state, super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHeader(label: 'Living Room'),
          CellBuilder<double>(
            cell: home.light.cell,
            builder: (context, value) => _CellCard(
              icon: Icons.lightbulb_outline,
              value: '${((value ?? 0.8) * 100).round()}%',
              valueKey: value,
              label: 'Light',
              color: AppTheme.amber,
            ),
          ),
          CellBuilder<String>(
            cell: home.lightColor.cell,
            builder: (context, value) => _CellCard(
              icon: Icons.palette_outlined,
              value: value ?? '#FFFFFF',
              valueKey: value,
              label: 'Color',
              color: AppTheme.amber,
            ),
          ),
          const _SectionHeader(label: 'Climate'),
          CellBuilder<double>(
            cell: home.thermostat.cell,
            builder: (context, value) => _CellCard(
              icon: Icons.thermostat,
              value: '${(value ?? 22.4).toStringAsFixed(1)}°C',
              valueKey: value,
              label: 'Thermostat',
              color: AppTheme.thermostat,
            ),
          ),
          const _SectionHeader(label: 'Security'),
          _DoorCard(home: home, state: state),
          const _SectionHeader(label: 'Energy'),
          CellValueBuilder<double>(
            cell: home.energyPrice,
            initial: 0.14,
            builder: (context, value) => _CellCard(
              icon: Icons.bolt,
              value: '\$${(value ?? 0.14).toStringAsFixed(2)}/kWh',
              valueKey: value,
              label: 'Current Rate',
              color: AppTheme.energy,
            ),
          ),
          CellValueBuilder<double>(
            cell: home.estimatedBill,
            initial: 4.20,
            builder: (context, value) => _CellCard(
              icon: Icons.attach_money,
              value: '\$${(value ?? 4.20).toStringAsFixed(2)}',
              valueKey: value,
              label: 'Monthly Estimate',
              color: AppTheme.accepted,
              emphasis: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

/// A card that flashes its accent when the cell value changes. The
/// builders above hand it the current value plus a [valueKey]; an
/// [AnimatedSwitcher] rolls the number on each change.
class _CellCard extends StatefulWidget {
  final IconData icon;
  final String value;
  final Object? valueKey;
  final String label;
  final Color color;
  final bool emphasis;

  const _CellCard({
    required this.icon,
    required this.value,
    required this.valueKey,
    required this.label,
    required this.color,
    this.emphasis = false,
  });

  @override
  State<_CellCard> createState() => _CellCardState();
}

class _CellCardState extends State<_CellCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flash;
  late final Animation<double> _flashValue;
  Object? _previousKey;

  @override
  void initState() {
    super.initState();
    _previousKey = widget.valueKey;
    _flash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flashValue = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _flash, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_CellCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.valueKey != _previousKey) {
      _previousKey = widget.valueKey;
      _flash.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _flashValue,
      builder: (context, child) {
        final opacity = (1 - _flashValue.value) * 0.20;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Color.lerp(
              theme.colorScheme.surfaceContainerHigh,
              widget.color.withValues(alpha: opacity),
              _flashValue.value,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2A2E36)),
          ),
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(widget.icon, size: 32, color: widget.color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.4),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Text(
                      widget.value,
                      key: ValueKey(widget.valueKey),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight:
                            widget.emphasis ? FontWeight.w700 : FontWeight.w600,
                        color: widget.color,
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
}

/// The door card: [CellBuilder] renders the lock state; [CellListener]
/// reacts to each real denial with the shake + red flash.
class _DoorCard extends StatefulWidget {
  final MockHome home;
  final DemoState state;

  const _DoorCard({required this.home, required this.state});

  @override
  State<_DoorCard> createState() => _DoorCardState();
}

class _DoorCardState extends State<_DoorCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake;
  late final Animation<double> _shakeOffset;
  bool _rejectionFlash = false;
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeOffset = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shake, curve: Curves.easeInOut));
  }

  void _onDenial(BuildContext context, Pulse<int> pulse) {
    if (!mounted) return;
    setState(() => _rejectionFlash = true);
    _shake.forward(from: 0);
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _rejectionFlash = false);
    });
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CellListener<int>(
      cell: widget.state.doorDenials.cell,
      onPulse: _onDenial,
      child: CellBuilder<bool>(
        cell: widget.home.door.cell,
        builder: (context, locked) {
          final isLocked = locked ?? false;
          return AnimatedBuilder(
            animation: _shakeOffset,
            builder: (context, child) => Transform.translate(
              offset: Offset(_shakeOffset.value, 0),
              child: child,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _rejectionFlash
                    ? AppTheme.rejected.withValues(alpha: 0.18)
                    : theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _rejectionFlash
                      ? AppTheme.rejected
                      : const Color(0xFF2A2E36),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sensor_door_outlined,
                      size: 32, color: AppTheme.rejected),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Front Door',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isLocked ? 'LOCKED' : 'UNLOCKED',
                          key: ValueKey(isLocked),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isLocked
                                ? AppTheme.rejected
                                : AppTheme.accepted,
                          ),
                        ),
                        CellBuilder<int>(
                          cell: widget.state.doorDenials.cell,
                          builder: (context, denials) => (denials ?? 0) == 0
                              ? Text(
                                  'TestCell: lock only if no one home',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                )
                              : Text(
                                  '✗ occupant home — lock refused',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppTheme.rejected,
                                    fontWeight: FontWeight.w600,
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
        },
      ),
    );
  }
}
