import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:banshee_run_app/src/utils/constants.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _useMetric = true;
  bool _audioEnabled = true;
  bool _keepScreenOn = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _SettingsSection(
            title: 'Units',
            children: [
              _SettingsTile(
                title: 'Distance & Pace Units',
                subtitle: _useMetric ? 'Kilometers' : 'Miles',
                trailing: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('km')),
                    ButtonSegment(value: false, label: Text('mi')),
                  ],
                  selected: {_useMetric},
                  onSelectionChanged: (selection) {
                    setState(() => _useMetric = selection.first);
                  },
                ),
              ),
            ],
          ),
          _SettingsSection(
            title: 'Audio',
            children: [
              SwitchListTile(
                title: const Text('Audio Feedback'),
                subtitle: const Text('Play tones when ahead/behind banshee'),
                value: _audioEnabled,
                onChanged: (value) {
                  setState(() => _audioEnabled = value);
                },
                activeTrackColor: AppColors.primary,
              ),
            ],
          ),
          _SettingsSection(
            title: 'Display',
            children: [
              SwitchListTile(
                title: const Text('Keep Screen On'),
                subtitle: const Text(
                  'Prevent screen from sleeping during runs',
                ),
                value: _keepScreenOn,
                onChanged: (value) {
                  setState(() => _keepScreenOn = value);
                },
                activeTrackColor: AppColors.primary,
              ),
            ],
          ),
          _SettingsSection(
            title: 'Maps',
            children: [
              ListTile(
                title: const Text('Offline Maps'),
                subtitle: const Text('Download maps for offline use'),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                ),
                onTap: () {
                  // TODO: Open offline maps screen
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Coming soon!')));
                },
              ),
              ListTile(
                title: const Text('Clear Map Cache'),
                subtitle: const Text('Free up storage space'),
                trailing: const Icon(
                  Icons.delete_outline,
                  color: AppColors.textSecondary,
                ),
                onTap: () {
                  _showClearCacheDialog();
                },
              ),
            ],
          ),
          _SettingsSection(
            title: 'Data',
            children: [
              ListTile(
                title: const Text('Export Runs'),
                subtitle: const Text('Export your run data'),
                trailing: const Icon(
                  Icons.download,
                  color: AppColors.textSecondary,
                ),
                onTap: () {
                  // TODO: Export functionality
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Coming soon!')));
                },
              ),
              ListTile(
                title: const Text('Delete All Runs'),
                subtitle: const Text('Permanently delete all run data'),
                trailing: const Icon(
                  Icons.delete_forever,
                  color: AppColors.error,
                ),
                onTap: () {
                  _showDeleteAllDialog();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Clear Cache?'),
        content: const Text(
          'This will remove all downloaded map tiles. You will need to re-download them for offline use.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Clear cache
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Cache cleared')));
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete All Runs?'),
        content: const Text(
          'This will permanently delete all your run data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Delete all runs
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('All runs deleted')));
            },
            child: const Text(
              'Delete All',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const _SettingsTile({required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing,
    );
  }
}
