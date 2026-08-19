import 'dart:async';

import 'package:flutter/material.dart';

import '../session/pi_desktop_connection.dart';
import 'pi_tokens.dart';
import 'ui_preferences.dart';

/// UI-only settings. Pi runtime and package configuration stay Pi-owned.
class SettingsDialog extends StatelessWidget {
  const SettingsDialog({
    required this.preferences,
    required this.connection,
    super.key,
  });

  final UiPreferences preferences;
  final PiDesktopConnection connection;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: preferences,
      builder: (context, child) {
        final tokens = PiTokens.of(context);
        return AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(24, 22, 14, 8),
          contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  'Settings',
                  style: tokens.display.copyWith(fontSize: 24),
                ),
              ),
              IconButton(
                tooltip: 'Close settings',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Section(
                    title: 'Appearance',
                    child: Column(
                      children: [
                        _ChoiceRow<ThemeMode>(
                          label: 'Display',
                          value: preferences.themeMode,
                          choices: const {
                            ThemeMode.dark: 'Dark',
                            ThemeMode.light: 'Light',
                          },
                          onSelected: preferences.setThemeMode,
                        ),
                        _FontFamilyPicker(preferences: preferences),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12, top: 4),
                          child: Text(
                            'The five boxing wizards jump quickly. 中文阅读效果。',
                            style: tokens.reading.copyWith(fontSize: 16),
                          ),
                        ),
                        _ChoiceRow<PiDensity>(
                          label: 'Spacing',
                          value: preferences.density,
                          choices: const {
                            PiDensity.compact: 'Compact',
                            PiDensity.standard: 'Comfortable',
                          },
                          onSelected: (density) async {
                            if (density != preferences.density) {
                              await preferences.cycleDensity();
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text('Text size', style: tokens.control),
                            ),
                            Text(
                              '${(preferences.textScale * 100).round()}%',
                              style: tokens.evidence.copyWith(
                                color: tokens.textSoft,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: preferences.textScale,
                          min: 0.9,
                          max: 1.4,
                          divisions: 10,
                          label: '${(preferences.textScale * 100).round()}%',
                          onChanged: (value) => preferences.setTextScale(value),
                          onChangeEnd: (value) =>
                              preferences.setTextScale(value, persist: true),
                        ),
                        Text(
                          'Applies to conversation, controls, and the composer. Code blocks stay monospaced unless Mono is selected.',
                          style: tokens.control.copyWith(
                            color: tokens.textFaint,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Workspace',
                    child: Column(
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Show sessions', style: tokens.control),
                          subtitle: Text(
                            'Keep the session archive visible.',
                            style: tokens.control.copyWith(
                              color: tokens.textFaint,
                              fontSize: 12,
                            ),
                          ),
                          value: preferences.archiveVisible,
                          onChanged: (_) =>
                              unawaited(preferences.toggleArchive()),
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Show Pi details', style: tokens.control),
                          subtitle: Text(
                            'Show Pi-owned tools, commands and resources.',
                            style: tokens.control.copyWith(
                              color: tokens.textFaint,
                              fontSize: 12,
                            ),
                          ),
                          value: preferences.inspectorVisible,
                          onChanged: (_) =>
                              unawaited(preferences.toggleInspector()),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () =>
                                unawaited(preferences.resetLayout()),
                            icon: const Icon(
                              Icons.restart_alt_outlined,
                              size: 16,
                            ),
                            label: const Text('Reset workspace layout'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Pi apps & extensions',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Apps such as Codex are surfaced only when they are installed and invoked by the connected Pi process. Pi Desktop renders the official extension UI requests and returns the selected response to that same process.',
                          style: tokens.control.copyWith(
                            color: tokens.textSoft,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              connection.isConnected
                                  ? Icons.check_circle_outline
                                  : Icons.circle_outlined,
                              size: 16,
                              color: connection.isConnected
                                  ? tokens.signalOk
                                  : tokens.textFaint,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                connection.isConnected ? 'Connected to Pi RPC' : 'Connect Pi to use installed apps and extensions.',
                                style: tokens.control.copyWith(
                                  color: tokens.textSoft,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }
}

class _FontFamilyPicker extends StatelessWidget {
  const _FontFamilyPicker({required this.preferences});

  final UiPreferences preferences;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Interface font', style: tokens.control),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final font in PiReadingFont.values)
                ChoiceChip(
                  label: Text(font.label),
                  selected: preferences.readingFont == font,
                  onSelected: (_) =>
                      unawaited(preferences.setReadingFont(font)),
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  labelStyle: tokens.control.copyWith(
                    fontSize: 12.5,
                    color: preferences.readingFont == font
                        ? tokens.text
                        : tokens.textSoft,
                  ),
                  selectedColor: tokens.panelSoft,
                  side: BorderSide(
                    color: preferences.readingFont == font
                        ? tokens.accent.withValues(alpha: 0.45)
                        : tokens.line,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.panelSoft.withValues(alpha: 0.52),
        border: Border.all(color: tokens.line),
        borderRadius: BorderRadius.circular(tokens.radius),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: tokens.control.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.value,
    required this.choices,
    required this.onSelected,
  });
  final String label;
  final T value;
  final Map<T, String> choices;
  final Future<void> Function(T value) onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 108, child: Text(label, style: tokens.control)),
          Expanded(
            child: SegmentedButton<T>(
              showSelectedIcon: false,
              segments: [
                for (final entry in choices.entries)
                  ButtonSegment(value: entry.key, label: Text(entry.value)),
              ],
              selected: {value},
              onSelectionChanged: (selected) =>
                  unawaited(onSelected(selected.first)),
            ),
          ),
        ],
      ),
    );
  }
}
