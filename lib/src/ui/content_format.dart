import 'dart:convert';

import '../session/pi_session_projection.dart';

Iterable<Map<String, dynamic>> contentBlocks(PiJsonObject message) sync* {
  final content = message['content'];
  if (content is String) {
    yield <String, dynamic>{'type': 'text', 'text': content};
    return;
  }
  if (content is! List) {
    return;
  }
  for (final block in content.whereType<Map>()) {
    yield Map<String, dynamic>.from(block);
  }
}

String visibleText(PiJsonObject message) {
  final parts = <String>[];
  for (final block in contentBlocks(message)) {
    if (block['type'] == 'text' && block['text'] is String) {
      parts.add(block['text'] as String);
    }
  }
  return parts.join('\n\n');
}

String messageText(PiJsonObject message) {
  final content = message['content'];
  if (content is String) {
    return content;
  }
  if (content is! List) {
    return '';
  }

  final parts = <String>[];
  for (final block in content.whereType<Map>()) {
    final type = block['type'];
    switch (type) {
      case 'text':
        if (block['text'] is String) {
          parts.add(block['text'] as String);
        }
      case 'image':
        parts.add('[image content from Pi]');
      case 'toolCall':
        final name = block['name'];
        final arguments = block['arguments'];
        final argumentText = arguments == null
            ? ''
            : '\n${_prettyJson(arguments)}';
        parts.add(
          'Tool call: ${name is String ? name : 'unknown'}$argumentText',
        );
    }
  }

  final details = message['details'];
  if (details is Map && details['diff'] is String) {
    parts.add('Diff:\n${details['diff']}');
  }
  return parts.join('\n\n');
}

String? thinkingText(PiJsonObject message) {
  final content = message['content'];
  if (content is! List) {
    return null;
  }
  final parts = <String>[];
  for (final block in content.whereType<Map>()) {
    if (block['type'] == 'thinking' && block['thinking'] is String) {
      parts.add(block['thinking'] as String);
    }
  }
  return parts.isEmpty ? null : parts.join('\n');
}

String toolPayloadText(Object? payload) {
  if (payload is! Map) {
    return payload is String ? payload : '';
  }
  final content = payload['content'];
  if (content is List) {
    final text = content
        .whereType<Map>()
        .where((item) => item['type'] == 'text' && item['text'] is String)
        .map((item) => item['text'] as String)
        .join('\n');
    if (text.isNotEmpty) {
      return text;
    }
  }
  final details = payload['details'];
  if (details is Map && details['diff'] is String) {
    return details['diff'] as String;
  }
  return _prettyJson(payload);
}

String truncationLabel(Object? payload) {
  if (payload is! Map) {
    return '';
  }
  final details = payload['details'];
  if (details is! Map) {
    return '';
  }
  final truncation = details['truncation'];
  if (truncation == null) {
    return '';
  }
  return truncation.toString();
}

String? currentModel(PiJsonObject? state) {
  final model = state?['model'];
  if (model is! Map || model['provider'] is! String || model['id'] is! String) {
    return null;
  }
  return '${model['provider']}/${model['id']}';
}

String sessionLabel(PiJsonObject? state) {
  final name = state?['sessionName'] as String?;
  final id = state?['sessionId'] as String?;
  return name ?? id ?? 'not loaded';
}

String cwdLabel(String processCwd, PiJsonObject? state) {
  final sessionFile = state?['sessionFile'] as String?;
  if (processCwd.isNotEmpty) {
    return processCwd;
  }
  if (sessionFile is String && sessionFile.isNotEmpty) {
    return sessionFile;
  }
  return 'unknown';
}

String projectLabel(String processCwd, PiJsonObject? state) {
  final cwd = cwdLabel(processCwd, state);
  final parts = cwd.split(RegExp(r'[/\\]'));
  for (var i = parts.length - 1; i >= 0; i--) {
    if (parts[i].isNotEmpty) {
      return parts[i];
    }
  }
  return cwd;
}

String modelShortLabel(String? model) {
  if (model == null || model.isEmpty) {
    return 'Model';
  }
  final slash = model.lastIndexOf('/');
  return slash >= 0 ? model.substring(slash + 1) : model;
}

String usageLabel(PiJsonObject stats) {
  final parts = <String>[];
  final contextUsage = stats['contextUsage'];
  if (contextUsage is Map && contextUsage['percent'] is num) {
    parts.add('${contextUsage['percent']}% context');
  }
  final tokens = stats['tokens'];
  if (tokens is Map && tokens['total'] is num) {
    parts.add('${tokens['total']} tokens');
  }
  final cost = stats['cost'];
  if (cost is num) {
    parts.add('\$${cost.toStringAsFixed(4)}');
  }
  return parts.isEmpty ? 'Pi usage available' : parts.join(' · ');
}

String _prettyJson(Object value) {
  try {
    return const JsonEncoder.withIndent('  ').convert(value);
  } on Object {
    return value.toString();
  }
}
