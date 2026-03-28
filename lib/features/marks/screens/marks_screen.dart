import 'package:flutter/material.dart';
import '../../../../core/utils/academic_utils.dart'; // We use the grading functions here
import '../../../../core/utils/validator_service.dart';

class MarksScreen extends StatefulWidget {
  const MarksScreen({Key? key}) : super(key: key);

  @override
  State<MarksScreen> createState() => _MarksScreenState();
}

class _MarksScreenState extends State<MarksScreen> {
  final _marksController = TextEditingController();
  final _totalController = TextEditingController();
  String _computedGrade = '-';
  String _computedPercentage = '-';

  void _generateReport() {
    try {
      final marks = double.parse(_marksController.text);
      final total = double.parse(_totalController.text);

      // Defend against logical impossibilities (marks > total) via Validator layer
      ValidatorService.validateMarks(marks, total);

      final percentage = AcademicUtils.calculatePercentage(marks, total);
      final grade = AcademicUtils.generateGrade(percentage);

      setState(() {
        _computedPercentage = '${percentage.toStringAsFixed(1)}%';
        _computedGrade = grade;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report Generated Successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll("Exception:", "")), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Marks Evaluation')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
             TextField(controller: _marksController, decoration: const InputDecoration(labelText: 'Marks Obtained'), keyboardType: TextInputType.number),
             TextField(controller: _totalController, decoration: const InputDecoration(labelText: 'Total Marks'), keyboardType: TextInputType.number),
             const SizedBox(height: 20),
             ElevatedButton(
                onPressed: _generateReport,
                child: const Text('Generate Report Card'),
             ),
             const SizedBox(height: 40),
             if (_computedGrade != '-')
             Card(
               color: Colors.blue.withOpacity(0.1),
               child: Padding(
                 padding: const EdgeInsets.all(24.0),
                 child: Column(
                   children: [
                      const Text('Report Card', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const Divider(),
                      Text('Percentage: $_computedPercentage', style: const TextStyle(fontSize: 18)),
                      Text('Grade: $_computedGrade', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
                   ],
                 ),
               ),
             )
          ],
        ),
      ),
    );
  }
}
