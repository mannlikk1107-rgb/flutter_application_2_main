// Path: lib/pages/student/top_up_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/user_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/api_service.dart';
import 'tasks_page.dart';

class TopUpPage extends StatefulWidget {
  const TopUpPage({super.key});

  @override
  State<TopUpPage> createState() => _TopUpPageState();
}

class _TopUpPageState extends State<TopUpPage>
    with SingleTickerProviderStateMixin {
  bool _isProcessing = false;
  List _history = [];
  bool _isLoadingHistory = true;
  bool _isTopUpExpanded = false;

  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  static const List<Map<String, dynamic>> _packages = [
    {'label': '100 ACoin', 'price': 'HK\$ 10', 'amount': 100.0, 'color': Color(0xFFFF9800)},
    {'label': '500 ACoin', 'price': 'HK\$ 45', 'amount': 500.0, 'color': Color(0xFF2196F3)},
    {'label': '1000 ACoin', 'price': 'HK\$ 80', 'amount': 1000.0, 'color': Color(0xFF9C27B0), 'bonus': '🎉 Best Value – Save 20%'},
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _expandController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _expandAnimation = CurvedAnimation(parent: _expandController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _toggleTopUp() {
    setState(() => _isTopUpExpanded = !_isTopUpExpanded);
    if (_isTopUpExpanded) {
      _expandController.forward();
    } else {
      _expandController.reverse();
    }
  }

  Future<void> _loadHistory() async {
    final user = Provider.of<UserProvider>(context, listen: false);
    if (user.mId.isNotEmpty) {
      final data = await ApiService.getACoinHistory(user.mId);
      if (mounted) {
        setState(() { _history = data; _isLoadingHistory = false; });
      }
    }
  }

  Future<void> _handlePurchase(String mId, double amountCoins, String priceLabel) async {
    if (_isProcessing) return;
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        // ✅ translated
        title: Text(lang.t('confirm_purchase')),
        content: Text(
          // ✅ inline format — keep variables working
          lang.locale.languageCode == 'zh'
            ? '確定以 $priceLabel 購買 ${amountCoins.toStringAsFixed(0)} ACoin？'
            : 'Purchase ${amountCoins.toStringAsFixed(0)} ACoin for $priceLabel?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            // ✅ translated
            child: Text(lang.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
            // ✅ translated
            child: Text(lang.t('confirm_payment')),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm || !mounted) return;

    setState(() => _isProcessing = true);
    bool success = await ApiService.buyACoin(mId, amountCoins);

    if (mounted) {
      setState(() => _isProcessing = false);
      if (success) {
        await Provider.of<UserProvider>(context, listen: false).refreshBalance();
        _loadHistory();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          // ✅ inline format
          content: Text(lang.locale.languageCode == 'zh'
            ? '✅ 成功充值 ${amountCoins.toStringAsFixed(0)} ACoin！'
            : '✅ Successfully topped up ${amountCoins.toStringAsFixed(0)} ACoin!'),
          backgroundColor: Colors.green,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          // ✅ translated
          content: Text(lang.t('topup_failed')),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    // ✅ get lang
    final lang = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        // ✅ translated
        title: Text(lang.t('acoin_center')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              await userProvider.refreshBalance();
              await _loadHistory();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Balance ──
                  Center(
                    child: Column(children: [
                      const SizedBox(height: 8),
                      Container(
                        width: 88, height: 88,
                        decoration: BoxDecoration(color: Colors.amber.withOpacity(0.12), shape: BoxShape.circle),
                        child: const Icon(Icons.monetization_on_rounded, size: 50, color: Colors.amber),
                      ),
                      const SizedBox(height: 10),
                      // ✅ translated
                      Text(lang.t('current_balance'), style: const TextStyle(fontSize: 14, color: Colors.grey)),
                      Text(userProvider.balance.toStringAsFixed(0),
                          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                      const Text("ACoin", style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ]),
                  ),
                  const SizedBox(height: 28),

                  // ── Top Up (collapsible) ──
                  _TappableCard(
                    onTap: _toggleTopUp,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Row(children: [
                            const Icon(Icons.add_circle_outline, color: Color(0xFF6366F1), size: 22),
                            const SizedBox(width: 10),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              // ✅ translated
                              Text(lang.t('top_up_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(lang.t('top_up_sub'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ]),
                          ]),
                          AnimatedRotation(
                            turns: _isTopUpExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 300),
                            child: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                          ),
                        ]),
                        SizeTransition(
                          sizeFactor: _expandAnimation,
                          child: Column(
                            children: [
                              const SizedBox(height: 16),
                              ..._packages.map((pkg) {
                                final color = pkg['color'] as Color;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: GestureDetector(
                                    onTap: () => _handlePurchase(userProvider.mId, pkg['amount'] as double, pkg['price'] as String),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.06),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: color.withOpacity(0.25)),
                                      ),
                                      child: Row(children: [
                                        Container(
                                          width: 42, height: 42,
                                          decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                                          child: Icon(Icons.monetization_on, color: color, size: 22),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                            Text(pkg['label'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                            if (pkg.containsKey('bonus'))
                                              Text(pkg['bonus'] as String, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                                          ]),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                                          child: Text(pkg['price'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                        ),
                                      ]),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Daily Tasks ──
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TasksPage())),
                    child: Container(
                      height: 72,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFDB2777)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                          child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                          // ✅ translated
                          Text(lang.t('daily_tasks'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(lang.t('earn_acoin_tasks'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ])),
                        const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Transaction History ──
                  // ✅ translated
                  Text(lang.t('transaction_history'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildTransactionHistory(lang),
                ],
              ),
            ),
          ),
          if (_isProcessing)
            Container(color: Colors.black.withOpacity(0.3), child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }

  Widget _buildTransactionHistory(LanguageProvider lang) {
    if (_isLoadingHistory) {
      return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
    }
    if (_history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          // ✅ translated
          child: Text(lang.t('no_transactions'), style: const TextStyle(color: Colors.grey)),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _history.length,
      itemBuilder: (ctx, i) {
        final item = _history[i];
        final val = double.tryParse(item['transValue'].toString()) ?? 0;
        final isIncome = val > 0;

        final String dateString = item['transDate'] ?? '';
        final DateTime dt = DateTime.tryParse(dateString) ?? DateTime.now();
        final hkTime = dt.add(const Duration(hours: 8));
        final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(hkTime);

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isIncome ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isIncome ? Colors.green : Colors.red, size: 20),
            ),
            title: Text(item['description'] ?? 'Transaction',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text(formattedDate, style: const TextStyle(fontSize: 12)),
            trailing: Text(
              "${isIncome ? '+' : ''}${val.toStringAsFixed(0)}",
              style: TextStyle(color: isIncome ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        );
      },
    );
  }
}

// ── Tappable Card ──
class _TappableCard extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _TappableCard({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: child,
      ),
    );
  }
}
