import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Analysis',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ExpenseApp(),
    );
  }
}

class ExpenseApp extends StatefulWidget {
  @override
  _ExpenseAppState createState() => _ExpenseAppState();
}

class _ExpenseAppState extends State<ExpenseApp> {
  int _selectedIndex = 0;
  File? _csvFile;
  List<ChartData> _chartData = [];
  Map<String, double> _categoryTotals = {};
  Map<String, Map<String, double>> _monthlyCategoryTotals = {};
  String _mostRepeatedName = '';
  bool _dataLoaded = false;
  double _totalExpense = 0.0;

  DateTime _selectedDate = DateTime.now();

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _pickCsvFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null) {
      setState(() {
        _csvFile = File(result.files.single.path!);
      });
      _analyzeData();
    }
  }

  void _analyzeData() async {
    if (_csvFile == null) return;

    try {
      final input = _csvFile!.openRead();
      final fields = await input
          .transform(utf8.decoder)
          .transform(const CsvToListConverter(eol: "\n"))
          .toList();

      if (fields.isEmpty || fields.length == 1) {
        print("No data or only header found in the CSV file.");
        return;
      }

      _categoryTotals = {};
      _monthlyCategoryTotals = {};
      Map<String, int> nameOccurrences = {};
      _totalExpense = 0.0;

      for (var i = 1; i < fields.length; i++) {
        // Start from 1 to skip the header row
        var row = fields[i];
        String category =
            row[2]?.toString() ?? 'Uncategorized'; // Category is the 3rd column
        double cost = double.tryParse(row[3]?.toString() ?? '0.0') ??
            0.0; // Cost is the 4th column
        String name =
            row[1]?.toString() ?? ''; // Name/Description is the 2nd column
        DateTime date =
            DateTime.parse(row[0].toString()); // Date is the 1st column
        // Calculate category-wise total
        _categoryTotals[category] = (_categoryTotals[category] ?? 0.0) + cost;
        _totalExpense += cost;

        // Calculate monthly category-wise totals
        String month = DateFormat('yyyy-MM').format(date);
        if (!_monthlyCategoryTotals.containsKey(month)) {
          _monthlyCategoryTotals[month] = {};
        }
        _monthlyCategoryTotals[month]![category] =
            (_monthlyCategoryTotals[month]![category] ?? 0.0) + cost;

        // Calculate most repeated name
        nameOccurrences[name] = (nameOccurrences[name] ?? 0) + 1;
      }

      _mostRepeatedName = nameOccurrences.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;

      setState(() {
        _chartData = _categoryTotals.entries
            .map((entry) => ChartData(entry.key, entry.value))
            .toList();
        _dataLoaded = true;
      });
    } catch (e) {
      print("Error while reading CSV file: $e");
    }
  }

  void _resetAndPickAnotherFile() {
    setState(() {
      _csvFile = null;
      _chartData = [];
      _categoryTotals = {};
      _monthlyCategoryTotals = {};
      _mostRepeatedName = '';
      _dataLoaded = false;
      _totalExpense = 0.0;
    });
    _pickCsvFile();
  }

  Widget _buildPieChart() {
    return SfCircularChart(
      title: ChartTitle(text: 'Category-wise Expense Breakdown (Pie Chart)'),
      legend: const Legend(isVisible: true),
      series: <CircularSeries>[
        PieSeries<ChartData, String>(
          dataSource: _chartData,
          xValueMapper: (ChartData data, _) => data.category,
          yValueMapper: (ChartData data, _) => data.amount,
          dataLabelMapper: (ChartData data, _) {
            if (_totalExpense == 0) {
              return '0%';
            }
            return '${((data.amount / _totalExpense) * 100).toStringAsFixed(1)}%';
          },
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            showZeroValue: false,
            labelPosition: ChartDataLabelPosition.outside,
            textStyle: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildBarChart() {
    // Sort the chart data by amount in descending order
    _chartData.sort((a, b) => b.amount.compareTo(a.amount));

    return SfCartesianChart(
      title: ChartTitle(text: 'Category-wise Expense Breakdown (Bar Chart)'),
      legend: const Legend(isVisible: false),
      primaryXAxis: CategoryAxis(),
      primaryYAxis: NumericAxis(
        title: AxisTitle(text: 'Amount'),
      ),
      series: <ChartSeries>[
        BarSeries<ChartData, String>(
          dataSource: _chartData,
          xValueMapper: (ChartData data, _) => data.category,
          yValueMapper: (ChartData data, _) => data.amount,
          dataLabelSettings: const DataLabelSettings(isVisible: true),
        ),
      ],
    );
  }

  Widget _buildAnalysisTab() {
    String selectedMonth = DateFormat('yyyy-MM').format(_selectedDate);
    Map<String, double> monthlyTotals =
        _monthlyCategoryTotals[selectedMonth] ?? {};

    // Calculate the overall monthly total
    double overallMonthlyTotal =
        monthlyTotals.values.fold(0.0, (sum, value) => sum + value);

    // Filter the data to get only the entries for the selected month
    List<List<dynamic>> selectedMonthData = _csvFile != null
        ? _csvFile!
            .readAsStringSync()
            .split('\n')
            .skip(1)
            .map((line) => line.split(','))
            .where((row) {
            DateTime date = DateTime.parse(row[0]);
            return DateFormat('yyyy-MM').format(date) == selectedMonth;
          }).toList()
        : [];

    // Group names and calculate totals for the selected month
    Map<String, double> nameTotals = {};
    for (var row in selectedMonthData) {
      String name = row[1]?.toString() ?? '';
      double cost = double.tryParse(row[3]?.toString() ?? '0.0') ?? 0.0;
      nameTotals[name] = (nameTotals[name] ?? 0.0) + cost;
    }

    // Sort category-wise totals in descending order by value
    var sortedCategoryTotals = _categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Sort monthly totals in descending order by value
    var sortedMonthlyTotals = monthlyTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Sort name totals in descending order by value
    var sortedNameTotals = nameTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Category-wise Totals:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            for (var entry in sortedCategoryTotals)
              Text('${entry.key}: ${entry.value.toStringAsFixed(2)}'),
            const SizedBox(height: 20),
            Text('Monthly Totals for ${selectedMonth}:',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            for (var entry in sortedMonthlyTotals)
              Text('${entry.key}: ${entry.value.toStringAsFixed(2)}'),
            const SizedBox(height: 10),
            Text(
                'Overall Monthly Total: ${overallMonthlyTotal.toStringAsFixed(2)}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Text('Name Totals for ${selectedMonth}:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            for (var entry in sortedNameTotals)
              Text('${entry.key}: ${entry.value.toStringAsFixed(2)}'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2101),
                  selectableDayPredicate: (DateTime val) {
                    return val.day == 1;
                  },
                  initialDatePickerMode: DatePickerMode.year,
                );
                if (pickedDate != null && pickedDate != _selectedDate) {
                  setState(() {
                    _selectedDate = DateTime(pickedDate.year, pickedDate.month);
                  });
                }
              },
              child: const Text('Select Month'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> _widgetOptions = <Widget>[
      _dataLoaded
          ? SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildPieChart(),
                  const SizedBox(height: 20),
                  _buildBarChart(),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _resetAndPickAnotherFile,
                    child: const Text('Pick Another CSV File'),
                  ),
                ],
              ),
            )
          : ElevatedButton(
              onPressed: _pickCsvFile,
              child: const Text('Pick CSV File'),
            ),
      _dataLoaded ? _buildAnalysisTab() : Container(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Analysis'),
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart),
            label: 'Charts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analysis',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class ChartData {
  ChartData(this.category, this.amount);
  final String category;
  final double amount;
}
