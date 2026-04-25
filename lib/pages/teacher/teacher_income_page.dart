// 路徑: lib/pages/teacher/teacher_income_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';

class TeacherIncomePage extends StatefulWidget {
  final String mId;
  final String teacherName;
  const TeacherIncomePage({super.key, required this.mId, required this.teacherName});
  @override
  State<TeacherIncomePage> createState() => _TeacherIncomePageState();
}

class _TeacherIncomePageState extends State<TeacherIncomePage> {
  static const String _apiUrl =
      'http://3.25.85.107/Research/Web/TestFYP/api/get_teacher_income.php';

  // ── App-wide brand colours ──────────────────────────────────
  static const Color _primary   = Color(0xFF6366F1);
  static const Color _primary2  = Color(0xFF818CF8);
  static const Color _surface   = Colors.white;
  static const Color _bg        = Color(0xFFF4F7FE);
  static const Color _textDark  = Color(0xFF1E293B);

  String _selectedRange = 'month';
  bool   _isLoading     = false;

  List<dynamic> _chartData = [];
  List<dynamic> _breakdown = [];
  List<dynamic> _recentTx  = [];
  double _totalIncome = 0;
  int    _totalTx     = 0;

  // ── Per-category colour / icon / emoji ─────────────────────
  Color _colorFor(String attId) {
    switch (attId) {
      case 'attG01': return const Color(0xFFFFC107);
      case 'attG02': return const Color(0xFFE91E63);
      case 'attG03': return const Color(0xFF9C27B0);
      case 'attG04': return const Color(0xFF2196F3);
      case 'att004': return const Color(0xFF22C55E);
      case 'att003': return const Color(0xFF06B6D4);
      case 'att001': return const Color(0xFFF59E0B);
      case 'att002': return const Color(0xFF8BC34A);
      case 'att005': return _primary;
      default:       return Colors.grey;
    }
  }

  String _emojiFor(String attId) {
    switch (attId) {
      case 'attG01': return '⭐';
      case 'attG02': return '❤️';
      case 'attG03': return '👑';
      case 'attG04': return '💎';
      case 'att004': return '📚';
      case 'att003': return '💰';
      case 'att001': return '🎉';
      case 'att002': return '📅';
      case 'att005': return '🎮';
      default:       return '💵';
    }
  }

  @override
  void initState() { super.initState(); _fetchIncome(); }

  Future<void> _fetchIncome() async {
    setState(() => _isLoading = true);
    try {
      final response = await http
          .post(Uri.parse(_apiUrl), body: {'mId': widget.mId, 'range': _selectedRange})
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _chartData   = data['chartData'] ?? [];
            _breakdown   = data['breakdown'] ?? [];
            _recentTx    = data['recentTx']  ?? [];
            _totalIncome = (data['summary']['totalIncome'] as num).toDouble();
            _totalTx     = data['summary']['totalTx'] as int;
          });
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Shared card decoration ─────────────────────────────────
  BoxDecoration _card({Color? shadow}) => BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (shadow ?? Colors.black).withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final rangeLabels = {
      'week':  lang.isEnglish ? 'This Week'  : '本週',
      'month': lang.isEnglish ? 'This Month' : '本月',
      'year':  lang.isEnglish ? 'This Year'  : '今年',
    };

    return Scaffold(
      backgroundColor: _bg,
      // ── Gradient AppBar matching the rest of the app ───────
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_primary, _primary2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          "${widget.teacherName} · ${lang.t('income_report')}",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchIncome,
        color: _primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildRangeSelector(rangeLabels),
            const SizedBox(height: 20),
            _buildSummaryCards(lang),
            const SizedBox(height: 20),
            _buildBarChart(lang),
            const SizedBox(height: 20),
            _buildBreakdown(lang),
            const SizedBox(height: 20),
            _buildRecentTransactions(lang),
          ]),
        ),
      ),
    );
  }

  // ── Range selector ─────────────────────────────────────────
  Widget _buildRangeSelector(Map<String, String> labels) {
    return Container(
      decoration: _card(),
      padding: const EdgeInsets.all(5),
      child: Row(
        children: labels.entries.map((e) {
          final selected = _selectedRange == e.key;
          return Expanded(
            child: GestureDetector(
              onTap: () { setState(() => _selectedRange = e.key); _fetchIncome(); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(colors: [_primary, _primary2],
                          begin: Alignment.topLeft, end: Alignment.bottomRight)
                      : null,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  e.value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.grey[500],
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Summary cards ──────────────────────────────────────────
  Widget _buildSummaryCards(LanguageProvider lang) {
    return Row(children: [
      Expanded(child: _summaryCard(
        gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        icon: Icons.monetization_on_rounded,
        label: lang.t('total_income'),
        value: '${_totalIncome.toStringAsFixed(0)} ACoin',
      )),
      const SizedBox(width: 16),
      Expanded(child: _summaryCard(
        gradient: const LinearGradient(colors: [_primary, _primary2],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        icon: Icons.receipt_long_rounded,
        label: lang.isEnglish ? 'Transactions' : '交易次數',
        value: '$_totalTx ${lang.t('records')}',
      )),
    ]);
  }

  Widget _summaryCard({
    required LinearGradient gradient,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(height: 14),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ]),
    );
  }

  // ── Bar chart ──────────────────────────────────────────────
  Widget _buildBarChart(LanguageProvider lang) {
    if (_isLoading) {
      return Container(
        height: 220,
        decoration: _card(),
        child: const Center(child: CircularProgressIndicator(color: _primary)),
      );
    }
    if (_chartData.isEmpty) return _emptyCard(lang.t('no_income_data'));

    final double maxVal = _chartData
        .map((e) => (e['income'] as num).toDouble())
        .fold(0.0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _card(shadow: _primary),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: _primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.bar_chart_rounded, color: _primary, size: 20),
          ),
          const SizedBox(width: 10),
          Text(lang.t('income_trend'),
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: _textDark)),
        ]),
        const SizedBox(height: 20),
        SizedBox(
          height: 180,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _chartData.map((item) {
              final val   = (item['income'] as num).toDouble();
              final ratio = maxVal > 0 ? val / maxVal : 0.0;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    if (val > 0)
                      Text(val.toStringAsFixed(0),
                          style: const TextStyle(
                              fontSize: 9, color: _primary, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      height: 140 * ratio,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_primary2, _primary],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(item['label'] ?? '',
                        style: TextStyle(fontSize: 9, color: Colors.grey[400]),
                        overflow: TextOverflow.ellipsis),
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }

  // ── Breakdown ──────────────────────────────────────────────
  Widget _buildBreakdown(LanguageProvider lang) {
    if (_breakdown.isEmpty) return const SizedBox.shrink();
    final double grandTotal = _breakdown
        .map((e) => (e['total'] as num).toDouble())
        .fold(0.0, (a, b) => a + b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: _primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.pie_chart_rounded, color: _primary, size: 20),
          ),
          const SizedBox(width: 10),
          Text(lang.t('income_breakdown'),
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: _textDark)),
        ]),
        const SizedBox(height: 16),
        ..._breakdown.map((item) {
          final attId    = item['attId']    as String? ?? '';
          final category = item['category'] as String? ?? '';
          final total    = (item['total'] as num).toDouble();
          final cnt      = item['cnt']      as int?    ?? 0;
          final ratio    = grandTotal > 0 ? total / grandTotal : 0.0;
          final color    = _colorFor(attId);
          final emoji    = _emojiFor(attId);

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(child: Text(category,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    overflow: TextOverflow.ellipsis)),
                Text('$cnt ${lang.t('records')}',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                const SizedBox(width: 8),
                Text('+${total.toStringAsFixed(0)}',
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.bold, fontSize: 14)),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio,
                  backgroundColor: color.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 4),
              Text('${(ratio * 100).toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 11, color: Colors.grey[400])),
            ]),
          );
        }),
      ]),
    );
  }

  // ── Recent transactions ────────────────────────────────────
  Widget _buildRecentTransactions(LanguageProvider lang) {
    if (_recentTx.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: _primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.history_rounded, color: _primary, size: 20),
          ),
          const SizedBox(width: 10),
          Text(lang.t('recent_transactions'),
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: _textDark)),
        ]),
        const SizedBox(height: 16),
        ..._recentTx.map((item) {
          final attId    = item['attId']       as String? ?? '';
          final category = item['category']    as String? ?? '';
          final val      = (item['transValue'] as num).toDouble();
          final balance  = (item['totalAmont'] as num).toDouble();
          final dateStr  = item['transDate']   as String? ?? '';
          final color    = _colorFor(attId);
          final emoji    = _emojiFor(attId);

          String formattedDate = dateStr;
          try {
            final dt = DateTime.parse(dateStr).toLocal();
            formattedDate =
                '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
          } catch (_) {}

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.15)),
            ),
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                    color: color.withOpacity(0.12), shape: BoxShape.circle),
                child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(category,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(formattedDate,
                    style: TextStyle(color: Colors.grey[400], fontSize: 11)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('+${val.toStringAsFixed(0)}',
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.bold, fontSize: 16)),
                Text(
                  lang.isEnglish
                      ? 'Bal: ${balance.toStringAsFixed(0)}'
                      : '餘額: ${balance.toStringAsFixed(0)}',
                  style: TextStyle(color: Colors.grey[400], fontSize: 10),
                ),
              ]),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _emptyCard(String msg) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: _card(),
      child: Center(
        child: Column(children: [
          Icon(Icons.inbox_rounded, size: 52, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(msg, style: TextStyle(color: Colors.grey[400], fontSize: 14)),
        ]),
      ),
    );
  }
}