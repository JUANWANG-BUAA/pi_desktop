import 'package:flutter/material.dart';

import '../session/pi_desktop_connection.dart';
import '../session/pi_session_projection.dart';

/// Rebuilds only when [select] changes. Projection stream tokens can notify
/// without forcing Archive, Inspector, or the committed transcript to rebuild.
class BoundConnection extends StatefulWidget {
  const BoundConnection({
    required this.connection,
    required this.select,
    required this.builder,
    super.key,
  });

  final PiDesktopConnection connection;
  final Object? Function(
    PiDesktopConnection connection,
    PiSessionProjection? projection,
  )
  select;
  final Widget Function(
    BuildContext context,
    PiDesktopConnection connection,
    PiSessionProjection? projection,
  )
  builder;

  @override
  State<BoundConnection> createState() => _BoundConnectionState();
}

class _BoundConnectionState extends State<BoundConnection> {
  PiSessionProjection? _projection;
  Object? _selected;

  @override
  void initState() {
    super.initState();
    widget.connection.addListener(_onConnection);
    _bindProjection();
    _selected = widget.select(widget.connection, _projection);
  }

  @override
  void didUpdateWidget(covariant BoundConnection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.connection != widget.connection) {
      oldWidget.connection.removeListener(_onConnection);
      widget.connection.addListener(_onConnection);
      _bindProjection();
      _selected = widget.select(widget.connection, _projection);
    }
  }

  @override
  void dispose() {
    widget.connection.removeListener(_onConnection);
    _projection?.removeListener(_onProjection);
    super.dispose();
  }

  void _bindProjection() {
    _projection?.removeListener(_onProjection);
    _projection = widget.connection.projection;
    _projection?.addListener(_onProjection);
  }

  void _onConnection() {
    if (!identical(_projection, widget.connection.projection)) {
      _bindProjection();
    }
    _emit();
  }

  void _onProjection() => _emit();

  void _emit() {
    final next = widget.select(widget.connection, widget.connection.projection);
    if (next != _selected) {
      _selected = next;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      widget.connection,
      widget.connection.projection,
    );
  }
}

/// Rebuilds on every projection notify. Use only for streaming tails and live tools.
class ProjectionListener extends StatefulWidget {
  const ProjectionListener({
    required this.projection,
    required this.builder,
    super.key,
  });

  final PiSessionProjection projection;
  final Widget Function(BuildContext context, PiSessionProjection projection)
  builder;

  @override
  State<ProjectionListener> createState() => _ProjectionListenerState();
}

class _ProjectionListenerState extends State<ProjectionListener> {
  @override
  void initState() {
    super.initState();
    widget.projection.addListener(_onChange);
  }

  @override
  void didUpdateWidget(covariant ProjectionListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projection != widget.projection) {
      oldWidget.projection.removeListener(_onChange);
      widget.projection.addListener(_onChange);
    }
  }

  @override
  void dispose() {
    widget.projection.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, widget.projection);
  }
}
