# Splitwise Expense Analysis App

This is a Flutter-based expense analysis app that takes a CSV export from Splitwise, analyzes the data, and visualizes key insights such as category-wise expenses, monthly expense trends, and more.

## Features

- **Category-wise Expense Breakdown (Donut Chart)**: Displays the top 4 expense categories in a donut chart for easy visualization.
- **Category-wise Expense Breakdown (Bar Chart)**: Shows a detailed breakdown of expenses across all categories.
- **Monthly Expense Trend (Line Chart)**: Visualizes how expenses change month-to-month.
- **Detailed Analysis Tab**: 
  - Shows category-wise totals.
  - Displays monthly totals and overall monthly expense.
  - Groups and shows expenses by name for the selected month.

## How to Run the App

1. **Clone the Repository**:
    ```bash
    git clone <your-repo-url>
    cd splitwise_expense_analysis_app
    ```

2. **Install Dependencies**:
    Ensure you have Flutter installed. Then, run:
    ```bash
    flutter pub get
    ```

3. **Run the App**:
    ```bash
    flutter run
    ```

4. **Pick a CSV File**:
    The app allows you to pick a CSV file exported from Splitwise. The analysis will automatically adjust based on the selected file.

## CSV File Requirements

The app expects a CSV file with the following structure:
- **Date**: The date of the expense.
- **Name/Description**: The name or description of the expense.
- **Category**: The category the expense falls under.
- **Amount**: The cost of the expense.

Example:
```csv
Date,Name,Category,Amount
2024-08-01,Dinner,Dining out,50.00
2024-08-02,Bus Ticket,Transport,20.00
...