import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'domain/shop_models.dart';
import 'presentation/shop_controller.dart';
import 'presentation/sale_cart_sheet.dart';
import 'presentation/purchase_cart_sheet.dart';
import 'presentation/record_management_sheet.dart';
import 'presentation/advanced_reports_page.dart';
import 'presentation/inventory_add_sheet.dart';
import 'presentation/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://wvpdnbncweoebtnnsrag.supabase.co',
  );
  const key = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_SLBMcNyMVCtJgMvker0bbQ_tygR6cWj',
  );
  await Supabase.initialize(url: url, publishableKey: key);
  runApp(const ProviderScope(child: SaiMateApp()));
}

const ink = Color(0xFF18212B);
const muted = Color(0xFF71808B);
const cream = Colors.white;
const green = Color(0xFF1C6D5B);
const mint = Color(0xFFDFF3E9);
const orange = Color(0xFFFF9E63);
const line = Color(0xFFE9EBE5);
const red = Color(0xFFE96C66);

Color appSurface(BuildContext context) => Theme.of(context).colorScheme.surface;
Color appCardColor(BuildContext context) =>
    Theme.of(context).colorScheme.surfaceContainerHigh;
Color appLineColor(BuildContext context) =>
    Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .65);
Color appRaisedSurface(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF151515)
    : const Color(0xFFF7F8F8);

enum EntryType { sale, purchase, customer, debt, product }

abstract final class AppErrorMessage {
  static String from(Object error) {
    if (error is FormatException) return error.message.toString();
    if (error is AuthException) return error.message;
    if (error is PlatformException && error.code == 'channel-error') {
      return 'ပုံရွေးစနစ် စတင်၍မရသေးပါ။ App ကိုပိတ်ပြီး ပြန်ဖွင့်ပါ။';
    }
    if (error is PostgrestException) {
      final message = error.message.toLowerCase();
      if (message.contains('insufficient stock')) {
        return 'ပစ္စည်းလက်ကျန် မလုံလောက်ပါ။ လက်ကျန်ပမာဏကို စစ်ဆေးပါ။';
      }
      if (error.code == '23505' && message.contains('sku')) {
        return 'ဤ SKU နံပါတ်ကို အသုံးပြုပြီးသား ဖြစ်ပါသည်။';
      }
      if (error.code == 'PGRST202') {
        return 'Supabase လုပ်ဆောင်ချက် မပြည့်စုံသေးပါ။ Database setup ကို စစ်ဆေးပါ။';
      }
      return 'အချက်အလက် သိမ်းဆည်း၍ မရပါ။ ${error.message}';
    }
    final message = error.toString();
    if (message.contains('SocketException') ||
        message.contains('Connection refused')) {
      return 'အင်တာနက် သို့မဟုတ် Supabase ချိတ်ဆက်မှုကို စစ်ဆေးပါ။';
    }
    return message
        .replaceFirst('Bad state: ', '')
        .replaceFirst('FormatException: ', '');
  }
}

class SaiMateApp extends ConsumerWidget {
  const SaiMateApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'ဆိုင်မိတ်',
    themeMode: ref.watch(themeModeProvider),
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: cream,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: green,
            brightness: Brightness.light,
          ).copyWith(
            surface: Colors.white,
            surfaceContainerLowest: Colors.white,
            surfaceContainerLow: Colors.white,
            surfaceContainer: Colors.white,
            surfaceContainerHigh: Colors.white,
            surfaceContainerHighest: Colors.white,
          ),
      fontFamily: 'Noto Sans Myanmar',
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: const Color(0x14000000),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: line),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        elevation: 18,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Color(0x660A201B),
        showDragHandle: true,
      ),
    ),
    darkTheme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: const Color(0xFF43C6A8),
            brightness: Brightness.dark,
          ).copyWith(
            surface: Colors.black,
            surfaceContainerLowest: Colors.black,
            surfaceContainerLow: Colors.black,
            surfaceContainer: Colors.black,
            surfaceContainerHigh: Colors.black,
            surfaceContainerHighest: Colors.black,
          ),
      fontFamily: 'Noto Sans Myanmar',
      cardTheme: CardThemeData(
        color: Colors.black,
        elevation: 2,
        shadowColor: const Color(0x66000000),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.black,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFF29403A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFF29403A)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.black,
        elevation: 24,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Color(0xAA020806),
        showDragHandle: true,
      ),
    ),
    home: const AuthGate(),
  );
}

class MyApp extends SaiMateApp {
  const MyApp({super.key});
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    return auth.when(
      data: (value) =>
          value.session == null ? const LoginPage() : const AppShell(),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text(e.toString()))),
    );
  }
}

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController(),
      shop = TextEditingController();
  final registerProvider = StateProvider.autoDispose<bool>((ref) => false);
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    shop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final register = ref.watch(registerProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CircleAvatar(
                    radius: 34,
                    backgroundColor: mint,
                    child: Icon(
                      Icons.storefront_rounded,
                      color: green,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    register ? 'ဆိုင်အသစ် ဖွင့်မည်' : 'Sai Mate',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (register) ...[
                    FormFieldBox(controller: name, label: 'အမည်'),
                    FormFieldBox(controller: shop, label: 'ဆိုင်အမည်'),
                  ],
                  FormFieldBox(controller: email, label: 'အီးမေးလ်'),
                  FormFieldBox(controller: password, label: 'စကားဝှက်'),
                  const SizedBox(height: 18),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: green,
                      padding: const EdgeInsets.all(14),
                    ),
                    onPressed: () => _submit(register),
                    child: Text(register ? 'အကောင့်ဖွင့်မည်' : 'ဝင်မည်'),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(registerProvider.notifier).state = !register,
                    child: Text(
                      register ? 'အကောင့်ရှိပြီးသား' : 'အကောင့်အသစ်ဖွင့်မည်',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(bool register) async {
    try {
      if (register) {
        await Supabase.instance.client.auth.signUp(
          email: email.text.trim(),
          password: password.text,
          data: {'full_name': name.text.trim(), 'shop_name': shop.text.trim()},
        );
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
      ref.invalidate(shopProvider);
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final Set<int> _builtTabs = {0};

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(tabProvider);
    _builtTabs.add(tab);
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final online = ref.watch(isOnlineProvider);
    ref.listen<bool>(isOnlineProvider, (previous, connected) {
      if (connected && previous == false) {
        ref.invalidate(shopProvider);
        ref.invalidate(transactionHistoryProvider);
      }
    });
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: colors.surface)),
          IndexedStack(
            index: tab,
            children: List.generate(4, (index) {
              if (!_builtTabs.contains(index)) return const SizedBox.shrink();
              return switch (index) {
                0 => const DashboardPage(),
                1 => const InventoryPage(),
                2 => const CustomersPage(),
                _ => const AdvancedReportsPage(),
              };
            }),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top,
            right: 1,
            child: ConnectionBadge(online: online),
          ),
        ],
      ),
      floatingActionButton: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => showEntrySheet(context, EntryType.sale),
          borderRadius: BorderRadius.circular(19),
          child: Ink(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: orange,
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: const Color(0xFF5F6969), width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x330C1C18),
                  blurRadius: 12,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 38),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(24, 0, 24, 10),
        child: RepaintBoundary(
          child: Container(
            height: 66,
            decoration: BoxDecoration(
              color: appRaisedSurface(context),
              borderRadius: BorderRadius.circular(44),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? .24 : .08),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                AppNavItem(
                  current: tab,
                  index: 0,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'ပင်မ',
                ),
                AppNavItem(
                  current: tab,
                  index: 1,
                  icon: Icons.inventory_2_outlined,
                  activeIcon: Icons.inventory_2,
                  label: 'ပစ္စည်း',
                ),
                AppNavItem(
                  current: tab,
                  index: 2,
                  icon: Icons.people_outline,
                  activeIcon: Icons.people,
                  label: 'ဖောက်သည်',
                ),
                AppNavItem(
                  current: tab,
                  index: 3,
                  icon: Icons.donut_large_outlined,
                  activeIcon: Icons.donut_large,
                  label: 'အစီရင်ခံစာ',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ConnectionBadge extends StatelessWidget {
  const ConnectionBadge({super.key, required this.online});
  final bool online;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      width: 48,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            color: Colors.green,
            size: 17,
          ),
          const SizedBox(height: 2),
          Text(
            online ? 'Online' : 'Offline',
            style: const TextStyle(
              color: Colors.green,
              fontFamily: null,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

class AppNavItem extends ConsumerWidget {
  const AppNavItem({
    super.key,
    required this.current,
    required this.index,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
  final int current, index;
  final IconData icon, activeIcon;
  final String label;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = current == index;
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: Semantics(
        label: label,
        button: true,
        selected: selected,
        child: InkResponse(
          onTap: () {
            ref.read(searchProvider.notifier).state = '';
            ref.read(tabProvider.notifier).state = index;
          },
          radius: 32,
          child: Tooltip(
            message: label,
            child: Center(
              child: AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: selected ? colors.primary : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  scale: selected ? 1 : .9,
                  child: Icon(
                    selected ? activeIcon : icon,
                    color: selected
                        ? colors.onPrimary
                        : colors.onSurfaceVariant,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider);
    final customers = ref.watch(customersProvider);
    final shop = ref.watch(shopProvider).valueOrNull;
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: DashboardHeader(
              shopName: shop?.shopName ?? 'Sai Mate',
              ownerName: shop?.ownerName ?? '',
              onAccountTap: () => showAccountSheet(
                context,
                ref,
                shopName: shop?.shopName ?? 'Sai Mate',
                ownerName: shop?.ownerName ?? '',
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 98),
            sliver: SliverList.list(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: SummaryCard(
                        debt: true,
                        value: shop?.outstandingDebt ?? 0,
                        count: customers.where((c) => c.debt > 0).length,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 4,
                      child: SummaryCard(
                        debt: false,
                        value: shop?.inventoryValue ?? 0,
                        count: products.length,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const SectionTitle('အမြန်လုပ်ဆောင်ရန်'),
                const SizedBox(height: 8),
                Row(
                  children: const [
                    QuickAction(EntryType.sale, Icons.add, 'ရောင်းမည်'),
                    QuickAction(EntryType.purchase, Icons.south_west, 'ဝယ်မည်'),
                    QuickAction(
                      EntryType.customer,
                      Icons.person_outline,
                      'ဖောက်သည်',
                    ),
                    QuickAction(EntryType.debt, Icons.history, 'အကြွေး'),
                  ],
                ),
                const SizedBox(height: 22),
                SectionTitle(
                  'ပစ္စည်းလက်ကျန်',
                  action: 'အားလုံးကြည့်ရန် ›',
                  onTap: () => ref.read(tabProvider.notifier).state = 1,
                ),
                const SizedBox(height: 10),
                AppCard(
                  child: Column(
                    children: products
                        .take(3)
                        .map((product) => ProductRow(product, divider: true))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 22),
                SectionTitle(
                  'မကြာသေးခင် အကြွေးများ',
                  action: 'စာရင်း ›',
                  onTap: () => ref.read(tabProvider.notifier).state = 2,
                ),
                const SizedBox(height: 10),
                AppCard(
                  child: Column(
                    children: customers
                        .take(2)
                        .map((customer) => CustomerRow(customer, divider: true))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.shopName,
    required this.ownerName,
    required this.onAccountTap,
  });

  final String shopName;
  final String ownerName;
  final VoidCallback onAccountTap;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(22, 24, 18, 20),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [green, Color(0xFF255F54)],
      ),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ownerName.isEmpty ? 'မင်္ဂလာပါ' : 'မင်္ဂလာပါ၊ $ownerName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 3),
              Text(
                shopName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Tooltip(
          message: 'အကောင့်နှင့် ထွက်ရန်',
          child: Semantics(
            button: true,
            label: 'အကောင့်နှင့် ထွက်ရန်',
            child: InkWell(
              onTap: onAccountTap,
              borderRadius: BorderRadius.circular(20),
              child: const SaiMateLogo(),
            ),
          ),
        ),
      ],
    ),
  );
}

Future<void> showAccountSheet(
  BuildContext context,
  WidgetRef ref, {
  required String shopName,
  required String ownerName,
}) async {
  final user = Supabase.instance.client.auth.currentUser;
  final shouldLogout = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.storefront_rounded, color: green, size: 42),
          const SizedBox(height: 10),
          Text(
            shopName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          if (ownerName.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(ownerName, textAlign: TextAlign.center),
          ],
          if (user?.email case final email?) ...[
            const SizedBox(height: 3),
            Text(
              email,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontSize: 13),
            ),
          ],
          const SizedBox(height: 22),
          Consumer(
            builder: (context, ref, child) {
              ref.watch(themeModeProvider);
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                secondary: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: green,
                ),
                title: const Text('အမှောင်ပုံစံ'),
                subtitle: Text(isDark ? 'Dark mode' : 'Light mode'),
                value: isDark,
                onChanged: ref.read(themeModeProvider.notifier).setDark,
              );
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: red,
              side: const BorderSide(color: red),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: sheetContext,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('အကောင့်မှ ထွက်မည်လား'),
                  content: const Text(
                    'နောက်တစ်ကြိမ် အသုံးပြုရန် အီးမေးလ်နှင့် စကားဝှက်ဖြင့် ပြန်ဝင်ရပါမည်။',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('မထွက်သေးပါ'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: red),
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('ထွက်မည်'),
                    ),
                  ],
                ),
              );
              if (confirmed == true && sheetContext.mounted) {
                Navigator.pop(sheetContext, true);
              }
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('အကောင့်မှ ထွက်မည်'),
          ),
        ],
      ),
    ),
  );
  if (shouldLogout != true) return;
  try {
    ref.read(tabProvider.notifier).state = 0;
    ref.read(searchProvider.notifier).state = '';
    ref.invalidate(shopProvider);
    await Supabase.instance.client.auth.signOut();
  } on AuthException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('အကောင့်မှ ထွက်၍မရပါ။ ${error.message}')),
      );
    }
  }
}

class SaiMateLogo extends StatefulWidget {
  const SaiMateLogo({super.key});

  @override
  State<SaiMateLogo> createState() => _SaiMateLogoState();
}

class _SaiMateLogoState extends State<SaiMateLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation;

  @override
  void initState() {
    super.initState();
    animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final wave = math.sin(animation.value * math.pi * 2);
        return Transform.translate(
          offset: Offset(0, wave * 1.8),
          child: Transform.scale(
            scale: 1 + (wave * .018),
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(shape: BoxShape.circle),
              child: ClipOval(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.inventory_2_rounded,
                      color: Colors.white,
                      size: 29,
                    ),
                    Positioned(
                      right: 7,
                      top: 6,
                      child: Transform.rotate(
                        angle: animation.value * math.pi * 2,
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xFFFFC18B),
                          size: 13,
                        ),
                      ),
                    ),
                    const Positioned(
                      bottom: 3,
                      child: Text(
                        'SAI MATE',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: null,
                          fontSize: 5.7,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.debt,
    required this.value,
    required this.count,
  });
  final bool debt;
  final int value, count;
  @override
  Widget build(BuildContext context) => Container(
    height: 150,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: Theme.of(context).brightness == Brightness.dark
            ? const [Color(0xA63B6C61), Color(0x59314D47)]
            : (debt
                  ? const [Color(0xE8FFFFFF), Color(0x91BCEADA)]
                  : const [Color(0xE8FFFFFF), Color(0x99FFE1C8)]),
      ),
      border: Border.all(color: Colors.white.withValues(alpha: .7)),
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [
        BoxShadow(
          color: Color(0x24124C40),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!debt) const Text('📦', style: TextStyle(fontSize: 23)),
        if (!debt) const SizedBox(height: 7),
        Text(
          debt ? 'ရရန်ရှိငွေ' : 'ပစ္စည်းတန်ဖိုး',
          style: const TextStyle(
            color: green,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${NumberFormat('#,##0').format(value)} Ks',
          maxLines: 1,
          style: TextStyle(
            color: debt ? ink : const Color(0xFFA65A2A),
            fontSize: debt ? 20 : 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          debt ? 'ဖောက်သည် $count ယောက်' : 'ကုန်ပစ္စည်း $count ခု',
          style: const TextStyle(color: muted, fontSize: 10),
        ),
        if (debt)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Supabase live data',
              style: TextStyle(
                color: green,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onTap});
  final String title;
  final String? action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      if (action != null)
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Text(
              action!,
              style: const TextStyle(
                color: green,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
    ],
  );
}

class QuickAction extends StatelessWidget {
  const QuickAction(this.type, this.icon, this.label, {super.key});
  final EntryType type;
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => showEntrySheet(context, type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: appRaisedSurface(context),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .045),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: green, size: 20),
              const SizedBox(height: 5),
              Text(label, style: const TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ),
    ),
  );
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: appRaisedSurface(context),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? .24
                  : .06,
            ),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    ),
  );
}

class ProductRow extends StatelessWidget {
  const ProductRow(this.product, {super.key, this.divider = false});
  final Product product;
  final bool divider;
  @override
  Widget build(BuildContext context) {
    final critical = product.stock <= 5;
    final low = product.stock <= 10 && !critical;
    return GestureDetector(
      onLongPress: () => showProductManagement(context, product),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: divider
            ? BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: appLineColor(context)),
                ),
              )
            : null,
        child: Row(
          children: [
            ProductThumbnail(product: product),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${product.sku} · ${product.stock} ခု ကျန်',
                    style: const TextStyle(color: muted, fontSize: 10),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: critical
                    ? const Color(0xFFFFE4DF)
                    : low
                    ? const Color(0xFFFFF0CF)
                    : const Color(0xFFE1F3E9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                critical
                    ? 'အရေးကြီး'
                    : low
                    ? 'နည်းနေပြီ'
                    : 'အဆင်ပြေ',
                style: TextStyle(
                  color: critical
                      ? const Color(0xFFB84E48)
                      : low
                      ? const Color(0xFF9A6A16)
                      : green,
                  fontSize: 9,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductThumbnail extends ConsumerWidget {
  const ProductThumbnail({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) => InkWell(
    onTap: () async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        final selection = await ProductImagePicker.pick(context);
        if (selection == null || !context.mounted) return;
        await ref
            .read(shopProvider.notifier)
            .updateProductImage(
              product: product,
              imageBytes: selection.bytes,
              imageExtension: selection.extension,
            );
        messenger.showSnackBar(
          const SnackBar(
            content: Text('ပစ္စည်းပုံ ပြောင်းပြီးပါပြီ ✓'),
            backgroundColor: green,
          ),
        );
      } catch (error) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(AppErrorMessage.from(error)),
            backgroundColor: const Color(0xFF9F3A36),
          ),
        );
      }
    },
    borderRadius: BorderRadius.circular(14),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 46,
          height: 46,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFF9E9DD),
            borderRadius: BorderRadius.circular(14),
          ),
          child: product.imageUrl == null
              ? const ProductImageFallback()
              : Image.network(
                  product.imageUrl!,
                  fit: BoxFit.cover,
                  cacheWidth: 96,
                  cacheHeight: 96,
                  filterQuality: FilterQuality.low,
                  errorBuilder: (context, error, stackTrace) =>
                      const ProductImageFallback(),
                ),
        ),
        Positioned(
          right: -3,
          bottom: -3,
          child: Container(
            width: 17,
            height: 17,
            decoration: BoxDecoration(
              color: green,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: const Icon(
              Icons.camera_alt_rounded,
              color: Colors.white,
              size: 9,
            ),
          ),
        ),
      ],
    ),
  );
}

class ProductImageFallback extends StatelessWidget {
  const ProductImageFallback({super.key});

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFF0E5), Color(0xFFF7D9C4)],
      ),
    ),
    child: Center(
      child: Icon(
        Icons.inventory_2_rounded,
        color: Color(0xFFC87943),
        size: 25,
      ),
    ),
  );
}

class ProductImageSelection {
  const ProductImageSelection({required this.bytes, required this.extension});

  final Uint8List bytes;
  final String extension;
}

abstract final class ProductImagePicker {
  static Future<ProductImageSelection?> pick(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const ProductImageSourceSheet(),
    );
    if (source == null) return null;
    final image = await ImagePicker().pickImage(
      source: source,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 82,
      maxWidth: 1400,
      maxHeight: 1400,
    );
    if (image == null) return null;
    return ProductImageSelection(
      bytes: await image.readAsBytes(),
      extension: image.name.split('.').last.toLowerCase(),
    );
  }
}

class ProductImageSourceSheet extends StatelessWidget {
  const ProductImageSourceSheet({super.key});

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      decoration: BoxDecoration(
        color: appSurface(context),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: line,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 17),
          const Text(
            'ပစ္စည်းပုံ ရွေးချယ်ပါ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ImageSourceOption(
                  icon: Icons.camera_alt_rounded,
                  title: 'ဓာတ်ပုံရိုက်မည်',
                  color: green,
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ImageSourceOption(
                  icon: Icons.photo_library_rounded,
                  title: 'Gallery မှရွေးမည်',
                  color: orange,
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class ImageSourceOption extends StatelessWidget {
  const ImageSourceOption({
    super.key,
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .2)),
      ),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 23),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}

class ProductImagePickerField extends StatelessWidget {
  const ProductImagePickerField({
    super.key,
    required this.selection,
    required this.onTap,
  });

  final ProductImageSelection? selection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 92,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: appCardColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: appLineColor(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 70,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFFF9E9DD),
                borderRadius: BorderRadius.circular(13),
              ),
              child: selection == null
                  ? const ProductImageFallback()
                  : Image.memory(selection!.bytes, fit: BoxFit.cover),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selection == null
                        ? 'ပစ္စည်းပုံ ထည့်မည်'
                        : 'ပုံရွေးပြီးပါပြီ',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Gallery မှ ပုံရွေးရန် နှိပ်ပါ',
                    style: TextStyle(color: muted, fontSize: 10),
                  ),
                ],
              ),
            ),
            const Icon(Icons.add_photo_alternate_rounded, color: green),
          ],
        ),
      ),
    ),
  );
}

class CustomerRow extends StatelessWidget {
  const CustomerRow(this.customer, {super.key, this.divider = false});
  final Customer customer;
  final bool divider;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onLongPress: () => showCustomerManagement(context, customer),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: divider
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: appLineColor(context))),
            )
          : null,
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFECE9FF),
            child: Text(
              customer.name.substring(0, 1),
              style: const TextStyle(
                color: Color(0xFF6659B1),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  customer.note,
                  style: const TextStyle(color: muted, fontSize: 10),
                ),
              ],
            ),
          ),
          Text(
            '${customer.debt} Ks',
            style: const TextStyle(
              color: red,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

class InventoryPage extends ConsumerWidget {
  const InventoryPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchProvider).toLowerCase();
    final items = ref
        .watch(productsProvider)
        .where((p) => p.name.toLowerCase().contains(query))
        .toList();
    return ListPage(
      title: 'ပစ္စည်းလက်ကျန်',
      hint: 'ပစ္စည်းရှာရန်...',
      count: 'ပစ္စည်းအားလုံး · ${items.length}',
      onAdd: () => showInventoryAddSheet(
        context,
        onCreateNew: () => showEntrySheet(context, EntryType.product),
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => ProductRow(items[index]),
    );
  }
}

class CustomersPage extends ConsumerWidget {
  const CustomersPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchProvider).toLowerCase();
    final items = ref
        .watch(customersProvider)
        .where((p) => p.name.toLowerCase().contains(query))
        .toList();
    return ListPage(
      title: 'ဖောက်သည်များ',
      hint: 'ဖောက်သည်ရှာရန်...',
      count: 'ဖောက်သည် · ${items.length}',
      onAdd: () => showEntrySheet(context, EntryType.customer),
      itemCount: items.length,
      itemBuilder: (context, index) => CustomerRow(items[index]),
    );
  }
}

class ListPage extends ConsumerWidget {
  const ListPage({
    super.key,
    required this.title,
    required this.hint,
    required this.count,
    required this.onAdd,
    required this.itemCount,
    required this.itemBuilder,
  });
  final String title, hint, count;
  final VoidCallback onAdd;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  @override
  Widget build(BuildContext context, WidgetRef ref) => SafeArea(
    bottom: false,
    child: CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 25, 18, 10),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (v) => ref.read(searchProvider.notifier).state = v,
                  decoration: InputDecoration(
                    hintText: hint,
                    prefixIcon: const Icon(Icons.search),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 18),
                SectionTitle(count, action: '＋ ထည့်မည်', onTap: onAdd),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 110),
          sliver: SliverList.builder(
            itemCount: itemCount,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RepaintBoundary(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: appRaisedSurface(context),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .035),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: itemBuilder(context, index),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sales = ref.watch(shopProvider).valueOrNull?.monthlySales ?? 0;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text(
              'အစီရင်ခံစာ',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF15362F)
                    : mint,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ဒီလ ရောင်းအား',
                    style: TextStyle(color: green, fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${NumberFormat('#,##0').format(sales)} Ks',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Supabase live transaction data',
                    style: TextStyle(
                      color: green,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showEntrySheet(BuildContext context, EntryType type) {
  if (type == EntryType.sale) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SaleCartSheet(),
    );
    return;
  }
  if (type == EntryType.purchase) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PurchaseCartSheet(),
    );
    return;
  }
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => EntryFormSheet(type: type),
  );
}

class EntryFormSheet extends ConsumerStatefulWidget {
  const EntryFormSheet({super.key, required this.type});
  final EntryType type;
  @override
  ConsumerState<EntryFormSheet> createState() => _EntryFormSheetState();
}

class _EntryFormSheetState extends ConsumerState<EntryFormSheet> {
  final first = TextEditingController(),
      second = TextEditingController(),
      third = TextEditingController(),
      fourth = TextEditingController(),
      fifth = TextEditingController();
  final productImageProvider =
      StateProvider.autoDispose<ProductImageSelection?>((ref) => null);
  @override
  void dispose() {
    first.dispose();
    second.dispose();
    third.dispose();
    fourth.dispose();
    fifth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shop = ref.watch(shopProvider).valueOrNull;
    final productImage = ref.watch(productImageProvider);
    final title = {
      EntryType.sale: 'ရောင်းချမှု မှတ်တမ်း',
      EntryType.purchase: 'ဝယ်ယူမှု မှတ်တမ်း',
      EntryType.customer: 'ဖောက်သည်အသစ်',
      EntryType.debt: 'အကြွေး မှတ်တမ်း',
      EntryType.product: 'ပစ္စည်းအသစ်',
    }[widget.type]!;
    final productFlow =
        widget.type == EntryType.sale || widget.type == EntryType.purchase;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
        decoration: BoxDecoration(
          color: appSurface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (productFlow)
                SelectField(
                  label: 'ပစ္စည်း',
                  items: shop?.products ?? const [],
                  onChanged: (v) =>
                      ref.read(selectedProductProvider.notifier).state = v,
                ),
              if (widget.type == EntryType.debt)
                CustomerSelect(
                  items: shop?.customers ?? const [],
                  onChanged: (v) =>
                      ref.read(selectedCustomerProvider.notifier).state = v,
                ),
              if (widget.type == EntryType.customer) ...[
                FormFieldBox(controller: first, label: 'အမည်'),
                FormFieldBox(controller: second, label: 'ဖုန်းနံပါတ်'),
              ],
              if (widget.type == EntryType.product) ...[
                ProductImagePickerField(
                  selection: productImage,
                  onTap: _pickProductImage,
                ),
                FormFieldBox(controller: first, label: 'ပစ္စည်းအမည်'),
                FormFieldBox(controller: second, label: 'SKU'),
                FormFieldBox(
                  controller: third,
                  label: 'ဝယ်စျေး',
                  numeric: true,
                ),
                FormFieldBox(
                  controller: fourth,
                  label: 'ရောင်းစျေး',
                  numeric: true,
                ),
                FormFieldBox(
                  controller: fifth,
                  label: 'စတင်လက်ကျန် အရေအတွက်',
                  numeric: true,
                ),
              ],
              if (productFlow || widget.type == EntryType.debt)
                FormFieldBox(
                  controller: first,
                  label: widget.type == EntryType.debt
                      ? 'အကြွေးပမာဏ'
                      : 'အရေအတွက်',
                  numeric: true,
                ),
              const SizedBox(height: 17),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: green,
                    padding: const EdgeInsets.all(13),
                  ),
                  onPressed: _save,
                  child: const Text('သိမ်းမည်'),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'ပယ်ဖျက်မည်',
                    style: TextStyle(color: muted),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    var succeeded = false;
    var resultMessage = 'သိမ်းဆည်းပြီးပါပြီ ✓';
    try {
      final c = ref.read(shopProvider.notifier),
          qty = int.tryParse(first.text) ?? 0;
      final selectedProduct = ref.read(selectedProductProvider);
      final selectedCustomer = ref.read(selectedCustomerProvider);
      if ((widget.type == EntryType.sale ||
              widget.type == EntryType.purchase) &&
          (selectedProduct == null || selectedProduct.isEmpty)) {
        throw const FormatException('ပစ္စည်းတစ်ခု ရွေးချယ်ပါ');
      }
      if (widget.type == EntryType.debt &&
          (selectedCustomer == null || selectedCustomer.isEmpty)) {
        throw const FormatException('ဖောက်သည်တစ်ဦး ရွေးချယ်ပါ');
      }
      if ((widget.type == EntryType.sale ||
              widget.type == EntryType.purchase ||
              widget.type == EntryType.debt) &&
          qty <= 0) {
        throw const FormatException('အရေအတွက်သည် 0 ထက် ကြီးရမည်');
      }
      switch (widget.type) {
        case EntryType.customer:
          await c.addCustomer(first.text, second.text);
        case EntryType.product:
          await c.addProduct(
            name: first.text,
            sku: second.text,
            cost: int.tryParse(third.text) ?? 0,
            price: int.tryParse(fourth.text) ?? 0,
            stock: int.tryParse(fifth.text) ?? 0,
            imageBytes: ref.read(productImageProvider)?.bytes,
            imageExtension: ref.read(productImageProvider)?.extension,
          );
        case EntryType.sale:
          await c.sell(productId: selectedProduct!, quantity: qty);
        case EntryType.purchase:
          await c.purchase(productId: selectedProduct!, quantity: qty);
        case EntryType.debt:
          await c.addDebt(customerId: selectedCustomer!, amount: qty);
      }
      succeeded = true;
    } catch (error) {
      developer.log('Form save failed', name: 'SaiMate.UI', error: error);
      resultMessage = AppErrorMessage.from(error);
    }
    if (!mounted) return;
    ref.read(selectedProductProvider.notifier).state = null;
    ref.read(selectedCustomerProvider.notifier).state = null;
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(resultMessage),
          backgroundColor: succeeded ? green : const Color(0xFF9F3A36),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: succeeded ? 2 : 4),
        ),
      );
  }

  Future<void> _pickProductImage() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final selection = await ProductImagePicker.pick(context);
      if (selection == null || !mounted) return;
      ref.read(productImageProvider.notifier).state = selection;
    } catch (error, stack) {
      developer.log(
        'Image picker failed',
        name: 'SaiMate.UI',
        error: error,
        stackTrace: stack,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(AppErrorMessage.from(error)),
          backgroundColor: const Color(0xFF9F3A36),
        ),
      );
    }
  }
}

class FormFieldBox extends StatelessWidget {
  const FormFieldBox({
    super.key,
    required this.controller,
    required this.label,
    this.numeric = false,
  });
  final TextEditingController controller;
  final String label;
  final bool numeric;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextField(
      controller: controller,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label),
    ),
  );
}

class SelectField extends StatelessWidget {
  const SelectField({
    super.key,
    required this.label,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final List<Product> items;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: DropdownButtonFormField<String>(
      decoration: InputDecoration(labelText: label),
      items: items
          .map((x) => DropdownMenuItem(value: x.id, child: Text(x.name)))
          .toList(),
      onChanged: onChanged,
    ),
  );
}

class CustomerSelect extends StatelessWidget {
  const CustomerSelect({
    super.key,
    required this.items,
    required this.onChanged,
  });
  final List<Customer> items;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: DropdownButtonFormField<String>(
      decoration: const InputDecoration(labelText: 'ဖောက်သည်'),
      items: items
          .map((x) => DropdownMenuItem(value: x.id, child: Text(x.name)))
          .toList(),
      onChanged: onChanged,
    ),
  );
}
