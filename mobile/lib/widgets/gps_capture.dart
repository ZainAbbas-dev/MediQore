// M2 FE-3: records the home's GPS position, with its status: not recorded yet,
// finding, recorded, or why it failed.
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../location/location_service.dart';
import 'large_button.dart';

class GpsCapture extends StatefulWidget {
  const GpsCapture({super.key, required this.location, required this.onCaptured});

  final LocationService location;
  final ValueChanged<LocationFix> onCaptured;

  @override
  State<GpsCapture> createState() => _GpsCaptureState();
}

class _GpsCaptureState extends State<GpsCapture> {
  bool _capturing = false;
  LocationFix? _fix;
  LocationProblem? _problem;

  Future<void> _capture() async {
    setState(() {
      _capturing = true;
      _problem = null;
    });
    final result = await widget.location.current();
    if (!mounted) return;
    setState(() {
      _capturing = false;
      _fix = result.fix ?? _fix;
      _problem = result.problem;
    });
    if (result.fix != null) widget.onCaptured(result.fix!);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fix = _fix;
    final problem = _problem;

    final String status;
    if (_capturing) {
      status = l10n.gpsCapturing;
    } else if (problem != null) {
      status = switch (problem) {
        LocationProblem.serviceOff => l10n.gpsServiceOff,
        LocationProblem.denied => l10n.gpsDenied,
        LocationProblem.deniedForever => l10n.gpsDeniedForever,
        LocationProblem.unavailable => l10n.gpsUnavailable,
      };
    } else if (fix != null) {
      status = l10n.gpsCaptured(fix.accuracyMetres.round());
    } else {
      status = l10n.gpsNotRecorded;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.gpsLabel, style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(status, style: problem != null ? TextStyle(color: theme.colorScheme.error) : null),
        if (fix != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              '${fix.latitude.toStringAsFixed(6)}, ${fix.longitude.toStringAsFixed(6)}',
              textDirection: TextDirection.ltr,
              style: theme.textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 8),
        if (_capturing)
          const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
        else
          LargeButton(
            label: problem != null ? l10n.gpsRetryButton : l10n.gpsCaptureButton,
            icon: Icons.my_location,
            secondary: true,
            onPressed: _capture,
          ),
        if (problem == LocationProblem.serviceOff || problem == LocationProblem.deniedForever)
          TextButton(onPressed: () => widget.location.openSettings(problem!), child: Text(l10n.gpsOpenSettings)),
      ],
    );
  }
}
