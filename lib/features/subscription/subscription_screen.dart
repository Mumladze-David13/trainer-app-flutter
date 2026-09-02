// lib/features/subscription/subscription_screen.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/models.dart';
import '../../core/services/auth_provider.dart';

enum _PaymentStage { idle, opening, polling, succeeded, failed, timedOut }

// YooKassa's hosted checkout page navigates the browser to our return_url once
// the user finishes. On mobile that's this same custom scheme the OAuth login
// flow already registers (see auth_provider.dart) — flutter_web_auth_2 detects
// the navigation and closes the in-app browser automatically. The real source
// of truth is still polling /subscription/payment/:id/status, since the
// backend confirms success via YooKassa's webhook, not via this redirect.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _loadingPrice = true;
  SubscriptionPrice? _price;
  String? _loadError;

  _PaymentStage _stage = _PaymentStage.idle;
  String? _payError;

  @override
  void initState() {
    super.initState();
    _loadPrice();
  }

  Future<void> _loadPrice() async {
    setState(() {
      _loadingPrice = true;
      _loadError = null;
    });
    final api = context.read<AuthProvider>().api;
    try {
      final price = await api.getSubscriptionPrice();
      if (mounted) setState(() => _price = price);
    } catch (_) {
      if (mounted) setState(() => _loadError = 'Не удалось загрузить цену подписки');
    } finally {
      if (mounted) setState(() => _loadingPrice = false);
    }
  }

  Future<void> _pay() async {
    final api = context.read<AuthProvider>().api;
    setState(() {
      _stage = _PaymentStage.opening;
      _payError = null;
    });

    try {
      final payment = await api.createSubscriptionPayment(kIsWeb ? 'web' : 'mobile');
      final uri = Uri.parse(payment.confirmationUrl);

      if (kIsWeb) {
        await launchUrl(uri, webOnlyWindowName: '_blank');
      } else {
        try {
          await FlutterWebAuth2.authenticate(
            url: payment.confirmationUrl,
            callbackUrlScheme: kOAuthCallbackUrlScheme,
          );
        } catch (_) {
          // Пользователь мог закрыть окно вручную после реальной оплаты
          // (до того, как ЮKassa успела редиректнуть) — не считаем это
          // ошибкой, ниже всё равно проверяем статус по paymentId.
        }
      }

      if (!mounted) return;
      setState(() => _stage = _PaymentStage.polling);
      await _pollStatus(payment.paymentId);
    } catch (_) {
      if (mounted) {
        setState(() {
          _stage = _PaymentStage.failed;
          _payError = 'Не удалось начать оплату. Попробуйте ещё раз.';
        });
      }
    }
  }

  Future<void> _pollStatus(String paymentId) async {
    final api = context.read<AuthProvider>().api;
    for (var attempt = 0; attempt < 30; attempt++) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      try {
        final status = await api.getSubscriptionPaymentStatus(paymentId);
        if (status == 'succeeded') {
          setState(() => _stage = _PaymentStage.succeeded);
          return;
        }
        if (status == 'failed' || status == 'canceled') {
          setState(() => _stage = _PaymentStage.failed);
          return;
        }
      } catch (_) {
        // Сетевой сбой при поллинге — пробуем ещё раз на следующей итерации.
      }
    }
    if (mounted) setState(() => _stage = _PaymentStage.timedOut);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Подписка')),
      body: SafeArea(
        child: _loadingPrice
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? _ErrorState(message: _loadError!, onRetry: _loadPrice)
                : _price == null
                    ? const SizedBox.shrink()
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _PriceCard(price: _price!),
                          const SizedBox(height: 20),
                          _buildAction(),
                        ],
                      ),
      ),
    );
  }

  Widget _buildAction() {
    switch (_stage) {
      case _PaymentStage.idle:
        return FilledButton(
          onPressed: _pay,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF8B0000),
            minimumSize: const Size.fromHeight(48),
          ),
          child: Text('Оплатить ${_price!.chargedRub} ₽'),
        );
      case _PaymentStage.opening:
        return const _StatusBlock(text: 'Открываем окно оплаты…');
      case _PaymentStage.polling:
        return const _StatusBlock(text: 'Проверяем статус оплаты…');
      case _PaymentStage.succeeded:
        return const _StatusBlock(
          icon: Icons.check_circle,
          color: Colors.green,
          text: 'Оплата прошла успешно',
        );
      case _PaymentStage.failed:
        return Column(
          children: [
            _StatusBlock(
              icon: Icons.error,
              color: Colors.red,
              text: _payError ?? 'Оплата не прошла',
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => setState(() => _stage = _PaymentStage.idle),
              child: const Text('Попробовать снова'),
            ),
          ],
        );
      case _PaymentStage.timedOut:
        return Column(
          children: [
            const _StatusBlock(
              icon: Icons.hourglass_top,
              color: Colors.orange,
              text: 'Платёж ещё обрабатывается. Если оплата прошла, '
                  'доступ откроется в течение пары минут.',
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => setState(() => _stage = _PaymentStage.idle),
              child: const Text('Понятно'),
            ),
          ],
        );
    }
  }
}

class _PriceCard extends StatelessWidget {
  final SubscriptionPrice price;
  const _PriceCard({required this.price});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.workspace_premium, color: Color(0xFF8B0000)),
              SizedBox(width: 8),
              Text('Ваш тариф', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 12),
            if (price.isFirstMonth) ...[
              Text(
                '${price.fullPriceRub} ₽/мес',
                style: TextStyle(
                  color: Colors.grey[600],
                  decoration: TextDecoration.lineThrough,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '${price.chargedRub} ₽',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '-50% первый месяц',
                      style: TextStyle(color: Colors.green[800], fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ] else
              Text(
                '${price.chargedRub} ₽/мес',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusBlock extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? color;
  const _StatusBlock({required this.text, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (icon != null)
          Icon(icon, color: color, size: 40)
        else
          const CircularProgressIndicator(),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Повторить')),
        ],
      ),
    );
  }
}
