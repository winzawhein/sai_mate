import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../data/subscription_repository.dart';
import 'press_feedback.dart';

const _lime = Color(0xFFA5EF55);
String _money(dynamic value) => '${NumberFormat('#,##0').format(value)} Ks';
String _date(dynamic value) =>
    DateFormat('dd MMM yyyy').format(DateTime.parse(value as String).toLocal());
String _error(Object e) {
  if (e is FormatException) return e.message;
  if (e is PostgrestException) {
    if (e.code == '23505') {
      return 'ဤငွေလွှဲနံပါတ်ကို တင်ပြီးပါပြီ။ မှတ်တမ်းကို စစ်ဆေးပါ။';
    }
    if (e.code == 'P0001') return e.message;
  }
  return 'မအောင်မြင်ပါ။ အင်တာနက်ချိတ်ဆက်မှု စစ်ပြီး ပြန်ကြိုးစားပါ။';
}

void _notice(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
Widget _panel(BuildContext context, Widget child, {Color? color}) => Padding(
  padding: const EdgeInsets.only(bottom: 16),
  child: Material(
    color: color ?? Theme.of(context).colorScheme.surfaceContainerHigh,
    borderRadius: BorderRadius.circular(20),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: SizedBox(width: double.infinity, child: child),
    ),
  ),
);

class SubscriptionPage extends ConsumerWidget {
  const SubscriptionPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(subscriptionOverviewProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: withLightImpact(
              () => ref.invalidate(subscriptionOverviewProvider),
            ),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Subscription ကို မဖွင့်နိုင်ပါ။ ဝန်ဆောင်မှု ပြင်ဆင်ပြီးကြောင်းနှင့် အင်တာနက်ချိတ်ဆက်မှု စစ်ဆေးပါ။',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: withLightImpact(
                    () => ref.invalidate(subscriptionOverviewProvider),
                  ),
                  child: const Text('ပြန်ကြိုးစားမည်'),
                ),
              ],
            ),
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(subscriptionOverviewProvider);
            await ref.read(subscriptionOverviewProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _panel(
                context,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.workspace_premium_rounded,
                          color: Colors.black,
                          size: 30,
                        ),
                        const Spacer(),
                        Chip(
                          label: Text(
                            data.active
                                ? 'ACTIVE'
                                : data.subscription == null
                                ? 'NO SUBSCRIPTION'
                                : 'EXPIRED',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      data.subscription?['plan_name'] as String? ??
                          'ဆိုင်အတွက် အစီအစဉ်ရွေးပါ',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data.subscription == null
                          ? 'ငွေပေးချေမှု အတည်ပြုပြီးမှ စတင်ပါမည်။'
                          : 'သက်တမ်းကုန်ရက် · ${_date(data.subscription!['expires_at'])}',
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ],
                ),
                color: _lime,
              ),
              if (data.pending)
                _panel(
                  context,
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.hourglass_top_rounded),
                    title: Text('စစ်ဆေးနေပါသည်'),
                    subtitle: Text(
                      'ငွေလွှဲပြေစာ ပို့ပြီးပါပြီ။ ထပ်မံငွေလွှဲရန် မလိုပါ။ Refresh နှိပ်ပြီး အခြေအနေကြည့်နိုင်ပါသည်။',
                    ),
                  ),
                ),
              if (!data.owner)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text('ဆိုင်ပိုင်ရှင်သာ subscription ဝယ်ယူနိုင်ပါသည်။'),
                ),
              if (data.reviewer)
                _panel(
                  context,
                  Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.fact_check_outlined),
                        title: const Text('Payment review'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: withLightImpact(
                          () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const BillingReviewPage(),
                            ),
                          ),
                        ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.tune),
                        title: const Text('Plans & payment accounts'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: withLightImpact(
                          () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const BillingConfigPage(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const Text(
                'အစီအစဉ်များ',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              if (data.plans.isEmpty || data.methods.isEmpty)
                _panel(
                  context,
                  const Text(
                    'အစီအစဉ်နှင့် ငွေလက်ခံအကောင့်များ ပြင်ဆင်နေပါသည်။ ငွေလွှဲခြင်း မပြုသေးပါနှင့်။',
                  ),
                ),
              for (final plan in data.plans)
                _panel(
                  context,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan['name'] as String,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('${plan['duration_days']} ရက်'),
                      const SizedBox(height: 12),
                      Text(
                        _money(plan['price']),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if ((plan['description'] as String).isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(plan['description'] as String),
                        ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed:
                              !data.owner ||
                                  data.pending ||
                                  data.methods.isEmpty
                              ? null
                              : withLightImpact(() async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => SubscriptionCheckout(
                                        data: data,
                                        plan: plan,
                                      ),
                                    ),
                                  );
                                  ref.invalidate(subscriptionOverviewProvider);
                                }),
                          child: Text(
                            data.active ? 'သက်တမ်းတိုးမည်' : 'ရွေးချယ်မည်',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'ငွေပေးချေမှု မှတ်တမ်း',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: withLightImpact(
                      () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              BillingHistoryPage(shopId: data.shopId),
                        ),
                      ),
                    ),
                    child: const Text('အားလုံး'),
                  ),
                ],
              ),
              if (data.payments.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('ငွေပေးချေမှု မရှိသေးပါ။'),
                ),
              for (final payment in data.payments.take(5))
                PaymentCard(payment: payment),
            ],
          ),
        ),
      ),
    );
  }
}

class PaymentCard extends StatelessWidget {
  const PaymentCard({super.key, required this.payment, this.onTap});
  final BillingRow payment;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => _panel(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: withLightImpact(onTap),
          title: Text(
            payment['plan_name'] as String,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '${_date(payment['created_at'])} · ${payment['method_name']}',
          ),
          trailing: Text(_money(payment['amount'])),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            Chip(
              label: Text(switch (payment['status']) {
                'approved' => 'အတည်ပြုပြီး',
                'rejected' => 'ပယ်ချထားသည်',
                _ => 'စစ်ဆေးနေပါသည်',
              }),
            ),
            Text('Ref: ${payment['transaction_reference']}'),
          ],
        ),
        if (payment['review_note'] != null)
          Text(payment['review_note'] as String),
        if (payment['status'] == 'rejected')
          const Text('ပြေစာနှင့် အချက်အလက်စစ်ပြီး အသစ်ပြန်တင်နိုင်ပါသည်။'),
        if (onTap != null) const Text('စစ်ဆေးရန် နှိပ်ပါ →'),
      ],
    ),
  );
}

class SubscriptionCheckout extends ConsumerStatefulWidget {
  const SubscriptionCheckout({
    super.key,
    required this.data,
    required this.plan,
  });
  final SubscriptionOverview data;
  final BillingRow plan;
  @override
  ConsumerState<SubscriptionCheckout> createState() =>
      _SubscriptionCheckoutState();
}

class _SubscriptionCheckoutState extends ConsumerState<SubscriptionCheckout> {
  final _form = GlobalKey<FormState>();
  final _reference = TextEditingController();
  final _id = const Uuid().v4();
  late BillingRow _method = widget.data.methods.first;
  Uint8List? _bytes;
  String? _path, _failure;
  DateTime _paidAt = DateTime.now();
  bool _busy = false, _attempted = false;
  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2000,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      slipExtension(bytes);
      if (mounted) {
        setState(() {
          _bytes = bytes;
          _failure = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _failure = _error(e));
    }
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (_bytes == null) {
      setState(() => _failure = 'ငွေလွှဲပြေစာ ထည့်ပါ။');
      return;
    }
    setState(() {
      _busy = true;
      _attempted = true;
      _failure = null;
    });
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      _path ??= await repo.upload(_id, _bytes!);
      await repo.submit(
        id: _id,
        shopId: widget.data.shopId,
        plan: widget.plan,
        method: _method,
        reference: _reference.text,
        paidAt: _paidAt,
        path: _path!,
      );
      ref.invalidate(subscriptionOverviewProvider);
      if (mounted) {
        _notice(context, 'ပြေစာ ပို့ပြီးပါပြီ။ စစ်ဆေးအတည်ပြုမှုကို စောင့်ပါ။');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _failure =
              '${_error(e)} ထပ်မံငွေမလွှဲပါနှင့်။ မူလပြေစာဖြင့် ပြန်ပို့နိုင်ပါသည်။',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('ငွေပေးချေမည်')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            _panel(
              context,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '1  အစီအစဉ်',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.plan['name'] as String,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${widget.plan['duration_days']} ရက် · ${_money(widget.plan['price'])}',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'အလိုအလျောက် ငွေဖြတ်ခြင်းမရှိပါ။ အတည်ပြုပြီးမှ သက်တမ်းစတင်ပါမည်။',
                  ),
                ],
              ),
            ),
            _panel(
              context,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '2  ငွေလွှဲရန် အကောင့်',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _method['id'] as String,
                    isExpanded: true,
                    items: widget.data.methods
                        .map(
                          (m) => DropdownMenuItem(
                            value: m['id'] as String,
                            child: Text(m['name'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: _attempted
                        ? null
                        : withSelectionImpact(
                            (String? id) => setState(
                              () => _method = widget.data.methods.firstWhere(
                                (m) => m['id'] == id,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _method['account_name'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          _method['account_number'] as String,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy account number',
                        onPressed: withLightImpact(() {
                          Clipboard.setData(
                            ClipboardData(
                              text: _method['account_number'] as String,
                            ),
                          );
                          _notice(context, 'ကူးယူပြီးပါပြီ');
                        }),
                        icon: const Icon(Icons.copy),
                      ),
                    ],
                  ),
                  Text(_method['instructions'] as String),
                  const SizedBox(height: 8),
                  Text('ငွေလွှဲပမာဏ · ${_money(widget.plan['price'])}'),
                ],
              ),
            ),
            _panel(
              context,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '3  ငွေလွှဲပြေစာ ပို့မည်',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _reference,
                    enabled: !_attempted,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      labelText: 'Transaction ID / ငွေလွှဲနံပါတ်',
                    ),
                    validator: (v) => (v?.trim().length ?? 0) < 4
                        ? 'ငွေလွှဲနံပါတ် အနည်းဆုံး 4 လုံး ထည့်ပါ'
                        : null,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_month),
                    title: const Text('ငွေလွှဲသည့်ရက်'),
                    subtitle: Text(DateFormat('dd MMM yyyy').format(_paidAt)),
                    onTap: _attempted
                        ? null
                        : withLightImpact(() async {
                            final now = DateTime.now();
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _paidAt,
                              firstDate: now.subtract(const Duration(days: 89)),
                              lastDate: now,
                            );
                            if (date != null && mounted) {
                              setState(() => _paidAt = date);
                            }
                          }),
                  ),
                  if (_bytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.memory(
                        _bytes!,
                        height: 240,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) =>
                            const Text('ပုံကို ဖွင့်မရပါ။ အခြားပုံ ရွေးပါ။'),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _attempted
                            ? null
                            : withLightImpact(() => _pick(ImageSource.gallery)),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Gallery'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _attempted
                            ? null
                            : withLightImpact(() => _pick(ImageSource.camera)),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Camera'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'JPG / PNG · 5 MB အထိ။ ပမာဏ၊ ရက်စွဲနှင့် ငွေလွှဲနံပါတ် ထင်ရှားသော ပြေစာတင်ပါ။',
                  ),
                ],
              ),
            ),
            if (_failure != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _failure!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton.icon(
              onPressed: _busy ? null : withLightImpact(_submit),
              icon: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(
                _busy
                    ? 'ပို့နေပါသည်…'
                    : _attempted
                    ? 'မူလပြေစာ ပြန်ပို့မည်'
                    : 'စစ်ဆေးရန် ပို့မည်',
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
  );
}

class BillingHistoryPage extends ConsumerStatefulWidget {
  const BillingHistoryPage({
    super.key,
    required this.shopId,
    this.review = false,
  });
  final String shopId;
  final bool review;
  @override
  ConsumerState<BillingHistoryPage> createState() => _BillingHistoryPageState();
}

class BillingReviewPage extends StatelessWidget {
  const BillingReviewPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const BillingHistoryPage(shopId: '', review: true);
}

class _BillingHistoryPageState extends ConsumerState<BillingHistoryPage> {
  final List<BillingRow> _rows = [];
  bool _busy = false, _more = true;
  String? _failure;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failure = null;
      if (reset) {
        _rows.clear();
        _more = true;
      }
    });
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      final rows = widget.review
          ? await repo.queue(_rows.length)
          : await repo.history(widget.shopId, _rows.length);
      if (mounted) {
        setState(() {
          _rows.addAll(rows);
          _more = rows.length == 20;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _failure = _error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.review ? 'Payment review' : 'ငွေပေးချေမှု မှတ်တမ်း'),
      actions: [
        IconButton(
          onPressed: _busy ? null : withLightImpact(() => _load(reset: true)),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (widget.review)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'ငွေလက်ခံအကောင့်တွင် အမှန်တကယ် ဝင်ရောက်သော ပမာဏနှင့် ငွေလွှဲနံပါတ်ကို ပြေစာနှင့် တိုက်စစ်ပြီးမှ အတည်ပြုပါ။',
              ),
            ),
          if (_rows.isEmpty && !_busy && _failure == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('မှတ်တမ်း မရှိပါ။', textAlign: TextAlign.center),
            ),
          for (final p in _rows)
            PaymentCard(
              payment: p,
              onTap: widget.review
                  ? () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => PaymentReviewDetail(payment: p),
                        ),
                      );
                      if (mounted) _load(reset: true);
                    }
                  : null,
            ),
          if (_failure != null) Text(_failure!),
          if (_busy)
            const Center(child: CircularProgressIndicator())
          else if (_more || _failure != null)
            OutlinedButton(
              onPressed: withLightImpact(() => _load()),
              child: Text(_failure == null ? 'ထပ်ကြည့်မည်' : 'ပြန်ကြိုးစားမည်'),
            ),
        ],
      ),
    ),
  );
}

class PaymentReviewDetail extends ConsumerStatefulWidget {
  const PaymentReviewDetail({super.key, required this.payment});
  final BillingRow payment;
  @override
  ConsumerState<PaymentReviewDetail> createState() =>
      _PaymentReviewDetailState();
}

class _PaymentReviewDetailState extends ConsumerState<PaymentReviewDetail> {
  final _note = TextEditingController();
  late Future<Uint8List> _image = ref
      .read(subscriptionRepositoryProvider)
      .slip(widget.payment['slip_path'] as String);
  bool _busy = false;
  String? _failure;
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _review(bool approve) async {
    if (!approve && _note.text.trim().isEmpty) {
      setState(() => _failure = 'ပယ်ချရသည့် အကြောင်းရင်း ထည့်ပါ။');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(approve ? 'အတည်ပြုမည်လား' : 'ပယ်ချမည်လား'),
        content: Text(
          approve
              ? 'ငွေဝင်ကြောင်း စစ်ပြီးပါက subscription ကို ${widget.payment['duration_days']} ရက် သက်တမ်းတိုးပါမည်။'
              : 'အကြောင်းရင်းကို ဆိုင်ပိုင်ရှင် မြင်နိုင်ပါမည်။',
        ),
        actions: [
          TextButton(
            onPressed: withLightImpact(() => Navigator.pop(c, false)),
            child: const Text('မလုပ်သေးပါ'),
          ),
          FilledButton(
            onPressed: withLightImpact(() => Navigator.pop(c, true)),
            child: const Text('ဆက်လုပ်မည်'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await ref
          .read(subscriptionRepositoryProvider)
          .review(widget.payment['id'] as String, approve, _note.text.trim());
      ref.invalidate(subscriptionOverviewProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(
          () => _failure = '${_error(e)} Refresh ဖြင့် လက်ရှိအခြေအနေကို စစ်ပါ။',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Review payment')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          PaymentCard(payment: widget.payment),
          _panel(
            context,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Account: ${widget.payment['account_name']}'),
                SelectableText(widget.payment['account_number'] as String),
                Text('Paid: ${_date(widget.payment['paid_at'])}'),
                SelectableText('Shop: ${widget.payment['shop_id']}'),
              ],
            ),
          ),
          FutureBuilder<Uint8List>(
            future: _image,
            builder: (context, snap) {
              if (snap.hasError) {
                return TextButton(
                  onPressed: withLightImpact(
                    () => setState(
                      () => _image = ref
                          .read(subscriptionRepositoryProvider)
                          .slip(widget.payment['slip_path'] as String),
                    ),
                  ),
                  child: const Text('ပြေစာ ပြန်ဖွင့်မည်'),
                );
              }
              if (!snap.hasData) {
                return const SizedBox(
                  height: 240,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return SizedBox(
                height: 420,
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Image.memory(
                    snap.data!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Center(
                      child: Text(
                        'ပြေစာပုံ ဖွင့်မရပါ။ အသုံးပြုသူကို ပြန်တင်ခိုင်းပါ။',
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _note,
            maxLength: 500,
            minLines: 2,
            maxLines: 4,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'Review note / ပယ်ချရသည့် အကြောင်းရင်း',
            ),
          ),
          if (_failure != null)
            Text(
              _failure!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : withLightImpact(() => _review(true)),
            icon: const Icon(Icons.check_circle_outline),
            label: Text(
              _busy ? 'လုပ်ဆောင်နေပါသည်…' : 'ငွေဝင်ပြီး · အတည်ပြုမည်',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : withLightImpact(() => _review(false)),
            child: const Text('ပယ်ချပြီး အကြောင်းပြန်မည်'),
          ),
        ],
      ),
    ),
  );
}

class BillingConfigPage extends ConsumerStatefulWidget {
  const BillingConfigPage({super.key});
  @override
  ConsumerState<BillingConfigPage> createState() => _BillingConfigPageState();
}

class _BillingConfigPageState extends ConsumerState<BillingConfigPage> {
  bool _plans = true;
  late Future<List<BillingRow>> _rows = ref
      .read(subscriptionRepositoryProvider)
      .config(_plans);
  void _reload() => setState(
    () => _rows = ref.read(subscriptionRepositoryProvider).config(_plans),
  );
  Future<void> _edit([BillingRow? row]) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => BillingConfigEditor(plans: _plans, row: row),
      ),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Billing settings')),
    floatingActionButton: FloatingActionButton(
      onPressed: withLightImpact(() => _edit()),
      child: const Icon(Icons.add),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Plans')),
              ButtonSegment(value: false, label: Text('Payment accounts')),
            ],
            selected: {_plans},
            onSelectionChanged: withSelectionImpact((Set<bool> values) {
              _plans = values.first;
              _reload();
            }),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<BillingRow>>(
            future: _rows,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: TextButton(
                    onPressed: withLightImpact(_reload),
                    child: const Text('ပြန်ကြိုးစားမည်'),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                children: [
                  if (snapshot.data!.isEmpty)
                    const Text(
                      '＋ ကိုနှိပ်ပြီး အမှန်တကယ် အသုံးပြုမည့် အချက်အလက်များ ထည့်ပါ။',
                    ),
                  for (final row in snapshot.data!)
                    _panel(
                      context,
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(row['name'] as String),
                        subtitle: Text(
                          _plans
                              ? '${_money(row['price'])} · ${row['duration_days']} days'
                              : '${row['account_name']} · ${row['account_number']}',
                        ),
                        trailing: Icon(
                          row['active'] == true
                              ? Icons.check_circle
                              : Icons.pause_circle_outline,
                        ),
                        onTap: withLightImpact(() => _edit(row)),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}

class BillingConfigEditor extends ConsumerStatefulWidget {
  const BillingConfigEditor({super.key, required this.plans, this.row});
  final bool plans;
  final BillingRow? row;
  @override
  ConsumerState<BillingConfigEditor> createState() =>
      _BillingConfigEditorState();
}

class _BillingConfigEditorState extends ConsumerState<BillingConfigEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.row?['name'] as String?,
  );
  late final _first = TextEditingController(
    text: widget.row?[widget.plans ? 'price' : 'account_name']?.toString(),
  );
  late final _second = TextEditingController(
    text: widget.row?[widget.plans ? 'duration_days' : 'account_number']
        ?.toString(),
  );
  late final _details = TextEditingController(
    text: widget.row?[widget.plans ? 'description' : 'instructions'] as String?,
  );
  late bool _active = widget.row?['active'] as bool? ?? true;
  bool _busy = false;
  String? _failure;
  @override
  void dispose() {
    _name.dispose();
    _first.dispose();
    _second.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await ref.read(subscriptionRepositoryProvider).saveConfig(widget.plans, {
        if (widget.row != null) 'id': widget.row!['id'],
        'name': _name.text.trim(),
        'active': _active,
        if (widget.plans) ...{
          'price': int.parse(_first.text.trim()),
          'duration_days': int.parse(_second.text.trim()),
          'description': _details.text.trim(),
        } else ...{
          'account_name': _first.text.trim(),
          'account_number': _second.text.trim(),
          'instructions': _details.text.trim(),
        },
      });
      ref.invalidate(subscriptionOverviewProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _failure = _error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool number = false,
    int max = 120,
    int? limit,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      enabled: !_busy,
      maxLength: max,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'ဖြည့်ရန် လိုအပ်ပါသည်';
        if (number &&
            (int.tryParse(v.trim()) == null ||
                int.parse(v.trim()) < 1 ||
                int.parse(v.trim()) > (limit ?? 2147483647))) {
          return 'မှန်ကန်သော ပမာဏထည့်ပါ';
        }
        return null;
      },
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.plans ? 'Subscription plan' : 'Payment account'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _field(_name, 'Name', max: 80),
            _field(
              _first,
              widget.plans ? 'Price (MMK)' : 'Account holder name',
              number: widget.plans,
            ),
            _field(
              _second,
              widget.plans ? 'Duration (days)' : 'Account number',
              number: widget.plans,
              limit: widget.plans ? 1095 : null,
            ),
            TextField(
              controller: _details,
              enabled: !_busy,
              maxLength: 1000,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: widget.plans
                    ? 'Description / included features'
                    : 'Payment instructions',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Available to customers'),
              value: _active,
              onChanged: _busy
                  ? null
                  : withSelectionImpact(
                      (bool v) => setState(() => _active = v),
                    ),
            ),
            if (_failure != null) Text(_failure!),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : withLightImpact(_save),
              child: Text(_busy ? 'သိမ်းနေပါသည်…' : 'သိမ်းမည်'),
            ),
          ],
        ),
      ),
    ),
  );
}
