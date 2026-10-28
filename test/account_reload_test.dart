import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sai_mate/data/in_memory_shop_repository.dart';
import 'package:sai_mate/domain/shop_models.dart';
import 'package:sai_mate/presentation/shop_controller.dart';

class NamedRepository extends InMemoryShopRepository {
  NamedRepository(this.name);
  final String name;
  @override
  Future<ShopState> load() async =>
      (await super.load()).copyWith(ownerName: name, shopName: '$name shop');
}

void main() {
  test('shop reloads when the account repository changes', () async {
    final account = StateProvider<String>((ref) => 'Milo');
    final container = ProviderContainer(
      overrides: [
        repositoryProvider.overrideWith(
          (ref) => NamedRepository(ref.watch(account)),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect((await container.read(shopProvider.future)).ownerName, 'Milo');
    container.read(account.notifier).state = 'New owner';
    expect((await container.read(shopProvider.future)).ownerName, 'New owner');
    expect(
      container.read(shopProvider).requireValue.shopName,
      'New owner shop',
    );
  });
}
