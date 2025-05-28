function filterVishnuExpenses() {
  var restart = 0;
  
  var sheet = SpreadsheetApp.getActiveSpreadsheet();
  var dataSheet = sheet.getSheetByName("Sheet1"); // Change this if your sheet has a different name
  var newSheetName = "Vishnu_Expenses";
  
  // Check if the sheet already exists
  var newSheet = sheet.getSheetByName(newSheetName);
  
  if (newSheet && restart) {
    sheet.deleteSheet(newSheet);
    newSheet = sheet.insertSheet(newSheetName);
    // Headers for new sheet
    newSheet.appendRow(["Date", "Description", "Category", "Cost", "Currency", "Your Expense"]);
  }
  
  if (!newSheet) {
    newSheet = sheet.insertSheet(newSheetName);
    // Headers for new sheet
    newSheet.appendRow(["Date", "Description", "Category", "Cost", "Currency", "Your Expense"]);
  }
  
  // Get data from main sheet
  var data = dataSheet.getDataRange().getValues();
  
  var vishnuColumnIndex = data[0].indexOf("Vishnu Ramesh"); // Locate Vishnu's column
  if (vishnuColumnIndex == -1) {
    SpreadsheetApp.getUi().alert("Column 'Vishnu Ramesh' not found!");
    return;
  }
  
  var properties = PropertiesService.getScriptProperties();
  var lastProcessedRow = properties.getProperty('lastProcessedRow');
  var startRow = lastProcessedRow ? parseInt(lastProcessedRow) + 1 : 1;
  if (restart) startRow = 1;
  
  var maxExecutionTime = 5 * 60 * 1000; // 5 minutes
  var startTime = new Date().getTime();
  
  for (var i = startRow; i < data.length; i++) {
    var currentTime = new Date().getTime();
    if (currentTime - startTime > maxExecutionTime) {
      // Set a time-based trigger to resume processing
      ScriptApp.newTrigger('filterVishnuExpenses')
        .timeBased()
        .after(1 * 60 * 1000) // 1 minute
        .create();
      properties.setProperty('lastProcessedRow', i - 1);
      return;
    }
    
    console.log("Processing row: " + (i + 1));
    var row = data[i];
    var description = row[1]; // Description
    var cost = row[3]; // Total cost
    var currency = row[4]; // Currency
    var vishnuExpense = row[vishnuColumnIndex]; // Vishnu's share
    
    // Skip repayment transactions (e.g., "Vishnu R paid Jerin")
    if (description.includes("paid") || vishnuExpense == 0) {
      continue;
    }
    
    // Compute actual expense
    var actualExpense = vishnuExpense < 0 ? Math.abs(vishnuExpense) : cost - vishnuExpense;
    
    // Append filtered data
    newSheet.appendRow([row[0], description, row[2], cost, currency, actualExpense]);
    
    // Save the last processed row
    properties.setProperty('lastProcessedRow', i);
  }
  
  // Clear the last processed row property after completion
  properties.deleteProperty('lastProcessedRow');
}

function calculateMonthlyExpenses() {
  var sheet = SpreadsheetApp.getActiveSpreadsheet();
  var expenseSheet = sheet.getSheetByName("Vishnu_Expenses");
  if (!expenseSheet) {
    SpreadsheetApp.getUi().alert("Run 'filterVishnuExpenses' first to generate data.");
    return;
  }

  var data = expenseSheet.getDataRange().getValues();
  var monthlyExpenses = {};

  for (var i = 1; i < data.length; i++) { // Start from 1 to skip headers
    var row = data[i];
    var date = new Date(row[0]);
    var month = date.getFullYear() + '-' + (date.getMonth() + 1); // Format: YYYY-MM
    var expense = row[5];

    if (!monthlyExpenses[month]) {
      monthlyExpenses[month] = 0;
    }
    monthlyExpenses[month] += expense;
  }

  var resultSheetName = "Monthly_Expenses";
  var resultSheet = sheet.getSheetByName(resultSheetName);
  if (resultSheet) {
    sheet.deleteSheet(resultSheet);
  }
  resultSheet = sheet.insertSheet(resultSheetName);
  resultSheet.appendRow(["Month", "Total Expense"]);

  for (var month in monthlyExpenses) {
    resultSheet.appendRow([month, monthlyExpenses[month]]);
  }

  createMonthlyExpenseChart(resultSheet);
}

function calculateMonthlyExpensesFromSheet2() {
  var sheet = SpreadsheetApp.getActiveSpreadsheet();
  var dataSheet = sheet.getSheetByName("Sheet2");
  if (!dataSheet) {
    SpreadsheetApp.getUi().alert("Sheet 'Sheet2' not found!");
    return;
  }

  var data = dataSheet.getDataRange().getValues();
  var monthlyExpenses = {};

  for (var i = 1; i < data.length; i++) { // Start from 1 to skip headers
    var row = data[i];
    var date = new Date(row[0]);
    var month = date.getFullYear() + '-' + (date.getMonth() + 1); // Format: YYYY-MM
    var expense = parseFloat(row[2]); // Amount

    if (!monthlyExpenses[month]) {
      monthlyExpenses[month] = 0;
    }
    monthlyExpenses[month] += expense;
  }

  var resultSheetName = "Monthly_Expenses_Sheet2";
  var resultSheet = sheet.getSheetByName(resultSheetName);
  if (resultSheet) {
    sheet.deleteSheet(resultSheet);
  }
  resultSheet = sheet.insertSheet(resultSheetName);
  resultSheet.appendRow(["Month", "Total Expense"]);

  for (var month in monthlyExpenses) {
    resultSheet.appendRow([month, monthlyExpenses[month]]);
  }

  createMonthlyExpenseChart(resultSheet);
}

function createMonthlyExpenseChart(resultSheet) {
  var range = resultSheet.getDataRange();
  var chart = resultSheet.newChart()
    .setChartType(Charts.ChartType.LINE)
    .addRange(range)
    .setPosition(5, 5, 0, 0)
    .setOption('title', 'Monthly Expense Trend')
    .setOption('hAxis.title', 'Month')
    .setOption('vAxis.title', 'Total Expense (INR)')
    .build();

  resultSheet.insertChart(chart);
}

function calculateTotalMonthlyExpenses() {
  var sheet = SpreadsheetApp.getActiveSpreadsheet();
  var monthlyExpensesSheet1 = sheet.getSheetByName("Monthly_Expenses");
  var monthlyExpensesSheet2 = sheet.getSheetByName("Monthly_Expenses_Sheet2");

  if (!monthlyExpensesSheet1 || !monthlyExpensesSheet2) {
    SpreadsheetApp.getUi().alert("Run 'calculateMonthlyExpenses' and 'calculateMonthlyExpensesFromSheet2' first to generate data.");
    return;
  }

  var data1 = monthlyExpensesSheet1.getDataRange().getValues();
  var data2 = monthlyExpensesSheet2.getDataRange().getValues();
  var totalMonthlyExpenses = {};

  // Combine data from Monthly_Expenses
  for (var i = 1; i < data1.length; i++) { // Start from 1 to skip headers
    var row = data1[i];
    var month = row[0];
    var expense = row[1];

    if (!totalMonthlyExpenses[month]) {
      totalMonthlyExpenses[month] = 0;
    }
    totalMonthlyExpenses[month] += expense;
  }

  // Combine data from Monthly_Expenses_Sheet2
  for (var i = 1; i < data2.length; i++) { // Start from 1 to skip headers
    var row = data2[i];
    var month = row[0];
    var expense = row[1];

    if (!totalMonthlyExpenses[month]) {
      totalMonthlyExpenses[month] = 0;
    }
    totalMonthlyExpenses[month] += expense;
  }

  var resultSheetName = "Total_Monthly_Expenses";
  var resultSheet = sheet.getSheetByName(resultSheetName);
  if (resultSheet) {
    sheet.deleteSheet(resultSheet);
  }
  resultSheet = sheet.insertSheet(resultSheetName);
  resultSheet.appendRow(["Month", "Total Expense"]);

  for (var month in totalMonthlyExpenses) {
    resultSheet.appendRow([month, totalMonthlyExpenses[month]]);
  }

  createMonthlyExpenseChart(resultSheet);
}
