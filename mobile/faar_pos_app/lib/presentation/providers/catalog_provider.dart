import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local/app_database.dart';
import '../../domain/entities/product_entity.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

// Listens to database table changes (e.g. stock decrements on sale)
final databaseChangeListenerProvider = StreamProvider<String>((ref) {
  return AppDatabase.instance.tableChanges;
});

final categoriesProvider = Provider<List<String>>((ref) {
  // Recompute when products/categories table changes
  ref.watch(databaseChangeListenerProvider);
  return AppDatabase.instance.getCategories();
});

final filteredProductsProvider = FutureProvider<List<ProductEntity>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final category = ref.watch(selectedCategoryProvider);
  // Re-fetch products automatically when inventory or products change
  ref.watch(databaseChangeListenerProvider);

  return AppDatabase.instance.getAllProducts(
    query: query,
    category: category,
  );
});
