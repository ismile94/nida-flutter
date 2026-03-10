import 'dart:io';
import 'dart:ui';

import 'package:battery_optimization_permission/battery_optimization_permission.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../services/alarm_settings_service.dart';
import '../utils/scaling.dart';

/// Full port of the RN AlarmSettingsModal.
///
/// Two-panel layout:
///   Left  — prayer list (tahajjud + 6 prayers + persistent-notification footer)
///   Right — settings for the selected prayer (switches, minutes selector,
///           alarm-type segmented control)
///
/// All settings are persisted in SharedPreferences in real-time via
/// [AlarmSettingsService], mirroring the RN `saveSettings` behaviour.
class AlarmSettingsModal extends StatefulWidget {
  final VoidCallback onClose;

  const AlarmSettingsModal({super.key, required this.onClose});

  @override
  State<AlarmSettingsModal> createState() => _AlarmSettingsModalState();
}

class _AlarmSettingsModalState extends State<AlarmSettingsModal> {
  Map<String, dynamic> _settings = AlarmSettingsService.defaultSettings;
  String _selectedPrayer = 'tahajjud';
  String _customMinutesInput = '';
  String _customTahajjudMinutesInput = '';

  // ── Battery optimization ──────────────────────────────────────────────────
  /// null = not checked yet, true = OK / non-Android, false = needs fixing
  bool? _batteryOptimizationOk;
  bool _batteryFixing = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkBatteryOptimization();
  }

  Future<void> _checkBatteryOptimization() async {
    if (!Platform.isAndroid) {
      if (mounted) setState(() => _batteryOptimizationOk = true);
      return;
    }
    final whitelisted =
        await BatteryOptimizationPermission.isIgnoringBatteryOptimizations();
    if (mounted) setState(() => _batteryOptimizationOk = whitelisted);
  }

  Future<void> _requestBatteryOptimization() async {
    if (!Platform.isAndroid) return;
    setState(() => _batteryFixing = true);
    try {
      final whitelisted =
          await BatteryOptimizationPermission.requestIgnoreBatteryOptimizations();
      if (mounted) {
        setState(() {
          _batteryOptimizationOk = whitelisted;
          _batteryFixing = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _batteryFixing = false);
        _checkBatteryOptimization();
      }
    }
  }

  // ── Persistence ──────────────────────────────────────────────────────────

  Future<void> _loadSettings() async {
    final s = await AlarmSettingsService.load();
    if (mounted) setState(() => _settings = s);
  }

  Future<void> _saveSettings(Map<String, dynamic> newSettings) async {
    await AlarmSettingsService.save(newSettings);
    if (mounted) setState(() => _settings = newSettings);
  }

  void _updatePrayerField(String prayerKey, String field, dynamic value) {
    final updated = Map<String, dynamic>.from(_settings);
    updated[prayerKey] = Map<String, dynamic>.from(
        _settings[prayerKey] as Map)
      ..[field] = value;
    _saveSettings(updated);
  }

  void _updateTopField(String field, dynamic value) {
    final updated = Map<String, dynamic>.from(_settings)..[field] = value;
    _saveSettings(updated);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _isTahajjud() => _selectedPrayer == 'tahajjud';

  Map<String, dynamic> _prayer(String key) =>
      Map<String, dynamic>.from(_settings[key] as Map);

  IconData _prayerIcon(String key) {
    switch (key) {
      case 'fajr':
      case 'isha':
        return Icons.nightlight_round;
      case 'sunrise':
      case 'dhuhr':
        return Icons.wb_sunny_outlined;
      case 'tahajjud':
        return Icons.nightlight;
      default:
        return Icons.wb_cloudy_outlined;
    }
  }

  String _formatPresetMinutes(int minutes, BuildContext context) {
    final h = AppLocalizations.t(context, 'hourShort');
    final m = AppLocalizations.t(context, 'minuteShort');
    if (minutes < 60) return '$minutes$m';
    final hrs = minutes / 60;
    if (hrs == hrs.truncateToDouble()) return '${hrs.toInt()}$h';
    return '${hrs.toStringAsFixed(1)}$h';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = (String k) => AppLocalizations.t(context, k);
    final prayers = ['tahajjud', 'fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'];

    return GestureDetector(
      onTap: widget.onClose, // tap outside → close
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: Center(
          child: GestureDetector(
            onTap: () {}, // absorb taps on the card
            child: Container(
              width: MediaQuery.of(context).size.width * 0.95,
              height: MediaQuery.of(context).size.height * 0.65,
              constraints: BoxConstraints(
                maxWidth: scaleSize(context, 600),
                maxHeight: MediaQuery.of(context).size.height * 0.9,
                minHeight: scaleSize(context, 450),
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(scaleSize(context, 24)),
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Battery optimization warning ───────────────────────
                  if (_batteryOptimizationOk == false)
                    _BatteryWarningBanner(
                      fixing: _batteryFixing,
                      onFix: _requestBatteryOptimization,
                      t: t,
                    ),
                  // ── Two-panel row ──────────────────────────────────────
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Left: prayer list ────────────────────────────
                        _PrayerList(
                          prayers: prayers,
                          selected: _selectedPrayer,
                          settings: _settings,
                          onSelect: (p) => setState(() {
                            _selectedPrayer = p;
                            _customMinutesInput = '';
                            _customTahajjudMinutesInput = '';
                          }),
                          persistentEnabled:
                              _settings['persistentNotificationEnabled'] ==
                                  true,
                          onPersistentToggle: (v) => _updateTopField(
                              'persistentNotificationEnabled', v),
                          prayerIcon: _prayerIcon,
                          t: t,
                        ),

                        // ── Right: settings panel ────────────────────────
                        Expanded(
                          child: _isTahajjud()
                              ? _TahajjudPanel(
                                  prayer: _prayer('tahajjud'),
                                  customInput: _customTahajjudMinutesInput,
                                  formatMinutes: (m) =>
                                      _formatPresetMinutes(m, context),
                                  onEnabledChange: (v) =>
                                      _updatePrayerField('tahajjud', 'enabled', v),
                                  onMinutesChange: (v) => _updatePrayerField(
                                      'tahajjud', 'minutesBeforeFajr', v),
                                  onAlarmTypeChange: (v) => _updatePrayerField(
                                      'tahajjud', 'alarmType', v),
                                  onCustomInputChange: (v) => setState(
                                      () => _customTahajjudMinutesInput = v),
                                  t: t,
                                )
                              : _RegularPrayerPanel(
                                  prayer: _prayer(_selectedPrayer),
                                  customInput: _customMinutesInput,
                                  formatMinutes: (m) =>
                                      _formatPresetMinutes(m, context),
                                  onEnabledChange: (v) => _updatePrayerField(
                                      _selectedPrayer, 'enabled', v),
                                  onPreEnabledChange: (v) =>
                                      _updatePrayerField(
                                          _selectedPrayer, 'preEnabled', v),
                                  onPreMinutesChange: (v) =>
                                      _updatePrayerField(
                                          _selectedPrayer, 'preMinutes', v),
                                  onAlarmTypeChange: (v) =>
                                      _updatePrayerField(
                                          _selectedPrayer, 'alarmType', v),
                                  onPreAlarmTypeChange: (v) =>
                                      _updatePrayerField(
                                          _selectedPrayer, 'preAlarmType', v),
                                  onCustomInputChange: (v) =>
                                      setState(() => _customMinutesInput = v),
                                  t: t,
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Battery warning banner ────────────────────────────────────────────────────

class _BatteryWarningBanner extends StatelessWidget {
  final bool fixing;
  final VoidCallback onFix;
  final String Function(String) t;

  const _BatteryWarningBanner({
    required this.fixing,
    required this.onFix,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFF8E1), Color(0xFFFFF3CD)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border(
          bottom: BorderSide(color: Color(0xFFFFE082), width: 1),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: scaleSize(context, 14),
        vertical: scaleSize(context, 10),
      ),
      child: Row(
        children: [
          Container(
            width: scaleSize(context, 30),
            height: scaleSize(context, 30),
            decoration: BoxDecoration(
              color: const Color(0xFFFF8F00).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.battery_alert_rounded,
              size: scaleSize(context, 16),
              color: const Color(0xFFE65100),
            ),
          ),
          SizedBox(width: scaleSize(context, 10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t('batteryOptimizationTitle'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: scaleFont(context, 11.5),
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF7A3A00),
                  ),
                ),
                SizedBox(height: scaleSize(context, 2)),
                Text(
                  t('batteryOptimizationBody'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: scaleFont(context, 10),
                    color: const Color(0xFF8B4E00),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: scaleSize(context, 8)),
          GestureDetector(
            onTap: fixing ? null : onFix,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(
                horizontal: scaleSize(context, 12),
                vertical: scaleSize(context, 7),
              ),
              decoration: BoxDecoration(
                color: fixing
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF6366F1),
                borderRadius: BorderRadius.circular(scaleSize(context, 10)),
                boxShadow: fixing
                    ? []
                    : [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                          blurRadius: scaleSize(context, 8),
                          offset: Offset(0, scaleSize(context, 2)),
                        ),
                      ],
              ),
              child: fixing
                  ? SizedBox(
                      width: scaleSize(context, 14),
                      height: scaleSize(context, 14),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      t('batteryOptimizationFix'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: scaleFont(context, 11),
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Left panel ───────────────────────────────────────────────────────────────

class _PrayerList extends StatelessWidget {
  final List<String> prayers;
  final String selected;
  final Map<String, dynamic> settings;
  final ValueChanged<String> onSelect;
  final bool persistentEnabled;
  final ValueChanged<bool> onPersistentToggle;
  final IconData Function(String) prayerIcon;
  final String Function(String) t;

  const _PrayerList({
    required this.prayers,
    required this.selected,
    required this.settings,
    required this.onSelect,
    required this.persistentEnabled,
    required this.onPersistentToggle,
    required this.prayerIcon,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: scaleSize(context, 112),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(vertical: scaleSize(context, 8)),
              children: prayers.map((p) {
                final isSelected = p == selected;
                final label = p == 'tahajjud' ? t('tahajjudAlarm') : t(p);
                return GestureDetector(
                  onTap: () => onSelect(p),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFEEF2FF)
                          : Colors.transparent,
                      border: Border(
                        left: BorderSide(
                          width: scaleSize(context, 3),
                          color: isSelected
                              ? const Color(0xFF6366F1)
                              : Colors.transparent,
                        ),
                      ),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: scaleSize(context, 10),
                      vertical: scaleSize(context, 10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          prayerIcon(p),
                          size: scaleSize(context, 16),
                          color: isSelected
                              ? const Color(0xFF6366F1)
                              : const Color(0xFF64748B),
                        ),
                        SizedBox(width: scaleSize(context, 6)),
                        Expanded(
                          child: Text(
                            label,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: scaleFont(context, 11),
                              color: isSelected
                                  ? const Color(0xFF6366F1)
                                  : const Color(0xFF64748B),
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Footer: persistent notification switch ──────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
              scaleSize(context, 8),
              scaleSize(context, 10),
              scaleSize(context, 8),
              scaleSize(context, 14),
            ),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('persistentNotificationTwoLines'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: scaleFont(context, 10),
                    color: const Color(0xFF475569),
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: scaleSize(context, 4)),
                Transform.scale(
                  scale: 0.75,
                  alignment: Alignment.centerLeft,
                  child: Switch(
                    value: persistentEnabled,
                    onChanged: onPersistentToggle,
                    activeColor: const Color(0xFF6366F1),
                    activeTrackColor:
                        const Color(0xFF6366F1).withValues(alpha: 0.35),
                    inactiveTrackColor: const Color(0xFFE2E8F0),
                    thumbColor:
                        WidgetStateProperty.all(Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Regular prayer settings panel ────────────────────────────────────────────

class _RegularPrayerPanel extends StatelessWidget {
  final Map<String, dynamic> prayer;
  final String customInput;
  final String Function(int) formatMinutes;
  final ValueChanged<bool> onEnabledChange;
  final ValueChanged<bool> onPreEnabledChange;
  final ValueChanged<int> onPreMinutesChange;
  final ValueChanged<String> onAlarmTypeChange;
  final ValueChanged<String> onPreAlarmTypeChange;
  final ValueChanged<String> onCustomInputChange;
  final String Function(String) t;

  const _RegularPrayerPanel({
    required this.prayer,
    required this.customInput,
    required this.formatMinutes,
    required this.onEnabledChange,
    required this.onPreEnabledChange,
    required this.onPreMinutesChange,
    required this.onAlarmTypeChange,
    required this.onPreAlarmTypeChange,
    required this.onCustomInputChange,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = prayer['enabled'] == true;
    final preEnabled = prayer['preEnabled'] == true;
    final preMinutes = (prayer['preMinutes'] as num? ?? 10).toInt();
    final alarmType = prayer['alarmType'] as String? ?? 'default';
    final preAlarmType = prayer['preAlarmType'] as String? ?? 'default';
    final alarmOptions = [
      _AlarmOption('default', t('defaultAlarm')),
      _AlarmOption('azan', t('azan')),
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.all(scaleSize(context, 16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Two-column switch row ──────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _SwitchCard(
                  title: t('prePrayerAlarm'),
                  value: preEnabled,
                  onChanged: onPreEnabledChange,
                ),
              ),
              SizedBox(width: scaleSize(context, 12)),
              Expanded(
                child: _SwitchCard(
                  title: t('prayerAlarm'),
                  value: enabled,
                  onChanged: onEnabledChange,
                ),
              ),
            ],
          ),

          // ── Before section ─────────────────────────────────────────
          if (preEnabled) ...[
            _Divider(),
            _SectionHeader(title: t('prePrayerAlarm')),
            SizedBox(height: scaleSize(context, 6)),
            _MinutesSelector(
              label: t('minutesBefore'),
              presets: const [30, 60, 90],
              selected: preMinutes,
              customInput: customInput,
              placeholder: t('customMinutesPlaceholder'),
              maxValue: 1440,
              formatLabel: formatMinutes,
              onSelect: (v) {
                onPreMinutesChange(v);
                onCustomInputChange('');
              },
              onCustomChange: (raw) {
                onCustomInputChange(raw);
                if (raw.isNotEmpty) {
                  final v = int.tryParse(raw) ?? 0;
                  if (v > 0 && v <= 1440) onPreMinutesChange(v);
                } else {
                  onPreMinutesChange(30);
                }
              },
            ),
            SizedBox(height: scaleSize(context, 10)),
            _AlarmTypeSegment(
              label: t('alarmType'),
              value: preAlarmType,
              options: alarmOptions,
              onChanged: onPreAlarmTypeChange,
            ),
          ],

          // ── Prayer alarm type ──────────────────────────────────────
          if (enabled) ...[
            _Divider(),
            _SectionHeader(title: t('prayerAlarm')),
            SizedBox(height: scaleSize(context, 10)),
            _AlarmTypeSegment(
              label: t('alarmType'),
              value: alarmType,
              options: alarmOptions,
              onChanged: onAlarmTypeChange,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Tahajjud settings panel ───────────────────────────────────────────────────

class _TahajjudPanel extends StatelessWidget {
  final Map<String, dynamic> prayer;
  final String customInput;
  final String Function(int) formatMinutes;
  final ValueChanged<bool> onEnabledChange;
  final ValueChanged<int> onMinutesChange;
  final ValueChanged<String> onAlarmTypeChange;
  final ValueChanged<String> onCustomInputChange;
  final String Function(String) t;

  const _TahajjudPanel({
    required this.prayer,
    required this.customInput,
    required this.formatMinutes,
    required this.onEnabledChange,
    required this.onMinutesChange,
    required this.onAlarmTypeChange,
    required this.onCustomInputChange,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = prayer['enabled'] == true;
    final minutes =
        (prayer['minutesBeforeFajr'] as num? ?? 60).toInt();
    final alarmType = prayer['alarmType'] as String? ?? 'default';

    return SingleChildScrollView(
      padding: EdgeInsets.all(scaleSize(context, 16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Enable row ─────────────────────────────────────────────
          Container(
            padding: EdgeInsets.all(scaleSize(context, 12)),
            margin: EdgeInsets.only(bottom: scaleSize(context, 14)),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius:
                  BorderRadius.circular(scaleSize(context, 12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t('tahajjudAlarm'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: scaleFont(context, 13),
                    color: const Color(0xFF475569),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Switch(
                  value: enabled,
                  onChanged: onEnabledChange,
                  activeColor: const Color(0xFF6366F1),
                  activeTrackColor:
                      const Color(0xFF6366F1).withValues(alpha: 0.35),
                  inactiveTrackColor: const Color(0xFFE2E8F0),
                  thumbColor: WidgetStateProperty.all(Colors.white),
                ),
              ],
            ),
          ),

          // ── Minutes before Fajr ────────────────────────────────────
          if (enabled) ...[
            _MinutesSelector(
              label: t('minutesBeforeFajr'),
              presets: const [30, 60, 90],
              selected: minutes,
              customInput: customInput,
              placeholder: t('custom'),
              maxValue: 600,
              formatLabel: formatMinutes,
              onSelect: (v) {
                onMinutesChange(v);
                onCustomInputChange('');
              },
              onCustomChange: (raw) {
                onCustomInputChange(raw);
                if (raw.isNotEmpty) {
                  final v = int.tryParse(raw) ?? 0;
                  if (v > 0 && v <= 600) onMinutesChange(v);
                } else {
                  onMinutesChange(60);
                }
              },
            ),
            _Divider(),
            _AlarmTypeSegment(
              label: t('alarmType'),
              value: alarmType,
              options: [
                _AlarmOption('default', t('defaultAlarm')),
                _AlarmOption('azan', t('azan')),
              ],
              onChanged: onAlarmTypeChange,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Reusable sub-widgets ─────────────────────────────────────────────────────

class _SwitchCard extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchCard(
      {required this.title, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(scaleSize(context, 12)),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(scaleSize(context, 12)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: scaleFont(context, 12),
              color: const Color(0xFF475569),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: scaleSize(context, 8)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF6366F1),
            activeTrackColor:
                const Color(0xFF6366F1).withValues(alpha: 0.35),
            inactiveTrackColor: const Color(0xFFE2E8F0),
            thumbColor: WidgetStateProperty.all(Colors.white),
          ),
        ],
      ),
    );
  }
}

class _MinutesSelector extends StatelessWidget {
  final String label;
  final List<int> presets;
  final int selected;
  final String customInput;
  final String placeholder;
  final int maxValue;
  final String Function(int)? formatLabel;
  final ValueChanged<int> onSelect;
  final ValueChanged<String> onCustomChange;

  const _MinutesSelector({
    required this.label,
    required this.presets,
    required this.selected,
    required this.customInput,
    required this.placeholder,
    required this.maxValue,
    required this.onSelect,
    required this.onCustomChange,
    this.formatLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isCustomActive = !presets.contains(selected);
    final buttonH = scaleSize(context, 32);

    return Padding(
      padding: EdgeInsets.only(top: scaleSize(context, 8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: scaleFont(context, 12),
              color: const Color(0xFF64748B),
            ),
          ),
          SizedBox(height: scaleSize(context, 8)),
          // Row with Expanded children guarantees single-row layout
          Row(
            children: [
              ...presets.map((m) {
                final active = selected == m && !isCustomActive;
                final lbl =
                    formatLabel != null ? formatLabel!(m) : '$m';
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: scaleSize(context, 4)),
                    child: _MinuteButton(
                      label: lbl,
                      active: active,
                      height: buttonH,
                      onTap: () => onSelect(m),
                    ),
                  ),
                );
              }),
              // Custom input — always last, same Expanded share
              Expanded(
                child: SizedBox(
                  height: buttonH,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isCustomActive
                          ? const Color(0xFF6366F1)
                          : Colors.white,
                      borderRadius:
                          BorderRadius.circular(scaleSize(context, 8)),
                      border: Border.all(
                        color: isCustomActive
                            ? const Color(0xFF6366F1)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    alignment: Alignment.center,
                    padding: EdgeInsets.symmetric(
                        horizontal: scaleSize(context, 4)),
                    child: TextField(
                      controller: TextEditingController.fromValue(
                        TextEditingValue(
                          text: customInput,
                          selection: TextSelection.collapsed(
                              offset: customInput.length),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: scaleFont(context, 12),
                        color: isCustomActive
                            ? Colors.white
                            : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        counterText: '',
                        hintText: placeholder,
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: scaleFont(context, 11),
                          color: isCustomActive
                              ? Colors.white70
                              : const Color(0xFF94A3B8),
                      ),
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    onChanged: onCustomChange,
                    onTap: () {},
                  ),
                ),
              ),
            ),  // Expanded (custom)
            ],
          ),
        ],
      ),
    );
  }
}

class _MinuteButton extends StatelessWidget {
  final String label;
  final bool active;
  final double height;
  final VoidCallback onTap;
  const _MinuteButton({
    required this.label,
    required this.active,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        padding:
            EdgeInsets.symmetric(horizontal: scaleSize(context, 4)),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF6366F1) : Colors.white,
          borderRadius: BorderRadius.circular(scaleSize(context, 8)),
          border: Border.all(
            color: active
                ? const Color(0xFF6366F1)
                : const Color(0xFFE2E8F0),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: scaleFont(context, 12),
            color: active
                ? Colors.white
                : const Color(0xFF64748B),
            fontWeight:
                active ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _AlarmOption {
  final String value;
  final String label;
  const _AlarmOption(this.value, this.label);
}

class _AlarmTypeSegment extends StatelessWidget {
  final String label;
  final String value;
  final List<_AlarmOption> options;
  final ValueChanged<String> onChanged;
  const _AlarmTypeSegment({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: scaleSize(context, 8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: scaleFont(context, 12),
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: scaleSize(context, 8)),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius:
                  BorderRadius.circular(scaleSize(context, 12)),
            ),
            padding: EdgeInsets.all(scaleSize(context, 3)),
            child: Row(
              children: options.map((opt) {
                final active = value == opt.value;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(opt.value),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        vertical: scaleSize(context, 7),
                        horizontal: scaleSize(context, 4),
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFF6366F1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(
                            scaleSize(context, 10)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        opt.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: scaleFont(context, 11),
                          color: active
                              ? Colors.white
                              : const Color(0xFF6366F1),
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: scaleSize(context, 10)),
      child: const Divider(
          height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: scaleFont(context, 11),
        fontWeight: FontWeight.w700,
        color: const Color(0xFF6366F1),
        letterSpacing: 0.3,
      ),
    );
  }
}
