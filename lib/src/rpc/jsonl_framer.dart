import 'dart:convert';

/// Decodes UTF-8 bytes into LF-delimited records.
///
/// The decoder deliberately treats only `\n` as a record boundary. A trailing
/// `\r` is removed to accept CRLF input, while Unicode line separators remain
/// part of the record as required by Pi's RPC protocol.
class JsonlFramer {
  JsonlFramer({required this.onLine});

  final void Function(String line) onLine;
  final StringBuffer _buffer = StringBuffer();
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
    _buffer.write(text);
    var decoded = _buffer.toString();
    var newlineIndex = decoded.indexOf('\n');

    while (newlineIndex >= 0) {
      var line = decoded.substring(0, newlineIndex);
      if (line.endsWith('\r')) {
        line = line.substring(0, line.length - 1);
      }
      onLine(line);
      decoded = decoded.substring(newlineIndex + 1);
      newlineIndex = decoded.indexOf('\n');
    }

    _buffer
      ..clear()
      ..write(decoded);
  }

  void _emitRemainingRecord() {
    if (_buffer.isEmpty) {
      return;
    }
    var line = _buffer.toString();
    if (line.endsWith('\r')) {
      line = line.substring(0, line.length - 1);
    }
    onLine(line);
    _buffer.clear();
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
