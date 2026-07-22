import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/expense_provider.dart';
import '../providers/settings_provider.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../utils/jalali_extension.dart';

class ChartsScreen extends StatefulWidget {
  final String eventId;
  final Color eventColor;

  const ChartsScreen({
    super.key,
    required this.eventId,
    required this.eventColor,
  });

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  int _donutTouchedIndex = -1;
  int? _stickyBarIndex;
  Timer? _tooltipTimer;
  Timer? _donutTimer;
  bool _donutIsPressed = false;

  // پالت رنگی هماهنگ
  List<Color> _generatePalette(Color base, int count) {
    if (count == 0) return [];
    final hsl = HSLColor.fromColor(base);
    final List<Color> colors = [];
    for (int i = 0; i < count; i++) {
      final hue = (hsl.hue + (i * 360 / count)) % 360;
      colors.add(
        HSLColor.fromAHSL(
          1.0,
          hue,
          (hsl.saturation * 0.8).clamp(0.35, 0.85),
          (hsl.lightness).clamp(0.40, 0.65),
        ).toColor(),
      );
    }
    return colors;
  }

  @override
  void dispose() {
    _tooltipTimer?.cancel();
    _donutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final eventData = provider.getEventData(widget.eventId);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (eventData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('نمودارها'),
          centerTitle: true,
          backgroundColor: widget.eventColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('رویداد یافت نشد')),
      );
    }

    final participants = eventData.participants;
    final expenses = eventData.expenses;

    // حالت خالی
    if (expenses.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('نمودارها'),
          centerTitle: true,
          backgroundColor: widget.eventColor,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.insert_chart_outlined_rounded,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'هنوز هزینه‌ای ثبت نشده',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'پس از ثبت هزینه‌ها، نمودارها اینجا نمایش داده می‌شوند',
                style: TextStyle(fontSize: 13, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      );
    }

    // محاسبات
    final totalExpenses = expenses.fold<double>(
      0.0,
      (sum, e) => sum + e.amount,
    );
    final fairShare = participants.isNotEmpty
        ? (totalExpenses / participants.length).toDouble()
        : 0.0;
    final balances = provider.calculateBalancesForEvent(widget.eventId);
    final debts = provider.calculateDebtsForEvent(widget.eventId);

    // بررسی سهم مساوی
    bool showFairShare = true;
    for (var expense in expenses) {
      if (expense.involvedParticipantIds.length != participants.length) {
        showFairShare = false;
        break;
      }

      bool isActuallyEqual = true;
      final numParticipants = expense.involvedParticipantIds.length;

      if (expense.splitType == 'equal') {
        isActuallyEqual = true;
      } else if (expense.splitType == 'percent' &&
          expense.customWeights != null) {
        final expectedPercent = 100.0 / numParticipants;
        double firstWeight = -1;
        for (var id in expense.involvedParticipantIds) {
          final weight = expense.customWeights![id];
          if (weight == null) {
            isActuallyEqual = false;
            break;
          }
          if (firstWeight < 0) {
            firstWeight = weight;
          }
          if ((weight - expectedPercent).abs() > 0.01) {
            isActuallyEqual = false;
            break;
          }
        }
      } else if (expense.splitType == 'shares' &&
          expense.customWeights != null) {
        double firstWeight = -1;
        for (var id in expense.involvedParticipantIds) {
          final weight = expense.customWeights![id];
          if (weight == null) {
            isActuallyEqual = false;
            break;
          }
          if (firstWeight < 0) {
            firstWeight = weight;
          }
          if ((weight - firstWeight).abs() > 0.001) {
            isActuallyEqual = false;
            break;
          }
        }
      } else if (expense.splitType == 'amount' &&
          expense.customWeights != null) {
        final expectedAmount = expense.amount / numParticipants;
        for (var id in expense.involvedParticipantIds) {
          final weight = expense.customWeights![id];
          if (weight == null) {
            isActuallyEqual = false;
            break;
          }
          if ((weight - expectedAmount).abs() > 0.01) {
            isActuallyEqual = false;
            break;
          }
        }
      } else {
        isActuallyEqual = false;
      }

      if (!isActuallyEqual) {
        showFairShare = false;
        break;
      }
    }

    // سهم پرداخت هر نفر
    final Map<String, double> totalPaidByPerson = {};
    for (var p in participants) {
      totalPaidByPerson[p.id] = 0;
    }
    for (var expense in expenses) {
      totalPaidByPerson[expense.payerId] =
          (totalPaidByPerson[expense.payerId] ?? 0) + expense.amount;
    }

    final palette = _generatePalette(widget.eventColor, participants.length);
    final eventName = eventData.event.name;

    // وضعیت تسویه‌ها
    final settledDebts = debts.where((d) => d.isSettled).toList();
    final unsettledDebts = debts.where((d) => !d.isSettled).toList();
    final settledAmount = settledDebts.fold<double>(
      0.0,
      (sum, d) => sum + d.amount,
    );
    final unsettledAmount = unsettledDebts.fold<double>(
      0.0,
      (sum, d) => sum + d.amount,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('نمودارها'),
        centerTitle: true,
        backgroundColor: widget.eventColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'اشتراک‌گذاری تصویری',
            onPressed: () => _shareAllChartsImage(context, eventName, isDark),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ═══════════════════════════════════════
            // کارت‌های خلاصه آماری
            // ═══════════════════════════════════════
            _buildSummaryCards(
              context,
              settings,
              totalExpenses,
              participants.length,
              expenses.length,
              fairShare,
              showFairShare,
              isDark,
            ),
            const SizedBox(height: 24),

            // ═══════════════════════════════════════
            // نمودار Donut — سهم پرداخت هر نفر
            // ═══════════════════════════════════════
            _buildSectionCard(
              context,
              icon: Icons.donut_large_rounded,
              title: 'سهم پرداخت هر نفر',
              isDark: isDark,
              trailing: GestureDetector(
                onTap: () => _shareDonutChartImage(
                  context,
                  eventName,
                  participants,
                  totalPaidByPerson,
                  totalExpenses,
                  settings,
                  isDark,
                ),
                child: Icon(
                  Icons.share,
                  size: 18,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 220,
                    child: PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            final isPressStart =
                                event is FlTapDownEvent ||
                                event is FlPanStartEvent;
                            final isPressEnd =
                                event is FlTapUpEvent ||
                                event is FlPanEndEvent ||
                                event is FlTapCancelEvent ||
                                event is FlPanCancelEvent;

                            if (isPressStart) {
                              _donutIsPressed = true;
                              _donutTimer?.cancel();
                              if (response != null &&
                                  response.touchedSection != null) {
                                setState(() {
                                  _donutTouchedIndex = response
                                      .touchedSection!.touchedSectionIndex;
                                });
                              }
                            } else if (isPressEnd && _donutIsPressed) {
                              _donutIsPressed = false;
                              _donutTimer?.cancel();
                              _donutTimer = Timer(
                                const Duration(seconds: 2),
                                () {
                                  if (mounted) {
                                    setState(() {
                                      _donutTouchedIndex = -1;
                                    });
                                  }
                                },
                              );
                            } else if (!_donutIsPressed) {
                              _donutTimer?.cancel();
                              if (response != null &&
                                  response.touchedSection != null) {
                                setState(() {
                                  _donutTouchedIndex = response
                                      .touchedSection!.touchedSectionIndex;
                                });
                              } else {
                                setState(() {
                                  _donutTouchedIndex = -1;
                                });
                              }
                            }
                          },
                        ),
                        borderData: FlBorderData(show: false),
                        sectionsSpace: 2,
                        centerSpaceRadius: 50,
                        sections: _buildDonutSections(
                          participants,
                          totalPaidByPerson,
                          totalExpenses,
                          palette,
                          settings,
                        ),
                      ),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOutCubic,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // مبلغ کل در وسط (شبیه label)
                  Text(
                    'مجموع: ${settings.formatAmount(totalExpenses).toPersianNumbers()}',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Legend
                  _buildDonutLegend(
                    participants,
                    totalPaidByPerson,
                    totalExpenses,
                    palette,
                    settings,
                    isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ═══════════════════════════════════════
            // نمودار Bar افقی — مانده حساب
            // ═══════════════════════════════════════
            _buildSectionCard(
              context,
              icon: Icons.bar_chart_rounded,
              title: 'مانده حساب هر نفر',
              isDark: isDark,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if ((participants.length * 50.0) > 300) ...[
                    Icon(
                      Icons.swipe_left,
                      size: 16,
                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                    ),
                    const SizedBox(width: 10),
                  ],
                  GestureDetector(
                    onTap: () => _shareBarChartImage(
                      context,
                      eventName,
                      participants,
                      balances,
                      settings,
                      isDark,
                    ),
                    child: Icon(
                      Icons.share,
                      size: 18,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
              child: _buildBalanceBarChart(
                context,
                participants,
                balances,
                settings,
                isDark,
              ),
            ),
            const SizedBox(height: 20),

            // ═══════════════════════════════════════
            // نمودار وضعیت تسویه
            // ═══════════════════════════════════════
            if (debts.isNotEmpty)
              _buildSectionCard(
                context,
                icon: Icons.check_circle_outline_rounded,
                title: 'وضعیت تسویه‌ها',
                isDark: isDark,
                child: _buildSettlementChart(
                  context,
                  settledDebts,
                  unsettledDebts,
                  settledAmount,
                  unsettledAmount,
                  settings,
                  isDark,
                ),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // اشتراک‌گذاری تصویری کل نمودارها
  // ═══════════════════════════════════════════════════
  Future<void> _shareAllChartsImage(
    BuildContext context,
    String eventName,
    bool isDark,
  ) async {
    try {
      final color = widget.eventColor;
      final completer = Completer<Uint8List>();
      final repaintKey = GlobalKey();
      OverlayEntry? entry;

      final provider = Provider.of<ExpenseProvider>(context, listen: false);
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      final eventData = provider.getEventData(widget.eventId);
      if (eventData == null) return;

      final participants = eventData.participants;
      final expenses = eventData.expenses;
      final totalExpenses = expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
      final balances = provider.calculateBalancesForEvent(widget.eventId);

      final Map<String, double> totalPaidByPerson = {};
      for (var p in participants) {
        totalPaidByPerson[p.id] = 0;
      }
      for (var expense in expenses) {
        totalPaidByPerson[expense.payerId] =
            (totalPaidByPerson[expense.payerId] ?? 0) + expense.amount;
      }

      final fairShare = participants.isNotEmpty
          ? (totalExpenses / participants.length).toDouble()
          : 0.0;
      bool showFairShare = true;
      for (var expense in expenses) {
        if (expense.involvedParticipantIds.length != participants.length) {
          showFairShare = false;
          break;
        }
        bool isActuallyEqual = true;
        final numParticipants = expense.involvedParticipantIds.length;
        if (expense.splitType == 'equal') {
          isActuallyEqual = true;
        } else if ((expense.splitType == 'percent' || expense.splitType == 'shares') &&
            expense.customWeights != null) {
          double firstWeight = -1;
          for (var id in expense.involvedParticipantIds) {
            final weight = expense.customWeights![id];
            if (weight == null) { isActuallyEqual = false; break; }
            if (firstWeight < 0) { firstWeight = weight; }
            if (expense.splitType == 'percent' &&
                (weight - 100.0 / numParticipants).abs() > 0.01) {
              isActuallyEqual = false; break;
            }
            if (expense.splitType == 'shares' &&
                (weight - firstWeight).abs() > 0.001) {
              isActuallyEqual = false; break;
            }
          }
        } else {
          isActuallyEqual = false;
        }
        if (!isActuallyEqual) { showFairShare = false; break; }
      }
      final debts = provider.calculateDebtsForEvent(widget.eventId);
      final settledDebts = debts.where((d) => d.isSettled).toList();
      final unsettledDebts = debts.where((d) => !d.isSettled).toList();
      final settledAmount = settledDebts.fold<double>(0, (s, d) => s + d.amount);
      final unsettledAmount = unsettledDebts.fold<double>(0, (s, d) => s + d.amount);

      final chartWidth = max(480.0, participants.length * 50.0);

      entry = OverlayEntry(
        builder: (BuildContext overlayContext) => Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              Positioned(
                left: -10000,
                top: 0,
                child: RepaintBoundary(
                  key: repaintKey,
                  child: SizedBox(
                    width: chartWidth,
                    child: _buildAllChartsSharePreview(
                      context: context,
                      isDark: isDark,
                      color: color,
                      eventName: eventName,
                      participants: participants,
                      expenses: expenses,
                      totalExpenses: totalExpenses,
                      balances: balances,
                      totalPaidByPerson: totalPaidByPerson,
                      fairShare: fairShare,
                      showFairShare: showFairShare,
                      settledDebts: settledDebts,
                      unsettledDebts: unsettledDebts,
                      settledAmount: settledAmount,
                      unsettledAmount: unsettledAmount,
                      settings: settings,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      Overlay.of(context, rootOverlay: true).insert(entry);
      await Future.delayed(const Duration(milliseconds: 500));

      final boundary =
          repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 2.5);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          completer.complete(byteData.buffer.asUint8List());
        } else {
          completer.completeError('Failed to get image bytes');
        }
      } else {
        completer.completeError('Failed to capture widget');
      }

      entry.remove();
      final pngBytes = await completer.future;
      final fileName =
          '${eventName.replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), '_').replaceAll(RegExp(r'\s+'), '_')}_charts.png';
      if (context.mounted) {
        await _shareImage(
          context: context,
          pngBytes: pngBytes,
          fileName: fileName,
          shareText: 'نمودارهای $eventName',
          shareSubject: 'نمودارهای $eventName',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در اشتراک‌گذاری تصویر: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildAllChartsSharePreview({
    required BuildContext context,
    required bool isDark,
    required Color color,
    required String eventName,
    required List participants,
    required List expenses,
    required double totalExpenses,
    required Map<String, double> balances,
    required Map<String, double> totalPaidByPerson,
    required double fairShare,
    required bool showFairShare,
    required List settledDebts,
    required List unsettledDebts,
    required double settledAmount,
    required double unsettledAmount,
    required SettingsProvider settings,
  }) {
    final palette = _generatePalette(color, participants.length);
    final debts = [...settledDebts, ...unsettledDebts];

    final sorted = List.from(participants)
      ..sort((a, b) {
        final balA = balances[a.id] ?? 0;
        final balB = balances[b.id] ?? 0;
        return balB.compareTo(balA);
      });
    final maxVal = balances.values.fold<double>(0, (m, v) => max(m, v.abs()));
    final chartMaxVal = maxVal > 0 ? maxVal * 1.2 : 1.0;
    final barHeight = max(sorted.length * 52.0, 120.0);

    return Container(
      color: isDark ? const Color(0xFF121212) : Colors.grey[100],
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.16),
                  color.withOpacity(0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.18)),
            ),
            child: Text(
              eventName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color.lerp(color, Colors.black, 0.22),
                fontFamily: 'Vazirmatn',
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryCards(
            context,
            settings,
            totalExpenses,
            participants.length,
            expenses.length,
            fairShare,
            showFairShare,
            isDark,
          ),
          const SizedBox(height: 24),
          _buildSectionCard(
            context,
            icon: Icons.donut_large_rounded,
            title: 'سهم پرداخت هر نفر',
            isDark: isDark,
            child: Column(
              children: [
                SizedBox(
                  height: 220,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(enabled: false),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 2,
                      centerSpaceRadius: 50,
                      sections: _buildDonutSections(
                        participants,
                        totalPaidByPerson,
                        totalExpenses,
                        palette,
                        settings,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'مجموع: ${settings.formatAmount(totalExpenses).toPersianNumbers()}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                _buildDonutLegend(
                  participants,
                  totalPaidByPerson,
                  totalExpenses,
                  palette,
                  settings,
                  isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionCard(
            context,
            icon: Icons.bar_chart_rounded,
            title: 'مانده حساب هر نفر',
            isDark: isDark,
            child: Column(
              children: [
                SizedBox(
                  height: barHeight,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: chartMaxVal,
                      minY: -chartMaxVal,
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        show: true,
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: chartMaxVal / 3,
                        getDrawingHorizontalLine: (value) {
                          if (value.abs() < 0.01) {
                            return FlLine(
                              color: isDark ? Colors.grey[600]! : Colors.grey[400]!,
                              strokeWidth: 1.5,
                            );
                          }
                          return FlLine(
                            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                            strokeWidth: 0.5,
                          );
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(sorted.length, (i) {
                        final balance = balances[sorted[i].id] ?? 0;
                        final isPositive = balance > 0.01;
                        final isNegative = balance < -0.01;
                        final isZero = !isPositive && !isNegative;
                        final displayY = isZero ? chartMaxVal * 0.2 : balance;
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: displayY,
                              color: isPositive
                                  ? Colors.green.shade400
                                  : isNegative
                                      ? Colors.red.shade400
                                      : (isDark ? Colors.grey[600]! : Colors.grey[400]!),
                              width: 18,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(!isNegative ? 6 : 0),
                                topRight: Radius.circular(!isNegative ? 6 : 0),
                                bottomLeft: Radius.circular(isNegative ? 6 : 0),
                                bottomRight: Radius.circular(isNegative ? 6 : 0),
                              ),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: isZero
                                    ? -chartMaxVal * 0.2
                                    : isPositive
                                        ? chartMaxVal * 0.15
                                        : -chartMaxVal * 0.15,
                                color: (isPositive ? Colors.green : isNegative ? Colors.red : Colors.grey)
                                    .withOpacity(0.06),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOutCubic,
                  ),
                ),
                const SizedBox(height: 16),
                Column(
                  children: List.generate(sorted.length, (i) {
                    final p = sorted[i];
                    final balance = balances[p.id] ?? 0;
                    final isPositive = balance > 0.01;
                    final isNegative = balance < -0.01;
                    final bColor = isPositive
                        ? Colors.green.shade400
                        : isNegative
                            ? Colors.red.shade400
                            : (isDark ? Colors.grey[600]! : Colors.grey[400]!);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: bColor,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            p.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.grey[300] : Colors.grey[700],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${settings.formatAmount(balance.abs()).toPersianNumbers()})',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.grey[500] : Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          if (debts.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildSectionCard(
              context,
              icon: Icons.check_circle_outline_rounded,
              title: 'وضعیت تسویه‌ها',
              isDark: isDark,
              child: _buildSettlementChart(
                context,
                settledDebts,
                unsettledDebts,
                settledAmount,
                unsettledAmount,
                settings,
                isDark,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // کارت‌های خلاصه آماری
  // ═══════════════════════════════════════════════════
  Widget _buildSummaryCards(
    BuildContext context,
    SettingsProvider settings,
    double totalExpenses,
    int participantsCount,
    int expensesCount,
    double fairShare,
    bool showFairShare,
    bool isDark,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isDark
                ? widget.eventColor.withOpacity(0.2)
                : widget.eventColor.withOpacity(0.1),
            isDark
                ? widget.eventColor.withOpacity(0.1)
                : widget.eventColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCompactStat(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'مجموع هزینه‌ها',
                    value: settings
                        .formatAmount(totalExpenses)
                        .toPersianNumbers(),
                    color: widget.eventColor,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildCompactStat(
                    icon: Icons.people_rounded,
                    label: 'شرکت‌کنندگان',
                    value: '$participantsCount نفر'.toPersianNumbers(),
                    color: Colors.indigo,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const VerticalDivider(
              width: 20,
              thickness: 1,
              indent: 4,
              endIndent: 4,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCompactStat(
                    icon: Icons.functions_rounded,
                    label: 'میانگین سهم هر نفر',
                    value: showFairShare
                        ? settings.formatAmount(fairShare).toPersianNumbers()
                        : 'نامساوی',
                    color: Colors.purple,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildCompactStat(
                    icon: Icons.receipt_long_rounded,
                    label: 'تعداد هزینه‌ها',
                    value: '$expensesCount مورد'.toPersianNumbers(),
                    color: Colors.deepOrange,
                    isDark: isDark,
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

  Widget _buildCompactStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(isDark ? 0.15 : 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey[800],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  // بخش کارت عمومی
  // ═══════════════════════════════════════════════════
  Widget _buildSectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool isDark,
    required Widget child,
    Widget? trailing,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: widget.eventColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.grey[800],
                  ),
                ),
                if (trailing != null) ...[
                  const Spacer(),
                  trailing,
                ],
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Future<void> _shareDonutChartImage(
    BuildContext context,
    String eventName,
    List participants,
    Map<String, double> totalPaid,
    double totalExpenses,
    SettingsProvider settings,
    bool isDark,
  ) async {
    try {
      final color = widget.eventColor;
      final completer = Completer<Uint8List>();
      final repaintKey = GlobalKey();
      OverlayEntry? entry;

      entry = OverlayEntry(
        builder: (BuildContext overlayContext) => Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              Positioned(
                left: -10000,
                top: 0,
                child: RepaintBoundary(
                  key: repaintKey,
                  child: SizedBox(
                    width: 480,
                    child: _buildDonutSharePreview(
                      context: overlayContext,
                      eventName: eventName,
                      participants: participants,
                      totalPaid: totalPaid,
                      totalExpenses: totalExpenses,
                      settings: settings,
                      isDark: isDark,
                      color: color,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      Overlay.of(context, rootOverlay: true).insert(entry);
      await Future.delayed(const Duration(milliseconds: 300));

      final boundary =
          repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 2.5);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          completer.complete(byteData.buffer.asUint8List());
        } else {
          completer.completeError('Failed to get image bytes');
        }
      } else {
        completer.completeError('Failed to capture widget');
      }

      entry.remove();
      final pngBytes = await completer.future;
      final fileName =
          '${eventName.replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), '_').replaceAll(RegExp(r'\s+'), '_')}_donut.png';
      if (context.mounted) {
        await _shareImage(
          context: context,
          pngBytes: pngBytes,
          fileName: fileName,
          shareText: 'سهم پرداخت هر نفر - $eventName',
          shareSubject: 'سهم پرداخت هر نفر - $eventName',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در اشتراک‌گذاری تصویر: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDonutSharePreview({
    required BuildContext context,
    required String eventName,
    required List participants,
    required Map<String, double> totalPaid,
    required double totalExpenses,
    required SettingsProvider settings,
    required bool isDark,
    required Color color,
  }) {
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final palette = _generatePalette(color, participants.length);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.donut_large_rounded, color: color, size: 24),
              const SizedBox(width: 8),
              Text(
                'سهم پرداخت هر نفر',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(enabled: false),
                borderData: FlBorderData(show: false),
                sectionsSpace: 2,
                centerSpaceRadius: 50,
                sections: _buildDonutSections(
                  participants,
                  totalPaid,
                  totalExpenses,
                  palette,
                  settings,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'مجموع: ${settings.formatAmount(totalExpenses).toPersianNumbers()}',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          _buildDonutLegend(
            participants,
            totalPaid,
            totalExpenses,
            palette,
            settings,
            isDark,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // Donut Chart — سهم پرداخت
  // ═══════════════════════════════════════════════════
  List<PieChartSectionData> _buildDonutSections(
    List participants,
    Map<String, double> totalPaid,
    double totalExpenses,
    List<Color> palette,
    SettingsProvider settings,
  ) {
    final List<PieChartSectionData> sections = [];
    int sectionIndex = 0; // Track actual section index

    for (int i = 0; i < participants.length; i++) {
      final p = participants[i];
      final paid = totalPaid[p.id] ?? 0;
      if (paid <= 0) continue;

      final pct = (paid / totalExpenses * 100);
      final isTouched = sectionIndex == _donutTouchedIndex;
      final radius = isTouched ? 55.0 : 45.0;
      final fontSize = isTouched ? 14.0 : 11.0;

      sections.add(
        PieChartSectionData(
          color: palette[i % palette.length],
          value: paid,
          title: '${pct.toStringAsFixed(0)}٪'.toPersianNumbers(),
          radius: radius,
          titleStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: const [Shadow(blurRadius: 3, color: Colors.black38)],
          ),
          badgePositionPercentageOffset: isTouched ? 1.15 : null,
          badgeWidget: isTouched
              ? _buildDonutBadge(
                  p.name,
                  settings.formatAmount(paid).toPersianNumbers(),
                  palette[i % palette.length],
                )
              : null,
        ),
      );
      sectionIndex++; // Increment after adding section
    }

    return sections;
  }

  Widget _buildDonutBadge(String name, String amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            amount,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Future<void> _shareBarChartImage(
    BuildContext context,
    String eventName,
    List participants,
    Map<String, double> balances,
    SettingsProvider settings,
    bool isDark,
  ) async {
    try {
      final color = widget.eventColor;
      final completer = Completer<Uint8List>();
      final repaintKey = GlobalKey();
      OverlayEntry? entry;
      final chartWidth = max(480.0, participants.length * 50.0);

      entry = OverlayEntry(
        builder: (BuildContext overlayContext) => Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              Positioned(
                left: -10000,
                top: 0,
                child: RepaintBoundary(
                  key: repaintKey,
                  child: SizedBox(
                    width: chartWidth,
                    child: _buildBarChartSharePreview(
                      context: overlayContext,
                      eventName: eventName,
                      participants: participants,
                      balances: balances,
                      settings: settings,
                      isDark: isDark,
                      color: color,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      Overlay.of(context, rootOverlay: true).insert(entry);
      await Future.delayed(const Duration(milliseconds: 300));

      final boundary =
          repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 2.5);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          completer.complete(byteData.buffer.asUint8List());
        } else {
          completer.completeError('Failed to get image bytes');
        }
      } else {
        completer.completeError('Failed to capture widget');
      }

      entry.remove();
      final pngBytes = await completer.future;
      final fileName =
          '${eventName.replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), '_').replaceAll(RegExp(r'\s+'), '_')}_balance.png';
      if (context.mounted) {
        await _shareImage(
          context: context,
          pngBytes: pngBytes,
          fileName: fileName,
          shareText: 'مانده حساب هر نفر - $eventName',
          shareSubject: 'مانده حساب هر نفر - $eventName',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در اشتراک‌گذاری تصویر: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildBarChartSharePreview({
    required BuildContext context,
    required String eventName,
    required List participants,
    required Map<String, double> balances,
    required SettingsProvider settings,
    required bool isDark,
    required Color color,
  }) {
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final sorted = List.from(participants)
      ..sort((a, b) {
        final balA = balances[a.id] ?? 0;
        final balB = balances[b.id] ?? 0;
        return balB.compareTo(balA);
      });
    final maxVal = balances.values.fold<double>(0, (m, v) => max(m, v.abs()));
    final chartMaxVal = maxVal > 0 ? maxVal * 1.2 : 1.0;
    final barHeight = max(sorted.length * 52.0, 120.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: color, size: 24),
              const SizedBox(width: 8),
              Text(
                'مانده حساب هر نفر',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: barHeight,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: chartMaxVal,
                minY: -chartMaxVal,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: chartMaxVal / 3,
                  getDrawingHorizontalLine: (value) {
                    if (value.abs() < 0.01) {
                      return FlLine(
                        color: isDark ? Colors.grey[600]! : Colors.grey[400]!,
                        strokeWidth: 1.5,
                      );
                    }
                    return FlLine(
                      color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                      strokeWidth: 0.5,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(sorted.length, (i) {
                  final balance = balances[sorted[i].id] ?? 0;
                  final isPositive = balance > 0.01;
                  final isNegative = balance < -0.01;
                  final isZero = !isPositive && !isNegative;
                  final displayY = isZero ? chartMaxVal * 0.2 : balance;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: displayY,
                        color: isPositive
                            ? Colors.green.shade400
                            : isNegative
                                ? Colors.red.shade400
                                : (isDark ? Colors.grey[600]! : Colors.grey[400]!),
                        width: 18,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(!isNegative ? 6 : 0),
                          topRight: Radius.circular(!isNegative ? 6 : 0),
                          bottomLeft: Radius.circular(isNegative ? 6 : 0),
                          bottomRight: Radius.circular(isNegative ? 6 : 0),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: isZero,
                          toY: -chartMaxVal * 0.2,
                          color: Colors.grey.withOpacity(0.06),
                        ),
                      ),
                    ],
                  );
                }),
              ),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOutCubic,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: List.generate(sorted.length, (i) {
              final p = sorted[i];
              final balance = balances[p.id] ?? 0;
              final isPositive = balance > 0.01;
              final isNegative = balance < -0.01;
              final bColor = isPositive
                  ? Colors.green.shade400
                  : isNegative
                      ? Colors.red.shade400
                      : (isDark ? Colors.grey[600]! : Colors.grey[400]!);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: bColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      p.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(${settings.formatAmount(balance.abs()).toPersianNumbers()})',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.grey[500] : Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDonutLegend(
    List participants,
    Map<String, double> totalPaid,
    double totalExpenses,
    List<Color> palette,
    SettingsProvider settings,
    bool isDark,
  ) {
    final validParticipants = participants.where((p) {
      final paid = totalPaid[p.id] ?? 0;
      return paid > 0;
    }).toList();

    if (validParticipants.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(validParticipants.length, (i) {
        final p = validParticipants[i];
        final paid = totalPaid[p.id] ?? 0;

        return Column(
          children: [
            if (i > 0) const SizedBox(height: 8),
            Row(
              textDirection: TextDirection.rtl,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: palette[participants.indexOf(p) % palette.length],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  p.name,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '(${settings.formatAmount(paid).toPersianNumbers()})',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                  ),
                ),
              ],
            ),
          ],
        );
      }),
    );
  }

  // ═══════════════════════════════════════════════════
  // Horizontal Bar Chart — مانده حساب
  // ═══════════════════════════════════════════════════
  Widget _buildBalanceBarChart(
    BuildContext context,
    List participants,
    Map<String, double> balances,
    SettingsProvider settings,
    bool isDark,
  ) {
    if (participants.isEmpty) {
      return const Center(child: Text('شرکت‌کننده‌ای وجود ندارد'));
    }

    // ترتیب بر اساس مانده (بیشترین طلب بالا)
    final sorted = List.from(participants)
      ..sort((a, b) {
        final balA = balances[a.id] ?? 0;
        final balB = balances[b.id] ?? 0;
        return balB.compareTo(balA);
      });

    final maxVal = balances.values.fold<double>(0, (m, v) => max(m, v.abs()));
    final chartMaxVal = maxVal > 0 ? maxVal * 1.2 : 1.0;

    final barHeight = max(sorted.length * 52.0, 120.0);
    final minChartWidth = sorted.length * 50.0;

    final chartWidget = BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: chartMaxVal,
        minY: -chartMaxVal,
        barTouchData: BarTouchData(
          enabled: true,
          handleBuiltInTouches: false,
          touchCallback: (FlTouchEvent event, BarTouchResponse? response) {
            if (event is FlTapDownEvent || event is FlPanStartEvent) {
              if (response != null && response.spot != null) {
                final tappedIndex = response.spot!.touchedBarGroupIndex;
                _tooltipTimer?.cancel();
                setState(() {
                  _stickyBarIndex = tappedIndex;
                });
                _tooltipTimer = Timer(const Duration(seconds: 5), () {
                  if (mounted) {
                    setState(() {
                      _stickyBarIndex = null;
                    });
                  }
                });
              }
            } else if (event is FlTapUpEvent || event is FlPanEndEvent) {
              if (response == null || response.spot == null) {
                _tooltipTimer?.cancel();
                _tooltipTimer = Timer(const Duration(seconds: 2), () {
                  if (mounted) {
                    setState(() {
                      _stickyBarIndex = null;
                    });
                  }
                });
              }
            }
          },
          touchTooltipData: BarTouchTooltipData(
            tooltipBorderRadius: const BorderRadius.all(Radius.circular(10)),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipColor: (touchedBarGroup) {
              final p = sorted[touchedBarGroup.x];
              final balance = balances[p.id] ?? 0;
              final isPositive = balance > 0.01;
              final isNegative = balance < -0.01;
              if (isPositive) return Colors.green.shade700;
              if (isNegative) return Colors.red.shade700;
              return isDark ? Colors.grey[600]! : Colors.grey[500]!;
            },
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final p = sorted[group.x];
              final balance = balances[p.id] ?? 0;
              final isPositive = balance > 0.01;
              final isNegative = balance < -0.01;
              final status = isPositive
                  ? 'طلبکار'
                  : isNegative
                  ? 'بدهکار'
                  : 'بی‌حساب';
              return BarTooltipItem(
                '${p.name}\n$status: ${settings.formatAmount(balance.abs()).toPersianNumbers()}',
                TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  fontFamily: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.fontFamily,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: chartMaxVal / 3,
          getDrawingHorizontalLine: (value) {
            if (value.abs() < 0.01) {
              return FlLine(
                color: isDark ? Colors.grey[600]! : Colors.grey[400]!,
                strokeWidth: 1.5,
              );
            }
            return FlLine(
              color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
              strokeWidth: 0.5,
            );
          },
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(sorted.length, (i) {
          final balance = balances[sorted[i].id] ?? 0;
          final isPositive = balance > 0.01;
          final isNegative = balance < -0.01;
          final isZero = !isPositive && !isNegative;
          final isSelected = _stickyBarIndex == i;
          final tooltipIndicators = isSelected
              ? const <int>[0]
              : const <int>[];
          final displayY = isZero
              ? chartMaxVal * 0.2
              : balance;
          return BarChartGroupData(
            x: i,
            showingTooltipIndicators: tooltipIndicators,
            barRods: [
              BarChartRodData(
                toY: displayY,
                color: isPositive
                    ? (isSelected ? Colors.green.shade700 : Colors.green.shade400)
                    : isNegative
                        ? (isSelected ? Colors.red.shade700 : Colors.red.shade400)
                        : (isSelected
                            ? (isDark ? Colors.grey[600]! : Colors.grey[500]!)
                            : (isDark ? Colors.grey[800]! : Colors.grey[300]!)),
                width: 18,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(!isNegative ? 6 : 0),
                  topRight: Radius.circular(!isNegative ? 6 : 0),
                  bottomLeft: Radius.circular(isNegative ? 6 : 0),
                  bottomRight: Radius.circular(isNegative ? 6 : 0),
                ),
                backDrawRodData: BackgroundBarChartRodData(
                  show: isZero,
                  toY: -chartMaxVal * 0.2,
                  color: Colors.grey.withOpacity(0.06),
                ),
              ),
            ],
          );
        }),
      ),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );

    return Column(
      children: [
        SizedBox(
          height: barHeight,
          child: minChartWidth > 300
              ? ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                    },
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: minChartWidth,
                      child: chartWidget,
                    ),
                  ),
                )
              : chartWidget,
        ),
        const SizedBox(height: 16),
        // لیست نام افراد و مانده
        Column(
          children: List.generate(sorted.length, (i) {
            final p = sorted[i];
            final balance = balances[p.id] ?? 0;
            final isPositive = balance > 0.01;
            final isNegative = balance < -0.01;
            final color = isPositive
                ? Colors.green.shade400
                : isNegative
                    ? Colors.red.shade400
                    : (isDark ? Colors.grey[600]! : Colors.grey[400]!);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    p.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${settings.formatAmount(balance.abs()).toPersianNumbers()})',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  // نمودار وضعیت تسویه
  // ═══════════════════════════════════════════════════
  Widget _buildSettlementChart(
    BuildContext context,
    List settledDebts,
    List unsettledDebts,
    double settledAmount,
    double unsettledAmount,
    SettingsProvider settings,
    bool isDark,
  ) {
    final total = settledDebts.length + unsettledDebts.length;
    if (total == 0) return const SizedBox.shrink();

    final settledPct = (settledDebts.length / total * 100).toStringAsFixed(0);
    final unsettledPct = (unsettledDebts.length / total * 100).toStringAsFixed(0);

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              borderData: FlBorderData(show: false),
              sectionsSpace: 3,
              centerSpaceRadius: 40,
              sections: [
                if (settledDebts.length > 0)
                  PieChartSectionData(
                    color: Colors.green.shade400,
                    value: settledDebts.length.toDouble(),
                    title: '$settledPct٪'.toPersianNumbers(),
                    radius: 45,
                    titleStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [Shadow(blurRadius: 2, color: Colors.black26)],
                    ),
                  ),
                if (unsettledDebts.length > 0)
                  PieChartSectionData(
                    color: Colors.red.shade400,
                    value: unsettledDebts.length.toDouble(),
                    title: '$unsettledPct٪'.toPersianNumbers(),
                    radius: 45,
                    titleStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [Shadow(blurRadius: 2, color: Colors.black26)],
                    ),
                  ),
              ],
            ),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
          ),
        ),
        const SizedBox(height: 16),
        // Legend تسویه
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildSettlementLegendItem(
              context: context,
              color: Colors.green.shade400,
              label: 'تسویه‌شده',
              count: settledDebts.length,
              amount: settings.formatAmount(settledAmount).toPersianNumbers(),
              debts: settledDebts,
              settings: settings,
              isDark: isDark,
            ),
            _buildSettlementLegendItem(
              context: context,
              color: Colors.red.shade400,
              label: 'تسویه‌نشده',
              count: unsettledDebts.length,
              amount: settings.formatAmount(unsettledAmount).toPersianNumbers(),
              debts: unsettledDebts,
              settings: settings,
              isDark: isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSettlementLegendItem({
    required BuildContext context,
    required Color color,
    required String label,
    required int count,
    required String amount,
    required List debts,
    required SettingsProvider settings,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: debts.isEmpty
          ? null
          : () => _showSettlementDetailPopup(
                context, color, label, debts, settings, isDark),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$count مورد'.toPersianNumbers(),
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[400] : Colors.grey[500],
              ),
            ),
            Text(
              amount,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.grey[500] : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSettlementDate(DateTime dateTime) {
    final datePart =
        '${Jalali.fromDateTime(dateTime).formatJalaliCompact().toPersianNumbers()}';
    final timeStr =
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}'
            .toPersianNumbers();
    if (timeStr == '۰۰:۰۰') {
      return datePart;
    }
    return '$datePart ساعت $timeStr';
  }

  void _showSettlementDetailPopup(
    BuildContext context,
    Color color,
    String title,
    List debts,
    SettingsProvider settings,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.5,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.grey[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.list_alt, size: 13, color: isDark ? Colors.grey[400] : Colors.grey[500]),
                  const SizedBox(width: 3),
                  Text(
                    '${ debts.length} مورد'.toPersianNumbers(),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[500],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.account_balance_wallet_outlined, size: 13, color: isDark ? Colors.grey[400] : Colors.grey[500]),
                  const SizedBox(width: 3),
                  Text(
                    settings.formatAmount(debts.fold<double>(0, (sum, d) => sum + d.amount)).toPersianNumbers(),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[500],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: debts.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
                  ),
                  itemBuilder: (_, i) {
                    final d = debts[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Icon(
                            d.isSettled
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            size: 18,
                            color: d.isSettled ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        d.debtorName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.grey[200]
                                              : Colors.grey[800],
                                        ),
                                      ),
                                    ),
                                    Text(
                                      ' ← ',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[500],
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        d.creditorName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.grey[200]
                                              : Colors.grey[800],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (d.settlementDate != null)
                                  Text(
                                    _formatSettlementDate(d.settlementDate!),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.grey[500]
                                          : Colors.grey[400],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            settings
                                .formatAmount(d.amount)
                                .toPersianNumbers(),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _shareImage({
    required BuildContext context,
    required Uint8List pngBytes,
    required String fileName,
    required String shareText,
    required String shareSubject,
  }) async {
    if (kIsWeb) {
      _showSharePreviewSheet(context, pngBytes, fileName, shareText, shareSubject);
    } else {
      try {
        Share.downloadFallbackEnabled = false;
        await Share.shareXFiles(
          [XFile.fromData(pngBytes, mimeType: 'image/png', name: fileName)],
          text: shareText,
          subject: shareSubject,
          fileNameOverrides: [fileName],
        );
      } finally {
        Share.downloadFallbackEnabled = true;
      }
    }
  }

  void _showSharePreviewSheet(
    BuildContext context,
    Uint8List pngBytes,
    String fileName,
    String shareText,
    String shareSubject,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[600] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'اشتراک‌گذاری تصویر',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey[800],
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      pngBytes,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        Share.downloadFallbackEnabled = false;
                        await Share.shareXFiles(
                          [XFile.fromData(pngBytes, mimeType: 'image/png', name: fileName)],
                          text: shareText,
                          subject: shareSubject,
                          fileNameOverrides: [fileName],
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('خطا در اشتراک‌گذاری: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('اشتراک‌گذاری'),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
