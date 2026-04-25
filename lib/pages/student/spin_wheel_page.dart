// 路徑: lib/pages/student/spin_wheel_page.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/language_provider.dart';
import '../../config/database.dart';

class SpinWheelPage extends StatefulWidget {
  const SpinWheelPage({super.key});
  @override
  State<SpinWheelPage> createState() => _SpinWheelPageState();
}

class _SpinWheelPageState extends State<SpinWheelPage> with SingleTickerProviderStateMixin {
  static const String _apiUrl = '${DatabaseConfig.baseUrl}${DatabaseConfig.projectPath}/api/spin_wheel.php';

  late AnimationController _controller;
  Animation<double>? _animation;

  bool _isSpinning = false;
  bool _hasSpunToday = false;
  bool _isCheckingStatus = true;
  double _currentRotation = 0;

  static const List<_Segment> _segments = [
    _Segment(coins: 5,  label: '5',  color: Color(0xFF64B5F6)),
    _Segment(coins: 10, label: '10', color: Color(0xFF66BB6A)),
    _Segment(coins: 5,  label: '5',  color: Color(0xFF64B5F6)),
    _Segment(coins: 20, label: '20', color: Color(0xFFFFB74D)),
    _Segment(coins: 5,  label: '5',  color: Color(0xFF64B5F6)),
    _Segment(coins: 10, label: '10', color: Color(0xFF66BB6A)),
    _Segment(coins: 5,  label: '5',  color: Color(0xFF64B5F6)),
    _Segment(coins: 25, label: '25', color: Color(0xFFEF5350)),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 5));
    _checkStatus();
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  Future<void> _checkStatus() async {
    final user = Provider.of<UserProvider>(context, listen: false);
    try {
      final resp = await http.post(Uri.parse(_apiUrl), body: {'action': 'check', 'mId': user.mId});
      final data = jsonDecode(resp.body);
      if (mounted) setState(() { _hasSpunToday = data['hasSpunToday'] == true; _isCheckingStatus = false; });
    } catch (_) {
      if (mounted) setState(() => _isCheckingStatus = false);
    }
  }

  double _getTargetRotation(int coins) {
    final indices = <int>[];
    for (int i = 0; i < _segments.length; i++) {
      if (_segments[i].coins == coins) indices.add(i);
    }
    final targetIndex  = indices[Random().nextInt(indices.length)];
    final segmentCenter = targetIndex * 45.0 + 22.5;
    final toTop        = (360.0 - segmentCenter) % 360.0;
    return _currentRotation + 5 * 360.0 + toTop;
  }

  Future<void> _spin() async {
    if (_isSpinning || _hasSpunToday) return;
    final user = Provider.of<UserProvider>(context, listen: false);
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    setState(() => _isSpinning = true);
    try {
      final resp = await http.post(Uri.parse(_apiUrl), body: {'action': 'spin', 'mId': user.mId});
      final data = jsonDecode(resp.body);
      if (data['success'] == true) {
        final int    coins  = data['coins'];
        final double target = _getTargetRotation(coins);
        _animation = Tween<double>(begin: _currentRotation, end: target)
            .animate(CurvedAnimation(parent: _controller, curve: Curves.decelerate));
        _controller.reset();
        _controller.forward().then((_) {
          if (mounted) {
            setState(() { _currentRotation = target % 360; _isSpinning = false; _hasSpunToday = true; });
            user.refreshBalance();
            _showWinDialog(coins);
          }
        });
      } else {
        if (mounted) {
          setState(() { _isSpinning = false; if (data['hasSpunToday'] == true) _hasSpunToday = true; });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(data['message'] ?? lang.t('already_spun_today')), backgroundColor: Colors.orange));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSpinning = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(Provider.of<LanguageProvider>(context, listen: false).t('network_error')), backgroundColor: Colors.red));
      }
    }
  }

  void _showWinDialog(int coins) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.celebration_rounded, color: Colors.amber, size: 64),
            const SizedBox(height: 12),
            Text(lang.t('congrats'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
              child: Text('+$coins ACoin', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
            ),
            const SizedBox(height: 8),
            Text(lang.t('added_to_account'), style: const TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text(lang.t('great'), style: const TextStyle(fontSize: 16)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(title: Text(lang.t('lucky_wheel')), backgroundColor: Colors.transparent, elevation: 0),
      body: _isCheckingStatus
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                // Prize info
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))]),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _buildPrizeInfo('5 A',    '50%',   const Color(0xFF64B5F6)),
                    _buildPrizeInfo('10 A',   '25%',   const Color(0xFF66BB6A)),
                    _buildPrizeInfo('20 A',   '12.5%', const Color(0xFFFFB74D)),
                    _buildPrizeInfo('25 A ⭐', '12.5%', const Color(0xFFEF5350)),
                  ]),
                ),
                const SizedBox(height: 32),

                const Icon(Icons.arrow_drop_down, color: Colors.red, size: 52),
                const SizedBox(height: 2),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final rotation = (_isSpinning && _animation != null) ? _animation!.value : _currentRotation;
                    return Transform.rotate(angle: rotation * pi / 180, child: child);
                  },
                  child: Container(
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8))]),
                    child: CustomPaint(size: const Size(290, 290), painter: _WheelPainter(segments: _segments)),
                  ),
                ),
                const SizedBox(height: 32),

                if (_hasSpunToday)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.08), borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.orange.withOpacity(0.3))),
                    child: Column(children: [
                      const Icon(Icons.access_time, color: Colors.orange, size: 32),
                      const SizedBox(height: 8),
                      Text(lang.t('already_spun_today'),
                          style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(lang.t('come_back_tomorrow'), style: const TextStyle(color: Colors.orange, fontSize: 13)),
                    ]),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSpinning ? null : _spin,
                      icon: _isSpinning
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.casino_rounded, size: 22),
                      label: Text(_isSpinning ? lang.t('spinning') : lang.t('spin_now'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF6366F1).withOpacity(0.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  '${lang.t('daily_limit')}，${lang.t('today')}${_hasSpunToday ? lang.t('spun_today') : lang.t('not_spun_today')}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ]),
            ),
    );
  }

  Widget _buildPrizeInfo(String label, String prob, Color color) {
    return Column(children: [
      Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(height: 5),
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      Text(prob, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
    ]);
  }
}

class _Segment {
  final int coins; final String label; final Color color;
  const _Segment({required this.coins, required this.label, required this.color});
}

class _WheelPainter extends CustomPainter {
  final List<_Segment> segments;
  _WheelPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final center   = Offset(size.width / 2, size.height / 2);
    final radius   = size.width / 2;
    final segAngle = 2 * pi / segments.length;

    for (int i = 0; i < segments.length; i++) {
      final start = -pi / 2 + i * segAngle;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, segAngle, true, Paint()..color = segments[i].color);
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, segAngle, true,
          Paint()..color = Colors.white..strokeWidth = 2.5..style = PaintingStyle.stroke);

      final midAngle = start + segAngle / 2;
      final textR    = radius * 0.60;
      canvas.save();
      canvas.translate(center.dx + textR * cos(midAngle), center.dy + textR * sin(midAngle));
      canvas.rotate(midAngle + pi / 2);
      final tp = TextPainter(
        text: TextSpan(text: segments[i].label, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        textAlign: TextAlign.center, textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2 - 4));
      final subTp = TextPainter(
        text: const TextSpan(text: 'ACoin', style: TextStyle(color: Colors.white70, fontSize: 8)),
        textDirection: TextDirection.ltr,
      )..layout();
      subTp.paint(canvas, Offset(-subTp.width / 2, tp.height / 2 - 6));
      canvas.restore();
    }
    canvas.drawCircle(center, radius, Paint()..color = Colors.white.withOpacity(0.25)..strokeWidth = 4..style = PaintingStyle.stroke);
    canvas.drawCircle(center, 24, Paint()..color = Colors.white);
    canvas.drawCircle(center, 24, Paint()..color = Colors.grey.shade200..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawCircle(center, 14, Paint()..color = Colors.amber);
    canvas.drawPath(_buildStarPath(center, 9, 4.5, 5), Paint()..color = Colors.white);
  }

  Path _buildStarPath(Offset center, double outer, double inner, int points) {
    final path = Path();
    final step = pi / points;
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? outer : inner;
      final a = -pi / 2 + i * step;
      final x = center.dx + r * cos(a);
      final y = center.dy + r * sin(a);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
