import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/models.dart';

/// B2B bulk-order negotiation inbox — role-aware. Buyer sees their requests,
/// artisan sees incoming ones; both can counter / accept / decline on their turn.
class QuotesScreen extends ConsumerStatefulWidget {
  const QuotesScreen({super.key});
  @override
  ConsumerState<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends ConsumerState<QuotesScreen> {
  List<Quote> _quotes = [];
  bool _loading = true;

  Api get _api => ref.read(apiProvider);
  String get _role => _api.isBuyer ? 'buyer' : 'artisan';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _quotes = _api.isBuyer ? await _api.myQuotes() : await _api.incomingQuotes();
    } catch (_) {
      _quotes = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _run(Future<Quote> Function() action) async {
    try {
      await action();
      await _load();
    } catch (_) {
      final lang = ref.read(langProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(T.of(context, lang, 'action_failed'))));
      }
    }
  }

  Future<void> _counter(Quote q) async {
    final lang = ref.read(langProvider);
    final ctrl = TextEditingController(text: q.currentPrice.toStringAsFixed(0));
    final price = await showDialog<double>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(T.of(c, lang, 'counter_offer')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: T.of(c, lang, 'your_counter'), prefixText: '₹ '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(T.of(c, lang, 'cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(c, double.tryParse(ctrl.text.trim())),
            child: Text(T.of(c, lang, 'send_request')),
          ),
        ],
      ),
    );
    if (price != null && price > 0) await _run(() => _api.counterQuote(q.id, price));
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    String t(String k) => T.of(context, lang, k);

    final body = _loading
        ? const Center(child: KLoading())
        : _quotes.isEmpty
            ? KEmpty(icon: Icons.gavel_rounded, title: t('no_quotes'))
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _quotes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _QuoteCard(
                    q: _quotes[i], role: _role, t: t,
                    onAccept: () => _run(() => _api.acceptQuote(_quotes[i].id)),
                    onDecline: () => _run(() => _api.declineQuote(_quotes[i].id)),
                    onCounter: () => _counter(_quotes[i]),
                  ),
                ),
              );

    // Artisan: a first-class bottom-nav tab (index 2). Buyer: a pushed screen.
    if (_api.isBuyer) {
      return Scaffold(appBar: AppBar(title: Text(t('quotes'))), body: body);
    }
    return AppScaffold(
      current: 3,
      body: Column(children: [
        KHeader(title: t('quotes'), leading: drawerButton()),
        Expanded(child: body),
      ]),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    required this.q, required this.role, required this.t,
    required this.onAccept, required this.onDecline, required this.onCounter,
  });
  final Quote q;
  final String role;
  final String Function(String) t;
  final VoidCallback onAccept, onDecline, onCounter;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final myTurn = q.isOpen && q.turn == role;
    // the price *I* would accept = the OTHER party's current offer
    final acceptPrice = role == 'buyer' ? q.artisanPrice : q.buyerPrice;

    return KCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          KNetImage(q.productImage, width: 46, height: 46),
          Gap.m,
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(q.productTitle ?? 'Product', maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleMedium),
              Text('${q.quantity} ${t('units')}', style: text.labelSmall),
            ]),
          ),
          _statusChip(context),
        ]),
        if ((q.message ?? '').isNotEmpty) ...[
          Gap.s,
          Text(q.message!, style: text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
        Gap.m,
        // offers on the table
        Row(children: [
          _offer(context, t('buyer_offer'), q.buyerPrice, q.turn == 'artisan' && q.isOpen),
          const SizedBox(width: 10),
          _offer(context, t('artisan_offer'), q.artisanPrice,
              q.turn == 'buyer' && q.isOpen && q.artisanPrice != null),
        ]),
        Gap.s,
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${t('list_price')}: ${q.listPrice == null ? '—' : rupees(q.listPrice!)}',
              style: text.labelSmall),
          Text('${t('est_total')}: ${rupees((q.isAccepted ? (q.agreedPrice ?? q.currentPrice) : q.currentPrice) * q.quantity)}',
              style: text.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
        ]),
        if (myTurn) ...[
          const Divider(height: 22),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onDecline,
                child: Text(t('reject'), style: const TextStyle(color: AppColors.danger)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(onPressed: onCounter, child: Text(t('counter_offer'))),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                // can only accept a concrete, positive offer from the other side
                onPressed: (acceptPrice == null || acceptPrice <= 0) ? null : onAccept,
                child: Text((acceptPrice == null || acceptPrice <= 0) ? t('accept') : '${t('accept')} ${rupees(acceptPrice)}',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _offer(BuildContext c, String label, double? price, bool active) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withValues(alpha: 0.07) : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(Radii.sm),
          border: Border.all(color: active ? AppColors.primary.withValues(alpha: 0.4) : AppColors.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(c).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(price == null ? '—' : '${rupees(price)}${t('per_unit')}',
              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.text)),
        ]),
      ),
    );
  }

  Widget _statusChip(BuildContext c) {
    late final String label;
    late final Color color;
    if (q.isAccepted) {
      label = t('deal_done');
      color = AppColors.success;
    } else if (q.isDeclined) {
      label = t('declined');
      color = AppColors.danger;
    } else if (q.turn == role) {
      label = t('your_turn');
      color = AppColors.primary;
    } else {
      label = t('awaiting_reply');
      color = AppColors.muted;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
