import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/split_bill_data.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'expenses_screen.dart';
import 'history_screen.dart';
import 'scan_screen.dart';
import 'split_bill_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.user});

  final User user;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  SplitBillData? _splitBillData;

  void _openSplitBill(SplitBillData data) {
    setState(() {
      _splitBillData = data;
      _currentIndex = 2;
    });
  }

  void _onBillSaved() {
    setState(() {
      _splitBillData = null;
      _currentIndex = 3;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bill saved to your account')),
    );
  }

  void _goToScan() {
    setState(() => _currentIndex = 1);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      HomeScreen(user: widget.user),
      ScanScreen(
        userId: widget.user.uid,
        onSplitBill: _openSplitBill,
      ),
      SplitBillScreen(
        userId: widget.user.uid,
        fromDisplayName:
            widget.user.displayName ?? widget.user.email?.split('@').first ?? 'You',
        data: _splitBillData,
        onScanReceipt: _goToScan,
        onBillSaved: _onBillSaved,
      ),
      HistoryScreen(user: widget.user),
      ExpensesScreen(user: widget.user),
    ];

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: tabs[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  selected: _currentIndex == 0,
                  onTap: () => setState(() => _currentIndex = 0),
                ),
                _NavItem(
                  icon: Icons.camera_alt_outlined,
                  label: 'Scan',
                  selected: _currentIndex == 1,
                  onTap: () => setState(() => _currentIndex = 1),
                ),
                _NavItem(
                  icon: Icons.receipt_long_outlined,
                  label: 'Split',
                  selected: _currentIndex == 2,
                  onTap: () => setState(() => _currentIndex = 2),
                ),
                _NavItem(
                  icon: Icons.history,
                  label: 'History',
                  selected: _currentIndex == 3,
                  onTap: () => setState(() => _currentIndex = 3),
                ),
                _NavItem(
                  icon: Icons.pie_chart_outline,
                  label: 'Expenses',
                  selected: _currentIndex == 4,
                  onTap: () => setState(() => _currentIndex = 4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: selected ? Colors.white : Colors.grey.shade600,
              size: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected ? AppColors.primary : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
