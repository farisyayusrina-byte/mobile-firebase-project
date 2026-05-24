import '../models/bill.dart';

class PersonBalance {
  const PersonBalance({
    required this.name,
    required this.theyOweYou,
    required this.youOweThem,
  });

  final String name;
  final double theyOweYou;
  final double youOweThem;

  /// Positive = they owe you more than you owe them.
  double get net => theyOweYou - youOweThem;

  bool get isSettled => theyOweYou < 0.01 && youOweThem < 0.01;
}

/// Balance for one group on Home.
class GroupBalance {
  const GroupBalance({
    required this.othersOweYou,
    required this.pendingUncollected,
    required this.hasBills,
    required this.allSettled,
  });

  /// Friends still owe you (you paid the bill).
  final double othersOweYou;
  /// Bills not fully split yet (no / partial assignments).
  final double pendingUncollected;
  final bool hasBills;
  final bool allSettled;

  bool get isEmpty => !hasBills;

  bool get isFullySettled =>
      hasBills && allSettled && othersOweYou < 0.01 && pendingUncollected < 0.01;
}

class SettlementSummary {
  const SettlementSummary({
    required this.youOwe,
    required this.owedToYou,
    required this.pendingUncollected,
    required this.people,
    required this.unsettledBills,
  });

  final double youOwe;
  final double owedToYou;
  final double pendingUncollected;
  final List<PersonBalance> people;
  final List<Bill> unsettledBills;

  double get netBalance => owedToYou - youOwe;
}

class SettlementCalculator {
  static const defaultSelfLabel = 'You';

  static bool isSelf(String name, {String? selfName}) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return false;
    if (n == 'you') return true;
    final custom = selfName?.trim().toLowerCase();
    if (custom != null && custom.isNotEmpty && n == custom) return true;
    return false;
  }

  static List<Bill> activeBills(List<Bill> bills) =>
      bills.where((b) => b.status != 'settled').toList();

  /// How much others owe you on this bill (you are the payer).
  static double othersOweOnBill(Bill bill, {String? selfName}) {
    if (bill.splitMode == 'equally' && bill.participants.length > 1) {
      final share = bill.total / bill.participants.length;
      final others = bill.participants.where((p) => !isSelf(p, selfName: selfName));
      return share * others.length;
    }

    var others = 0.0;
    for (final item in bill.items) {
      final who = item.assignedTo.trim();
      if (who.isEmpty || isSelf(who, selfName: selfName)) continue;
      others += item.price;
    }

    final itemsSum = bill.items.fold<double>(0, (s, i) => s + i.price);
    final gap = bill.total - itemsSum;
    if (gap > 0.01 && bill.participants.isNotEmpty) {
      final othersCount =
          bill.participants.where((p) => !isSelf(p, selfName: selfName)).length;
      if (othersCount > 0) {
        others += gap * (othersCount / bill.participants.length);
      }
    }

    return others;
  }

  static GroupBalance groupBalance(
    List<Bill> groupBills, {
    String? selfName,
  }) {
    if (groupBills.isEmpty) {
      return const GroupBalance(
        othersOweYou: 0,
        pendingUncollected: 0,
        hasBills: false,
        allSettled: true,
      );
    }

    final active = activeBills(groupBills);
    if (active.isEmpty) {
      return GroupBalance(
        othersOweYou: 0,
        pendingUncollected: 0,
        hasBills: true,
        allSettled: true,
      );
    }

    var othersOwe = 0.0;
    var pending = 0.0;

    for (final bill in active) {
      othersOwe += othersOweOnBill(bill, selfName: selfName);
      if (bill.status == 'pending') {
        pending += bill.total;
      }
    }

    return GroupBalance(
      othersOweYou: othersOwe,
      pendingUncollected: pending,
      hasBills: true,
      allSettled: false,
    );
  }

  static SettlementSummary fromBills(
    List<Bill> bills, {
    String? selfName,
  }) {
    final active = activeBills(bills);
    final owedToYou = <String, double>{};
    final youOwe = <String, double>{};

    for (final bill in active) {
      _applyBill(bill, owedToYou, youOwe, selfName: selfName);
    }

    final names = <String>{...owedToYou.keys, ...youOwe.keys}
      ..removeWhere((n) => isSelf(n, selfName: selfName));

    final people = names
        .map(
          (name) => PersonBalance(
            name: name,
            theyOweYou: owedToYou[name] ?? 0,
            youOweThem: youOwe[name] ?? 0,
          ),
        )
        .where((p) => !p.isSettled)
        .toList()
      ..sort((a, b) => b.net.compareTo(a.net));

    final totalOwedToYou = owedToYou.values.fold<double>(0, (s, v) => s + v);
    final totalYouOwe = youOwe.values.fold<double>(0, (s, v) => s + v);

    var pendingUncollected = 0.0;
    for (final bill in active) {
      if (bill.status == 'pending') {
        pendingUncollected += bill.total;
      }
    }

    final unsettled = active
        .where((b) => b.status == 'pending' || b.status == 'split')
        .toList();

    return SettlementSummary(
      youOwe: totalYouOwe,
      owedToYou: totalOwedToYou,
      pendingUncollected: pendingUncollected,
      people: people,
      unsettledBills: unsettled,
    );
  }

  static void _applyBill(
    Bill bill,
    Map<String, double> owedToYou,
    Map<String, double> youOwe,
    {String? selfName}
  ) {
    final others = othersOweOnBill(bill, selfName: selfName);
    if (others > 0) {
      if (bill.splitMode == 'equally' && bill.participants.length > 1) {
        final share = bill.total / bill.participants.length;
        for (final person in bill.participants) {
          if (isSelf(person, selfName: selfName)) continue;
          owedToYou[person] = (owedToYou[person] ?? 0) + share;
        }
      } else {
        for (final item in bill.items) {
          final who = item.assignedTo.trim();
          if (who.isEmpty || isSelf(who, selfName: selfName)) continue;
          owedToYou[who] = (owedToYou[who] ?? 0) + item.price;
        }
        final itemsSum = bill.items.fold<double>(0, (s, i) => s + i.price);
        final gap = bill.total - itemsSum;
        if (gap > 0.01 && bill.participants.isNotEmpty) {
          final othersList = bill.participants
              .where((p) => !isSelf(p, selfName: selfName))
              .toList();
          if (othersList.isNotEmpty) {
            final each = gap / othersList.length;
            for (final p in othersList) {
              owedToYou[p] = (owedToYou[p] ?? 0) + each;
            }
          }
        }
      }
    }
  }

  static List<Bill> billsForPerson(
    List<Bill> bills,
    String personName, {
    String? selfName,
  }) {
    if (isSelf(personName, selfName: selfName)) return [];

    return bills.where((bill) {
      if (bill.status == 'settled') return false;
      if (bill.splitMode == 'equally') {
        return bill.participants.any(
          (p) => p.toLowerCase() == personName.toLowerCase(),
        );
      }
      return bill.items.any(
        (i) => i.assignedTo.toLowerCase() == personName.toLowerCase(),
      );
    }).toList();
  }

}
