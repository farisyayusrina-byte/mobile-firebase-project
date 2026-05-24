import '../models/bill.dart';

/// Sample bills for demo / presentation (no receipt images).
class DemoBillSeed {
  const DemoBillSeed({
    required this.title,
    required this.total,
    required this.category,
    required this.status,
    required this.participants,
    required this.items,
    required this.createdAt,
    this.splitMode = 'byItems',
  });

  final String title;
  final double total;
  final String category;
  final String status;
  final List<String> participants;
  final List<BillItem> items;
  final DateTime createdAt;
  final String splitMode;

  static List<DemoBillSeed> samples() {
    final now = DateTime.now();
    final y = now.year;
    final m = now.month;

    return [
      DemoBillSeed(
        title: 'Mamak Stall — Dinner',
        total: 85.40,
        category: 'Food & Dining',
        status: 'split',
        participants: const ['You', 'Ahmad', 'Sarah'],
        createdAt: DateTime(y, m, now.day.clamp(3, 28)),
        items: const [
          BillItem(name: 'Nasi Goreng', price: 12.50, assignedTo: 'You'),
          BillItem(name: 'Teh Tarik x3', price: 10.50, assignedTo: 'Ahmad'),
          BillItem(name: 'Mee Goreng x2', price: 24.00, assignedTo: 'Sarah'),
          BillItem(name: 'Satay', price: 38.40, assignedTo: 'You'),
        ],
      ),
      DemoBillSeed(
        title: 'Grab — Airport trip',
        total: 45.50,
        category: 'Transport',
        status: 'personal',
        participants: const ['You'],
        createdAt: DateTime(y, m, (now.day - 2).clamp(1, 28)),
        items: const [
          BillItem(name: 'Grab fare', price: 45.50, assignedTo: ''),
        ],
      ),
      DemoBillSeed(
        title: 'Lotus Groceries',
        total: 298.00,
        category: 'Groceries',
        status: 'pending',
        participants: const ['You', 'Mei Ling'],
        createdAt: DateTime(y, m, (now.day - 4).clamp(1, 28)),
        items: const [
          BillItem(name: 'Vegetables', price: 45.00, assignedTo: 'You'),
          BillItem(name: 'Chicken & meat', price: 89.00, assignedTo: ''),
          BillItem(name: 'Snacks & drinks', price: 164.00, assignedTo: 'Mei Ling'),
        ],
      ),
      DemoBillSeed(
        title: 'Uniqlo — Mid-season sale',
        total: 156.00,
        category: 'Shopping',
        status: 'split',
        participants: const ['You', 'Sarah'],
        createdAt: DateTime(y, m, (now.day - 6).clamp(1, 28)),
        items: const [
          BillItem(name: 'T-shirt', price: 49.90, assignedTo: 'You'),
          BillItem(name: 'Pants', price: 106.10, assignedTo: 'Sarah'),
        ],
      ),
      DemoBillSeed(
        title: 'TGV — Movie night',
        total: 89.00,
        category: 'Entertainment',
        status: 'split',
        participants: const ['You', 'Ahmad', 'Sarah', 'Mei Ling'],
        createdAt: DateTime(y, m, (now.day - 8).clamp(1, 28)),
        items: const [
          BillItem(name: 'Tickets x4', price: 68.00, assignedTo: 'You'),
          BillItem(name: 'Popcorn combo', price: 21.00, assignedTo: 'Ahmad'),
        ],
        splitMode: 'equally',
      ),
      DemoBillSeed(
        title: 'Shell Station — Petrol',
        total: 189.00,
        category: 'Transport',
        status: 'personal',
        participants: const ['You'],
        createdAt: DateTime(y, m, (now.day - 10).clamp(1, 28)),
        items: const [
          BillItem(name: 'RON95', price: 189.00, assignedTo: ''),
        ],
      ),
      DemoBillSeed(
        title: 'Restoran Seafood — Group lunch',
        total: 371.40,
        category: 'Food & Dining',
        status: 'split',
        participants: const ['You', 'Ahmad', 'Sarah', 'Mei Ling'],
        createdAt: DateTime(y, m, (now.day - 12).clamp(1, 28)),
        items: const [
          BillItem(name: 'Set seafood A', price: 128.00, assignedTo: 'You'),
          BillItem(name: 'Set seafood B', price: 115.40, assignedTo: 'Ahmad'),
          BillItem(name: 'Drinks & sides', price: 128.00, assignedTo: 'Sarah'),
        ],
      ),
      DemoBillSeed(
        title: 'Coffee Bean — Brunch',
        total: 71.00,
        category: 'Food & Dining',
        status: 'split',
        participants: const ['You', 'Sarah'],
        createdAt: DateTime(y, m, (now.day - 14).clamp(1, 28)),
        items: const [
          BillItem(name: 'Latte x2', price: 36.00, assignedTo: 'You'),
          BillItem(name: 'Pastries', price: 35.00, assignedTo: 'Sarah'),
        ],
      ),
      // Last month — for "vs last month" on Expenses
      DemoBillSeed(
        title: 'April — Family dinner',
        total: 420.00,
        category: 'Food & Dining',
        status: 'split',
        participants: const ['You', 'Ahmad'],
        createdAt: DateTime(y, m - 1, 22),
        items: const [
          BillItem(name: 'Dinner set', price: 420.00, assignedTo: 'You'),
        ],
      ),
      DemoBillSeed(
        title: 'April — Grab weekly',
        total: 280.50,
        category: 'Transport',
        status: 'personal',
        participants: const ['You'],
        createdAt: DateTime(y, m - 1, 15),
        items: const [
          BillItem(name: 'Rides', price: 280.50, assignedTo: ''),
        ],
      ),
      DemoBillSeed(
        title: 'April — Grocery run',
        total: 350.00,
        category: 'Groceries',
        status: 'split',
        participants: const ['You', 'Mei Ling'],
        createdAt: DateTime(y, m - 1, 8),
        items: const [
          BillItem(name: 'Monthly groceries', price: 350.00, assignedTo: 'You'),
        ],
      ),
      DemoBillSeed(
        title: 'April — Shopping mall',
        total: 429.80,
        category: 'Shopping',
        status: 'pending',
        participants: const ['You', 'Sarah'],
        createdAt: DateTime(y, m - 1, 3),
        items: const [
          BillItem(name: 'Clothes', price: 429.80, assignedTo: ''),
        ],
      ),
      // Earlier months for monthly chart (Jan–Apr totals)
      DemoBillSeed(
        title: 'March — Team lunch',
        total: 245.00,
        category: 'Food & Dining',
        status: 'split',
        participants: const ['You', 'Ahmad'],
        createdAt: DateTime(y, 3, 18),
        items: const [
          BillItem(name: 'Lunch', price: 245.00, assignedTo: 'You'),
        ],
      ),
      DemoBillSeed(
        title: 'February — Transport',
        total: 180.00,
        category: 'Transport',
        status: 'personal',
        participants: const ['You'],
        createdAt: DateTime(y, 2, 10),
        items: const [
          BillItem(name: 'Petrol', price: 180.00, assignedTo: ''),
        ],
      ),
      DemoBillSeed(
        title: 'January — New year dinner',
        total: 520.00,
        category: 'Food & Dining',
        status: 'split',
        participants: const ['You', 'Sarah', 'Ahmad'],
        createdAt: DateTime(y, 1, 5),
        items: const [
          BillItem(name: 'Banquet', price: 520.00, assignedTo: 'You'),
        ],
      ),
    ];
  }
}
