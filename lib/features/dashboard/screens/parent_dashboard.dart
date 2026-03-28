import 'package:flutter/material.dart';

class ParentDashboard extends StatelessWidget {
  const ParentDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Child\'s Profile',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // ── Info Cards ──
            _InfoCard(
              title: 'Attendance',
              value: '92%',
              icon: Icons.check_circle_rounded,
              color: Colors.green,
              status: 'Good Standing',
            ),
            const SizedBox(height: 12),
            _InfoCard(
              title: 'Fee Status',
              value: '₹5,000 Due',
              icon: Icons.payments_rounded,
              color: Colors.red,
              status: 'Overdue',
            ),
            const SizedBox(height: 12),
            _InfoCard(
              title: 'Last Exam',
              value: 'Grade A',
              icon: Icons.grading_rounded,
              color: Colors.blue,
              status: 'Top Performer',
            ),
            const SizedBox(height: 12),
            _InfoCard(
              title: 'Notices',
              value: '2 New',
              icon: Icons.notifications_rounded,
              color: Colors.orange,
              status: 'Check Now',
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String status;

  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                const SizedBox(height: 4),
                Text(value,
                    style: TextStyle(
                        color: color,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Chip(
            label: Text(status,
                style: TextStyle(color: color, fontSize: 10)),
            backgroundColor: color.withOpacity(0.1),
            side: BorderSide.none,
          ),
        ],
      ),
    );
  }
}
