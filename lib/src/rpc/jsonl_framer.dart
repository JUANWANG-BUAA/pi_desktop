import 'dart:convert';

/// Decodes UTF-8 bytes into LF-delimited records.
///
/// The decoder deliberately treats only `\n` as a record boundary. A trailing
/// `\r` is removed to accept CRLF input, while Unicode line separators remain
/// part of the record as required by Pi's RPC protocol.
///
/// Splitting is incremental: each decoded chunk is only combined with the
/// still-unterminated remainder, never re-scanned as a whole buffer. Records
/// larger than [maxLineLength] raise a [FormatException] so a runaway tool
/// output cannot grow memory without bound.
class JsonlFramer {
  JsonlFramer({
    required this.onLine,
    this.maxLineLength = defaultMaxLineLength,
  });

  /// 64 million characters bounds one Pi record well above any realistic
  /// tool output while keeping memory growth finite.
  static const defaultMaxLineLength = 64 * 1024 * 1024;

  final void Function(String line) onLine;
  final int maxLineLength;

  String _remainder = '';
  late final ByteConversionSink _byteSink = const Utf8Decoder(
    allowMalformed: false,
  ).startChunkedConversion(_DecodedTextSink(_appendText));

  bool _isClosed = false;

  /// Adds a byte chunk. UTF-8 sequences split across chunks are preserved.
  void add(List<int> bytes) {
    if (_isClosed) {
      throw StateError('Cannot add bytes after the JSONL framer is closed.');
    }
    _byteSink.add(bytes);
  }

  /// Closes the UTF-8 decoder and emits a final unterminated record, if any.
  void close() {
    if (_isClosed) {
      return;
    }
    _isClosed = true;
    _byteSink.close();
    _emitRemainingRecord();
  }

  void _appendText(String text) {
    final combined = _remainder.isEmpty ? text : '$_remainder$text';
    final segments = combined.split('\n');
    _remainder = segments.removeLast();
    _checkLength(_remainder.length);
    for (var line in segments) {
      if (line.endsWith('\r')) {
        line = line.substring(0, line.length - 1);
      }
      onLine(line);
    }
  }

  void _emitRemainingRecord() {
    if (_remainder.isEmpty) {
      return;
    }
    var line = _remainder;
    _remainder = '';
    if (line.endsWith('\r')) {
      line = line.substring(0, line.length - 1);
    }
    onLine(line);
  }

  void _checkLength(int length) {
    if (length > maxLineLength) {
      throw FormatException(
        'Pi RPC record exceeds the $maxLineLength character bound.',
      );
    }
  }
}

class _DecodedTextSink implements Sink<String> {
  _DecodedTextSink(this.onText);

  final void Function(String text) onText;

  @override
  void add(String data) => onText(data);

  @override
  void close() {}
}
