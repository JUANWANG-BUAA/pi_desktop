import 'package:flutter/material.dart';

import 'pi_tokens.dart';
import 'widgets.dart';

/// Lightweight Markdown renderer for Pi assistant text.
///
/// This is display-only. It does not rewrite Prompt content or create a second
/// document model; the source string remains the Pi message.
class MarkdownDocument extends StatelessWidget {
  const MarkdownDocument({required this.text, super.key, this.serif = false});

  final String text;
  final bool serif;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    final blocks = _splitFences(text);
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final block in blocks)
            if (block.code)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: CodeSurface(text: block.text, language: block.language),
              )
            else
              ..._renderTextBlock(tokens, block.text),
        ],
      ),
    );
  }

  List<Widget> _renderTextBlock(PiTokens tokens, String raw) {
    final widgets = <Widget>[];
    final lines = raw.split('\n');
    final paragraph = <String>[];
    final listItems = <String>[];

    void flushParagraph() {
      if (paragraph.isEmpty) {
        return;
      }
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text.rich(
            _inline(tokens, paragraph.join('\n')),
            style: serif ? tokens.reading : tokens.control,
          ),
        ),
      );
      paragraph.clear();
    }

    void flushList() {
      if (listItems.isEmpty) {
        return;
      }
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10, left: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in listItems)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ListLead(item: item),
                      Expanded(
                        child: Text.rich(
                          _inline(tokens, _taskText(item)),
                          style: (serif ? tokens.reading : tokens.control)
                              .copyWith(
                                color: _taskDone(item)
                                    ? tokens.textFaint
                                    : null,
                                decoration: _taskDone(item)
                                    ? TextDecoration.lineThrough
                                    : null,
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
      listItems.clear();
    }

    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      if (_isTableRow(line)) {
        flushList();
        flushParagraph();
        final rows = <String>[];
        while (i < lines.length && _isTableRow(lines[i])) {
          if (!_isTableSeparator(lines[i])) {
            rows.add(lines[i]);
          }
          i++;
        }
        if (rows.isNotEmpty) {
          widgets.add(_MarkdownTable(rows: rows, tokens: tokens));
        }
        continue;
      }
      final heading = RegExp(r'^(#{1,4})\s+(.*)$').firstMatch(line);
      final list = RegExp(r'^[-*]\s+(.*)$').firstMatch(line);
      final numbered = RegExp(r'^\d+\.\s+(.*)$').firstMatch(line);
      final quote = line.startsWith('> ');
      if (heading != null) {
        flushList();
        flushParagraph();
        final level = heading.group(1)!.length;
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: level == 1 ? 8 : 4, bottom: 8),
            child: Text(
              heading.group(2)!,
              style: tokens.control.copyWith(
                fontSize: level == 1
                    ? 18
                    : level == 2
                    ? 16
                    : 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
        );
      } else if (list != null || numbered != null) {
        flushParagraph();
        listItems.add((list ?? numbered)!.group(1)!);
      } else if (quote) {
        flushList();
        flushParagraph();
        widgets.add(
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: tokens.accent, width: 2)),
            ),
            child: Text.rich(
              _inline(tokens, line.substring(2)),
              style: tokens.reading.copyWith(
                color: tokens.textSoft,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        );
      } else if (line.trim().isEmpty) {
        flushList();
        flushParagraph();
      } else {
        flushList();
        paragraph.add(line);
      }
      i++;
    }
    flushList();
    flushParagraph();
    return widgets;
  }

  TextSpan _inline(PiTokens tokens, String input) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'(\*\*[^*]+\*\*|`[^`]+`|\*[^*]+\*)');
    var cursor = 0;
    for (final match in pattern.allMatches(input)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: input.substring(cursor, match.start)));
      }
      final token = match.group(0)!;
      if (token.startsWith('**')) {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        );
      } else if (token.startsWith('`')) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: tokens.evidence.copyWith(
              fontSize: tokens.evidenceSize,
              color: tokens.accent,
              backgroundColor: tokens.panelSoft,
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      }
      cursor = match.end;
    }
    if (cursor < input.length) {
      spans.add(TextSpan(text: input.substring(cursor)));
    }
    return TextSpan(children: spans);
  }
}

bool _taskDone(String item) => RegExp(r'^\[[xX]\]\s+').hasMatch(item);

bool _taskOpen(String item) => RegExp(r'^\[ \]\s+').hasMatch(item);

String _taskText(String item) =>
    item.replaceFirst(RegExp(r'^\[[ xX]\]\s+'), '');

class _ListLead extends StatelessWidget {
  const _ListLead({required this.item});
  final String item;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    if (_taskDone(item) || _taskOpen(item)) {
      return Padding(
        padding: const EdgeInsets.only(right: 7, top: 2),
        child: Icon(
          _taskDone(item)
              ? Icons.check_box_rounded
              : Icons.check_box_outline_blank_rounded,
          size: 15,
          color: _taskDone(item) ? tokens.textFaint : tokens.accent,
        ),
      );
    }
    return Text(
      '·  ',
      style: (PiTokens.of(context).control).copyWith(color: tokens.accent),
    );
  }
}

class _FenceBlock {
  const _FenceBlock({required this.text, required this.code, this.language});

  final String text;
  final bool code;
  final String? language;
}

List<_FenceBlock> _splitFences(String source) {
  final blocks = <_FenceBlock>[];
  final pattern = RegExp(r'```([^\n]*)\n([\s\S]*?)```');
  var cursor = 0;
  for (final match in pattern.allMatches(source)) {
    if (match.start > cursor) {
      blocks.add(
        _FenceBlock(text: source.substring(cursor, match.start), code: false),
      );
    }
    blocks.add(
      _FenceBlock(
        text: match.group(2)!.trimRight(),
        code: true,
        language: _fenceLanguage(match.group(1)!),
      ),
    );
    cursor = match.end;
  }
  if (cursor < source.length) {
    blocks.add(_FenceBlock(text: source.substring(cursor), code: false));
  }
  if (blocks.isEmpty) {
    blocks.add(_FenceBlock(text: source, code: false));
  }
  return blocks;
}

String? _fenceLanguage(String value) {
  final words = value.trim().split(RegExp(r'\s+'));
  return words.isEmpty || words.first.isEmpty ? null : words.first;
}

bool _isTableRow(String line) {
  final trimmed = line.trim();
  return trimmed.startsWith('|') && trimmed.contains('|', 1);
}

bool _isTableSeparator(String line) {
  final trimmed = line.trim();
  return RegExp(r'^\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?$')
      .hasMatch(trimmed);
}

List<String> _tableCells(String row) {
  var line = row.trim();
  if (line.startsWith('|')) {
    line = line.substring(1);
  }
  if (line.endsWith('|')) {
    line = line.substring(0, line.length - 1);
  }
  return line.split('|').map((cell) => cell.trim()).toList(growable: false);
}

class _MarkdownTable extends StatelessWidget {
  const _MarkdownTable({required this.rows, required this.tokens});

  final List<String> rows;
  final PiTokens tokens;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }
    final parsed = rows.map(_tableCells).toList(growable: false);
    final columns = parsed.fold<int>(
      0,
      (max, row) => row.length > max ? row.length : max,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.chipRadius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: tokens.line),
            borderRadius: BorderRadius.circular(tokens.chipRadius),
          ),
          child: Table(
            border: TableBorder.symmetric(
              inside: BorderSide(color: tokens.line),
            ),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              for (var r = 0; r < parsed.length; r++)
                TableRow(
                  decoration: BoxDecoration(
                    color: r == 0 ? tokens.panelSoft : tokens.panel,
                  ),
                  children: [
                    for (var c = 0; c < columns; c++)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Text(
                          c < parsed[r].length ? parsed[r][c] : '',
                          style: tokens.control.copyWith(
                            fontSize: 13,
                            fontWeight: r == 0
                                ? FontWeight.w600
                                : FontWeight.w400,
                            fontFamily: 'SF Mono',
                            fontFamilyFallback: PiTokens.monoFallbacks,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
