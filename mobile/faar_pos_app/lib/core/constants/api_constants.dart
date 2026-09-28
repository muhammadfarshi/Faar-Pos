class ApiConstants {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080', // Android emulator localhost
  );
  static const String v1 = '/api/v1';
  // Auth
  static const String login = '$v1/auth/login';
  static const String refresh = '$v1/auth/refresh';
  static const String logout = '$v1/auth/logout';
  static const String me = '$v1/auth/me';
  // Orgs & Branches
  static const String orgMe = '$v1/organizations/me';
  static const String branches = '$v1/organizations/me/branches';
  // Users
  static const String users = '$v1/users';
  // Products
  static const String products = '$v1/products';
  static const String categories = '$v1/categories';
  // Taxes
  static const String taxGroups = '$v1/taxes/groups';
  // Transactions
  static const String transactions = '$v1/transactions';
  static const String syncBatch = '$v1/transactions/sync-batch';
  // Inventory
  static const String inventory = '$v1/inventory';
  // Reports
  static const String reports = '$v1/reports';
  // Printers
  static const String printers = '$v1/printers';
}
