import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BrahmaApp());
}

class BrahmaApp extends StatelessWidget {
  const BrahmaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brahma',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF090A0F),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF10B981),
          secondary: Color(0xFF06B6D4),
          surface: Color(0xFF131622),
          error: Color(0xFFEF4444),
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF131622),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: const BrahmaMainDashboard(),
    );
  }
}

class BrahmaDatabase {
  static final BrahmaDatabase instance = BrahmaDatabase._init();
  static Database? _database;

  BrahmaDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('brahma_core.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE accounts (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            account_type TEXT NOT NULL,
            balance_paise INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE meal_logs (
            id TEXT PRIMARY KEY,
            hospital_name TEXT NOT NULL,
            meal_type TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            rate_paise INTEGER NOT NULL,
            total_paise INTEGER NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE tasks (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            is_completed INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL
          )
        ''');

        const uuid = Uuid();
        await db.insert('accounts', {'id': uuid.v4(), 'name': 'Cash in Hand', 'account_type': 'CASH', 'balance_paise': 0});
        await db.insert('accounts', {'id': uuid.v4(), 'name': 'Primary Bank', 'account_type': 'BANK', 'balance_paise': 0});
        await db.insert('accounts', {'id': uuid.v4(), 'name': 'UPI Wallet', 'account_type': 'UPI', 'balance_paise': 0});
      },
    );
  }
}

class BrahmaMainDashboard extends StatefulWidget {
  const BrahmaMainDashboard({super.key});

  @override
  State<BrahmaMainDashboard> createState() => _BrahmaMainDashboardState();
}

class _BrahmaMainDashboardState extends State<BrahmaMainDashboard> {
  int _currentIndex = 0;
  int _liquidBalancePaise = 0;
  List<Map<String, dynamic>> _todayMeals = [];
  List<Map<String, dynamic>> _tasks = [];
  bool _nightCheckinDone = false;

  final _hospitalCtrl = TextEditingController(text: 'Berlin General Hospital');
  final _qtyCtrl = TextEditingController(text: '50');
  final _rateCtrl = TextEditingController(text: '80');
  final _taskCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    final db = await BrahmaDatabase.instance.database;

    final accs = await db.query('accounts');
    int total = 0;
    for (var a in accs) {
      total += (a['balance_paise'] as int);
    }

    final meals = await db.query('meal_logs', orderBy: 'created_at DESC');
    final tasksList = await db.query('tasks', orderBy: 'created_at DESC');

    setState(() {
      _liquidBalancePaise = total;
      _todayMeals = meals;
      _tasks = tasksList;
    });
  }

  String _formatPaise(int paise) {
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2).format(paise / 100.0);
  }

  Future<void> _addMealEntry() async {
    final qty = int.tryParse(_qtyCtrl.text) ?? 0;
    final rateRupees = double.tryParse(_rateCtrl.text) ?? 0.0;
    if (qty <= 0 || rateRupees <= 0) return;

    final ratePaise = (rateRupees * 100).round();
    final totalPaise = qty * ratePaise;

    final db = await BrahmaDatabase.instance.database;
    await db.insert('meal_logs', {
      'id': const Uuid().v4(),
      'hospital_name': _hospitalCtrl.text.trim(),
      'meal_type': 'LUNCH',
      'quantity': qty,
      'rate_paise': ratePaise,
      'total_paise': totalPaise,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });

    _refreshData();
  }

  Future<void> _addTask() async {
    if (_taskCtrl.text.trim().isEmpty) return;
    final db = await BrahmaDatabase.instance.database;
    await db.insert('tasks', {
      'id': const Uuid().v4(),
      'title': _taskCtrl.text.trim(),
      'is_completed': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    _taskCtrl.clear();
    _refreshData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Brahma', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Color(0xFF10B981))),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshData)],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(),
          _buildMealLogTab(),
          _buildTasksTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        selectedItemColor: const Color(0xFF10B981),
        unselectedItemColor: Colors.white54,
        backgroundColor: const Color(0xFF131622),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_outlined), label: 'Meals'),
          BottomNavigationBarItem(icon: Icon(Icons.check_circle_outline), label: 'Tasks'),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('PINNED GOAL', style: TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 11)),
                  SizedBox(height: 6),
                  Text('Daily Central Kitchen & Revenue Flow', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Ensure on-time hospital deliveries and track daily cash collection.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFF1E293B),
            child: ListTile(
              leading: const Icon(Icons.verified_user_outlined, color: Color(0xFF10B981)),
              title: const Text('Next 7 Days Covered', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
              subtitle: Text('Available Balance: ${_formatPaise(_liquidBalancePaise)}'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(Icons.nightlight_round, color: _nightCheckinDone ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
              title: const Text('Night Check-in'),
              subtitle: Text(_nightCheckinDone ? 'Recorded for today' : 'Pending daily money entry'),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                onPressed: () => setState(() => _nightCheckinDone = true),
                child: const Text('Record Now', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealLogTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('LOG HOSPITAL MEALS', style: TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 12),
                  TextField(controller: _hospitalCtrl, decoration: const InputDecoration(labelText: 'Hospital Name', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: _qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: _rateCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Rate (₹)', border: OutlineInputBorder()))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                      onPressed: _addMealEntry,
                      child: const Text('Save Dispatch Entry', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('RECENT DISPATCHES', style: TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _todayMeals.length,
            itemBuilder: (ctx, i) {
              final m = _todayMeals[i];
              return Card(
                child: ListTile(
                  title: Text(m['hospital_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${m['quantity']} meals @ ${_formatPaise(m['rate_paise'])}'),
                  trailing: Text(_formatPaise(m['total_paise']), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTasksTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(child: TextField(controller: _taskCtrl, decoration: const InputDecoration(hintText: 'New task...', border: OutlineInputBorder()))),
              const SizedBox(width: 8),
              IconButton.filled(style: IconButton.styleFrom(backgroundColor: const Color(0xFF10B981)), icon: const Icon(Icons.add, color: Colors.black), onPressed: _addTask),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _tasks.length,
            itemBuilder: (ctx, i) => ListTile(
              leading: const Icon(Icons.check_circle_outline, color: Color(0xFF10B981)),
              title: Text(_tasks[i]['title']),
            ),
          ),
        ),
      ],
    );
  }
}
