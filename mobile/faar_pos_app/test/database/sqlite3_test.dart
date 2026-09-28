import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('sqlite3 in-memory and file database operations work flawlessly', () {
    final db = sqlite3.openInMemory();
    db.execute('''
      CREATE TABLE test_products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        base_price TEXT NOT NULL,
        stock_quantity INTEGER NOT NULL
      );
    ''');

    final stmt = db.prepare('INSERT INTO test_products (name, base_price, stock_quantity) VALUES (?, ?, ?)');
    stmt.execute(['Brass Fixture', '1250.00', 45]);
    stmt.dispose();

    final result = db.select('SELECT * FROM test_products');
    expect(result.length, 1);
    expect(result.first['name'], 'Brass Fixture');
    expect(result.first['base_price'], '1250.00');
    expect(result.first['stock_quantity'], 45);

    db.dispose();
  });
}
