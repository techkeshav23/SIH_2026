import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/api.dart';
import '../../data/models.dart';

final feedProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  return ref.read(apiProvider).buyerFeed();
});

/// Buyer-facing marketplace — simulated ONDC / GeM discovery of listed products.
class MarketScreen extends ConsumerWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('B2B Marketplace'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(24),
          child: Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Powered by ONDC · GeM ready',
                style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ),
        ),
      ),
      body: feed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Could not load marketplace')),
        data: (items) => items.isEmpty
            ? const Center(child: Text('No listed products yet.'))
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(feedProvider),
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _FeedCard(p: items[i], api: ref.read(apiProvider)),
                ),
              ),
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.p, required this.api});
  final Product p;
  final Api api;

  @override
  Widget build(BuildContext context) {
    final img = p.enhancedImageUrl ?? p.rawImageUrl;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openInquiry(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: img != null
                  ? Image.network(api.mediaUrl(img), width: double.infinity, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const _Ph())
                  : const _Ph(),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.titleEn ?? p.titleHi ?? 'Product',
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    p.finalPrice != null
                        ? '₹${p.finalPrice!.toStringAsFixed(0)}'
                        : (p.suggestedPriceMin != null
                            ? '₹${p.suggestedPriceMin!.toStringAsFixed(0)}+'
                            : ''),
                    style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openInquiry(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _InquirySheet(p: p, api: api),
    );
  }
}

class _Ph extends StatelessWidget {
  const _Ph();
  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.bg,
        child: const Center(child: Icon(Icons.image_outlined, color: AppColors.muted)),
      );
}

class _InquirySheet extends StatefulWidget {
  const _InquirySheet({required this.p, required this.api});
  final Product p;
  final Api api;
  @override
  State<_InquirySheet> createState() => _InquirySheetState();
}

class _InquirySheetState extends State<_InquirySheet> {
  final _org = TextEditingController();
  final _msg = TextEditingController(text: 'Interested in bulk order. Please share MOQ & rate.');
  bool _sending = false;

  Future<void> _send() async {
    if (_org.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.api.sendInquiry(widget.p.id, _org.text.trim(), _msg.text.trim());
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inquiry sent to artisan ✓')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Inquire — ${widget.p.titleEn ?? widget.p.titleHi ?? ''}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          TextField(
            controller: _org,
            decoration: const InputDecoration(
                labelText: 'Your organization / GSTIN', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _msg,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: const Icon(Icons.send),
            label: Text(_sending ? 'Sending…' : 'Send inquiry'),
          ),
        ],
      ),
    );
  }
}
