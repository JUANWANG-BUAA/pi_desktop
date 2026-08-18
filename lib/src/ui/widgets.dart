import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pi_tokens.dart';

class ResizeHandle extends StatelessWidget {
  const ResizeHandle({required this.onDrag, super.key, this.onDragEnd});

  final ValueChanged<double> onDrag;
  final VoidCallback? onDragEnd;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        onHorizontalDragEnd: (_) => onDragEnd?.call(),
        child: SizedBox(
          width: 8,
          child: Center(child: Container(width: 1, color: tokens.line)),
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: PiTokens.of(context).micro),
    );
  }
}

class MetaRow extends StatelessWidget {
  const MetaRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 78, child: Text(label, style: tokens.micro)),
          Expanded(
            child: SelectableText(
              value,
              style: tokens.evidence.copyWith(
                fontSize: tokens.evidenceSize,
                color: tokens.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class QuietButton extends StatelessWidget {
  const QuietButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.tooltip,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? tooltip;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: tokens.textSoft),
          const SizedBox(width: 8),
        ],
        Text(label),
      ],
    );
    final button = OutlinedButton(onPressed: onPressed, child: child);
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class StatusDot extends StatelessWidget {
  const StatusDot({required this.color, super.key, this.size = 7});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class ContextChip extends StatelessWidget {
  const ContextChip({required this.label, super.key, this.icon, this.onTap});

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.panelSoft,
        borderRadius: BorderRadius.circular(tokens.chipRadius),
        border: Border.all(color: tokens.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: tokens.textFaint),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: tokens.control.copyWith(
              fontSize: 12,
              color: tokens.textSoft,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) {
      return child;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.chipRadius),
      child: child,
    );
  }
}

class PiSelect<T> extends StatelessWidget {
  const PiSelect({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    super.key,
    this.compact = false,
    this.itemLabel,
  });

  final T? value;
  final String hint;
  final List<T> items;
  final ValueChanged<T?>? onChanged;
  final bool compact;
  final String Function(T value)? itemLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    String label(T item) => itemLabel?.call(item) ?? '$item';
    final enabled = onChanged != null && items.isNotEmpty;
    final shown = value == null ? hint : label(value as T);

    return MenuAnchor(
      consumeOutsideTap: true,
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(tokens.panel),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shadowColor: WidgetStatePropertyAll(
          Colors.black.withValues(alpha: 0.28),
        ),
        side: WidgetStatePropertyAll(BorderSide(color: tokens.line)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radius),
          ),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 6),
        ),
        maximumSize: const WidgetStatePropertyAll(Size(360, 420)),
      ),
      builder: (context, controller, child) {
        final labelWidget = ConstrainedBox(
          constraints: BoxConstraints(maxWidth: compact ? 168 : 480),
          child: Text(
            shown,
            overflow: TextOverflow.ellipsis,
            style: tokens.control.copyWith(
              fontSize: compact ? 12.5 : 13.5,
              fontWeight: FontWeight.w500,
              color: value == null ? tokens.textFaint : tokens.textSoft,
            ),
          ),
        );
        final trigger = Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: compact ? 6 : 10,
          ),
          child: Row(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            children: [
              if (compact) labelWidget else Expanded(child: labelWidget),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: tokens.textFaint,
              ),
            ],
          ),
        );
        return Tooltip(
          message: hint,
          child: Material(
            color: compact ? Colors.transparent : tokens.panelSoft,
            borderRadius: BorderRadius.circular(tokens.chipRadius),
            child: InkWell(
              onTap: enabled
                  ? () => controller.isOpen
                        ? controller.close()
                        : controller.open()
                  : null,
              borderRadius: BorderRadius.circular(tokens.chipRadius),
              child: trigger,
            ),
          ),
        );
      },
      menuChildren: [
        for (final item in items)
          MenuItemButton(
            onPressed: onChanged == null ? null : () => onChanged!(item),
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(
                value == item ? tokens.panelSoft : Colors.transparent,
              ),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
            child: Text(
              label(item),
              overflow: TextOverflow.ellipsis,
              style: tokens.control.copyWith(
                fontSize: 13,
                fontWeight: value == item ? FontWeight.w600 : FontWeight.w400,
                color: value == item ? tokens.text : tokens.textSoft,
              ),
            ),
          ),
      ],
    );
  }
}

class FoldBlock extends StatefulWidget {
  const FoldBlock({
    required this.title,
    required this.child,
    super.key,
    this.initiallyExpanded = false,
    this.accent,
  });

  final String title;
  final Widget child;
  final bool initiallyExpanded;
  final Color? accent;

  @override
  State<FoldBlock> createState() => _FoldBlockState();
}

class _FoldBlockState extends State<FoldBlock> with TickerProviderStateMixin {
  late var _open = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    final color = widget.accent ?? tokens.textFaint;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reducedMotion
        ? Duration.zero
        : const Duration(milliseconds: 180);
    // Trace data belongs to Pi, but it should recede until a user asks for it.
    // The deliberately translucent surface gives it a distinct layer without
    // turning every tool call into a heavy card.
    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(vertical: _open ? 3 : 0),
      decoration: BoxDecoration(
        color: _open
            ? tokens.panelSoft.withValues(alpha: 0.36)
            : Colors.transparent,
        border: Border.all(
          color: _open
              ? tokens.line.withValues(alpha: 0.6)
              : Colors.transparent,
        ),
        borderRadius: BorderRadius.circular(tokens.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _open,
            label: widget.title,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _open = !_open),
                borderRadius: BorderRadius.circular(tokens.chipRadius),
                hoverColor: tokens.panelSoft.withValues(alpha: 0.32),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      AnimatedRotation(
                        duration: duration,
                        curve: Curves.easeOutCubic,
                        turns: _open ? 0.25 : 0,
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          widget.title,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.control.copyWith(
                            color: color,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: duration,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 2, 12, 12),
                    child: TweenAnimationBuilder<double>(
                      duration: duration,
                      curve: Curves.easeOut,
                      tween: Tween(begin: 0, end: 1),
                      builder: (context, value, child) => Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, (1 - value) * -4),
                          child: child,
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.only(left: 10),
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: tokens.line.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                        child: widget.child,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class CodeSurface extends StatelessWidget {
  const CodeSurface({
    required this.text,
    super.key,
    this.color,
    this.maxHeight = 240,
    this.language,
  });

  final String text;
  final Color? color;
  final double? maxHeight;
  final String? language;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    final body = SelectableText(
      text,
      style: tokens.evidence.copyWith(color: color ?? tokens.text),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 10),
      decoration: BoxDecoration(
        color: tokens.panelSoft,
        borderRadius: BorderRadius.circular(tokens.chipRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  language?.isNotEmpty == true ? language! : 'code',
                  style: tokens.micro.copyWith(color: tokens.textFaint),
                ),
              ),
              IconButton(
                tooltip: 'Copy code',
                visualDensity: VisualDensity.compact,
                onPressed: () => copyText(text),
                icon: const Icon(Icons.copy_outlined, size: 15),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4),
            child: maxHeight == null
                ? body
                : ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxHeight!),
                    child: SingleChildScrollView(child: body),
                  ),
          ),
        ],
      ),
    );
  }
}

class SendButton extends StatelessWidget {
  const SendButton({
    required this.onPressed,
    super.key,
    this.tooltip = 'Send prompt',
  });

  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final tokens = PiTokens.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: onPressed == null ? tokens.panelSoft : tokens.accent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(
              Icons.arrow_upward,
              size: 16,
              color: onPressed == null
                  ? tokens.textFaint
                  : Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> copyText(String text) {
  return Clipboard.setData(ClipboardData(text: text));
}
