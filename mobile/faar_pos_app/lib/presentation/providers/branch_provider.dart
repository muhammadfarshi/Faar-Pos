import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/branch_entity.dart';
import 'auth_provider.dart';

final currentBranchProvider = Provider<BranchEntity?>((ref) {
  return ref.watch(authProvider).value?.branch;
});

final branchesProvider = FutureProvider<List<BranchEntity>>((ref) async {
  // Fetch from API
  await Future.delayed(const Duration(seconds: 1));
  return [];
});

class BranchNotifier extends AsyncNotifier<List<BranchEntity>> {
  @override
  Future<List<BranchEntity>> build() async {
    // initial fetch
    return [];
  }

  Future<void> createBranch(String name, String code, String city) async {
    // create logic
  }

  Future<void> updateBranch(int id, Map<String, dynamic> updates) async {
    // update logic
  }

  Future<void> deactivateBranch(int id) async {
    // deactivate logic
  }
}

final branchNotifierProvider = AsyncNotifierProvider<BranchNotifier, List<BranchEntity>>(() {
  return BranchNotifier();
});
