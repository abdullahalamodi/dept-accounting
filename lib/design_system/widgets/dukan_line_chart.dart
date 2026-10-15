import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/dukan_tokens.dart';

class DukanChartPoint {
  const DukanChartPoint({
    required this.label,
    required this.value,
    this.secondary,
  });
  final String label;
  final double value;
  final double? secondary;
}

class DukanLineChart extends StatefulWidget {
  const DukanLineChart({
    super.key,
    required this.points,
    required this.formatValue,
    required this.primaryLabel,
    this.secondaryLabel,
    this.height = 244,
  });
  final List<DukanChartPoint> points;
  final String Function(double) formatValue;
  final String primaryLabel;
  final String? secondaryLabel;
  final double height;

  @override
  State<DukanLineChart> createState() => _DukanLineChartState();
}

class _DukanLineChartState extends State<DukanLineChart> {
  int? selected;

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) return SizedBox(height: widget.height);
    final points = widget.points;
    final values = [
      0.0,
      for (final p in points) ...[p.value, ?p.secondary],
    ];
    final maximum = values.reduce(math.max), minimum = values.reduce(math.min);
    final span = maximum - minimum;
    final step = span == 0
        ? 1.0
        : math.pow(10, (math.log(span / 3) / math.ln10).floor()).toDouble();
    final tick = span == 0 ? 1.0 : (span / 3 / step).ceil() * step;
    final bottom = (minimum / tick).floor() * tick;
    final top = maximum == 0 && minimum == 0
        ? 3.0
        : (maximum / tick).ceil() * tick;
    final style = Theme.of(context).textTheme.bodySmall!
        .copyWith(color: DukanColors.muted);
    final index = selected?.clamp(0, points.length - 1);
    return Semantics(
      label: points
          .map(
            (p) =>
                '${p.label}: ${widget.primaryLabel} ${widget.formatValue(p.value)}${p.secondary == null ? '' : '، ${widget.secondaryLabel} ${widget.formatValue(p.secondary!)}'}',
          )
          .join('؛ '),
      child: ExcludeSemantics(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              SizedBox(
                height: widget.height,
                child: LayoutBuilder(
                  builder: (context, size) {
                    void select(Offset offset) {
                      final fraction = ((offset.dx - 52) / (size.maxWidth - 64))
                          .clamp(0.0, 1.0);
                      setState(
                        () =>
                            selected = (fraction * (points.length - 1)).round(),
                      );
                    }

                    return MouseRegion(
                      onHover: (event) => select(event.localPosition),
                      onExit: (_) => setState(() => selected = null),
                      child: GestureDetector(
                        onTapDown: (event) => select(event.localPosition),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _LinePainter(
                                  points: points,
                                  minimum: bottom,
                                  maximum: top,
                                  style: style,
                                  format: widget.formatValue,
                                  selected: index,
                                ),
                              ),
                            ),
                            if (index != null)
                              Positioned(
                                top: 0,
                                right: 12,
                                child: IgnorePointer(
                                  child: Container(
                                    constraints: BoxConstraints(
                                      maxWidth: size.maxWidth - 64,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: DukanColors.surface,
                                      border: Border.all(
                                        color: DukanColors.border,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        DukanLayout.radius,
                                      ),
                                    ),
                                    child: Text(
                                      '${points[index].label}  ·  ${widget.primaryLabel}: ${widget.formatValue(points[index].value)}${points[index].secondary == null ? '' : '\n${widget.secondaryLabel}: ${widget.formatValue(points[index].secondary!)}'}',
                                      textDirection: TextDirection.rtl,
                                      style: style.copyWith(
                                        color: DukanColors.ink,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(left: 38),
                child: Row(
                  children: [
                    for (var i = 0; i < points.length; i++)
                      if (points.length <= 7 ||
                          i == 0 ||
                          i == points.length - 1 ||
                          i % 6 == 0)
                        Expanded(
                          child: Text(
                            points[i].label,
                            textAlign: TextAlign.center,
                            style: style,
                            maxLines: 1,
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.points,
    required this.minimum,
    required this.maximum,
    required this.style,
    required this.format,
    required this.selected,
  });
  final List<DukanChartPoint> points;
  final double minimum, maximum;
  final TextStyle style;
  final String Function(double) format;
  final int? selected;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(52, 18, size.width - 12, size.height - 8);
    double y(double value) =>
        plot.bottom - (value - minimum) / (maximum - minimum) * plot.height;
    final grid = Paint()
      ..color = DukanColors.border
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final value = minimum + (maximum - minimum) * i / 3;
      final at = y(value);
      for (var x = plot.left; x < plot.right; x += 11) {
        canvas.drawLine(
          Offset(x, at),
          Offset(math.min(x + 5, plot.right), at),
          grid,
        );
      }
      final text = TextPainter(
        text: TextSpan(text: format(value), style: style),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 46);
      text.paint(
        canvas,
        Offset(plot.left - text.width - 10, at - text.height / 2),
      );
    }
    List<Offset> offsets(bool secondary) => [
      for (var i = 0; i < points.length; i++)
        Offset(
          plot.left + plot.width * i / math.max(1, points.length - 1),
          y(secondary ? points[i].secondary! : points[i].value),
        ),
    ];
    Path line(List<Offset> dots) {
      final path = Path()..moveTo(dots.first.dx, dots.first.dy);
      for (var i = 1; i < dots.length; i++) {
        final previous = dots[i - 1], current = dots[i];
        final mid = (previous.dx + current.dx) / 2;
        path.cubicTo(mid, previous.dy, mid, current.dy, current.dx, current.dy);
      }
      return path;
    }

    final primary = offsets(false), path = line(primary);
    final fill = Path.from(path)
      ..lineTo(primary.last.dx, y(0))
      ..lineTo(primary.first.dx, y(0))
      ..close();
    canvas.save();
    canvas.clipRect(plot.inflate(5));
    canvas.drawPath(
      fill,
      Paint()..color = DukanColors.primarySoft.withValues(alpha: .65),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = DukanColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8,
    );
    if (points.every((p) => p.secondary != null)) {
      canvas.drawPath(
        line(offsets(true)),
        Paint()
          ..color = DukanColors.chartSecondary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    }
    final dot = primary[selected ?? primary.length - 1];
    if (selected != null) {
      canvas.drawLine(
        Offset(dot.dx, plot.top),
        Offset(dot.dx, plot.bottom),
        grid,
      );
    }
    canvas.drawCircle(dot, 5.5, Paint()..color = DukanColors.surface);
    canvas.drawCircle(dot, 3.5, Paint()..color = DukanColors.primary);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.points != points ||
      old.selected != selected ||
      old.minimum != minimum ||
      old.maximum != maximum ||
      old.style != style;
}
