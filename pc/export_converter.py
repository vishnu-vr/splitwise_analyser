import pandas as pd
import os
from datetime import datetime # For parsing dates

def combine_all_expenses_from_folder(
    folder_path,
    output_file_name="All_My_Expenses_Combined.csv",
    splitwise_config={
        "your_name_column": "Vishnu Ramesh",
        "description_col_name": "Description",
        "category_col_name": "Category",
        "cost_col_name": "Cost",
        "currency_col_name": "Currency",
        "file_prefix": "splitwise", # Files starting with this prefix are Splitwise
        "date_col_name": "Date"
    },
    mymoney_config={
        "date_col_name": "TIME",
        "type_col_name": "TYPE", # To filter for expenses
        "amount_col_name": "AMOUNT",
        "category_col_name": "CATEGORY",
        "description_col_name": "NOTES", # Corresponds to Notes in My Money
        "currency": "INR", # Fixed currency for My Money
        "file_prefix": "mymoney" # Files starting with this prefix are My Money
    }
):
    """
    Reads multiple expense exports from a folder (Splitwise and My Money),
    filters and combines them into a single output file.

    Args:
        folder_path (str): Path to the folder containing your expense files.
        output_file_name (str): Name of the combined output CSV file.
        splitwise_config (dict): Configuration for Splitwise files.
        mymoney_config (dict): Configuration for My Money files.
    """
    all_combined_expenses = []
    supported_extensions = ('.csv', '.xlsx', '.xls')

    if not os.path.isdir(folder_path):
        print(f"Error: Folder not found at '{folder_path}'")
        return

    for filename in os.listdir(folder_path):
        file_path = os.path.join(folder_path, filename)
        
        # Determine file type based on prefix or other criteria
        is_splitwise = filename.lower().startswith(splitwise_config["file_prefix"].lower())
        is_mymoney = filename.lower().startswith(mymoney_config["file_prefix"].lower())
        
        if not (is_splitwise or is_mymoney) or not filename.lower().endswith(supported_extensions):
            print(f"Skipping non-supported or unidentifiable file: {filename}")
            continue

        print(f"Processing file: {filename} (Type: {'Splitwise' if is_splitwise else 'My Money'})")

        try:
            if filename.lower().endswith('.csv'):
                df = pd.read_csv(file_path)
            else: # .xlsx or .xls
                df = pd.read_excel(file_path, sheet_name=0) # Read the first sheet by default
        except Exception as e:
            print(f"  Skipping '{filename}' due to read error: {e}")
            continue

        # --- Process Splitwise File ---
        if is_splitwise:
            config = splitwise_config
            if config["your_name_column"] not in df.columns:
                print(f"  Warning: Splitwise column '{config['your_name_column']}' not found in '{filename}'. Skipping this file.")
                continue

            # Ensure other required columns exist, print warnings if not
            required_cols_splitwise = [config["description_col_name"], config["cost_col_name"],
                                       config["currency_col_name"], config["category_col_name"],
                                       config["date_col_name"]]
            for col in required_cols_splitwise:
                if col not in df.columns:
                    raise(f"  Warning: Splitwise file '{filename}' missing column '{col}'. Using empty string/0.")

            for index, row in df.iterrows():
                description = str(row.get(config["description_col_name"], '')).lower()
                cost = row.get(config["cost_col_name"], 0)
                currency = row.get(config["currency_col_name"], '')
                category = row.get(config["category_col_name"], '')
                date_str = str(row.get(config["date_col_name"], ''))

                vishnu_expense_raw = row.get(config["your_name_column"], 0)

                vishnu_expense = float(vishnu_expense_raw)

                cost = float(cost)

                if "paid" in description or vishnu_expense == 0:
                    continue

                if vishnu_expense < 0:
                    actual_expense = abs(vishnu_expense)
                else:
                    # This logic assumes 'cost' is total and 'vishnu_expense' is Vishnu's share that needs to be subtracted
                    # from the total to get someone else's, OR if 'vishnu_expense' is already Vishnu's share.
                    # Re-confirm: If 'Vishnu Ramesh' column *is* your direct positive share, then actual_expense = vishnu_expense.
                    # If it's a "cost minus someone else's share" scenario for your own, then cost - vishnu_expense.
                    # Based on the original Google Apps Script, it implied cost - vishnu_expense for positive values.
                    actual_expense = cost - vishnu_expense

                all_combined_expenses.append({
                    "Date": date_str,
                    "Description": str(row.get(config["description_col_name"], '')), # Original case
                    "Category": str(row.get(config["category_col_name"], '')),
                    # "Cost": cost,
                    # "Currency": currency,
                    "Your Expense": actual_expense,
                    "Source App": "Splitwise",
                    "Source File": filename
                })

        # --- Process My Money File ---
        elif is_mymoney:
            config = mymoney_config
            # Basic checks for My Money columns
            required_cols_mymoney = [config["date_col_name"], config["type_col_name"],
                                     config["amount_col_name"], config["category_col_name"],
                                     config["description_col_name"]]
            for col in required_cols_mymoney:
                if col not in df.columns:
                    raise(f"  Warning: My Money file '{filename}' missing critical column '{col}'. Skipping this file.")
                    # continue # Skip if a critical column is missing

            for index, row in df.iterrows():
                try:
                    record_type = str(row.get(config["type_col_name"], '')).lower()
                    amount_raw = row.get(config["amount_col_name"], 0)
                    
                    # Ensure amount is numeric, handle commas if present
                    if isinstance(amount_raw, str):
                        amount_raw = amount_raw.replace(',', '')
                    amount = float(amount_raw)

                    # Only include "(-) Expense" type transactions
                    if "(-) expense" not in record_type:
                        continue

                    # My Money amount is directly your expense
                    actual_expense = abs(amount) # Use absolute in case it's negative in export

                    # Parse and format date (e.g., "Dec 01, 2024 3:17 PM" to a standard date format)
                    date_time_str = str(row.get(config["date_col_name"], ''))
                    try:
                        # Assuming the format "Mon DD, YYYY HH:MM AM/PM"
                        parsed_date = datetime.strptime(date_time_str, "%b %d, %Y %I:%M %p")
                        formatted_date = parsed_date.strftime("%Y-%m-%d") # YYYY-MM-DD for consistency
                    except ValueError:
                        formatted_date = date_time_str # Keep original if parsing fails

                    all_combined_expenses.append({
                        "Date": formatted_date,
                        "Description": str(row.get(config["description_col_name"], '')),
                        "Category": str(row.get(config["category_col_name"], '')),
                        # "Cost": actual_expense, # For personal expense, total cost is your expense
                        # "Currency": config["currency"], # Fixed INR
                        "Your Expense": actual_expense,
                        "Source App": "My Money",
                        "Source File": filename
                    })
                except (ValueError, TypeError) as e:
                    print(f"  Warning: Skipping row {index+2} in '{filename}' due to data error: {e}. Row data: {row.to_dict()}")
                    continue # Skip problematic rows

    if not all_combined_expenses:
        print("No expenses found across all files after filtering.")
        return

    # Create a new DataFrame from all combined filtered expenses
    output_df = pd.DataFrame(all_combined_expenses)

    # Sort by Date for better readability
    output_df['Date'] = pd.to_datetime(output_df['Date'], errors='coerce') # Convert to datetime, coerce errors to NaT
    output_df = output_df.sort_values(by='Date').dropna(subset=['Date']) # Sort and drop rows where date parsing failed
    output_df['Date'] = output_df['Date'].dt.strftime('%Y-%m-%d') # Convert back to string for consistent output format

    # Save to CSV
    try:
        output_df.to_csv(output_file_name, index=False)
        print(f"\nSuccessfully extracted and combined all expenses to '{output_file_name}'")
    except Exception as e:
        print(f"An error occurred while saving the combined output file: {e}")

# --- How to use the script ---

# IMPORTANT:
# 1. Replace "C:\\Users\\YourUser\\Downloads\\ExpenseExports" with the actual
#    path to the folder where you save ALL your expense export files.
# 2. RENAME your files so they have the correct prefixes!
#    - Splitwise exports: e.g., "splitwise_jan_2024.csv", "splitwise_feb_2024.xlsx"
#    - My Money exports: e.g., "mymoney_2024_Q1.csv", "mymoney_daily.xls"
# 3. Verify the column names in the `splitwise_config` and `mymoney_config`
#    dictionaries to ensure they exactly match the headers in your export files.

combine_all_expenses_from_folder(
    folder_path="C:\\data\\vishnu\\spitwise_analysis\\pc\\expenses", # <--- CHANGE THIS FOLDER PATH
    output_file_name="All_My_Expenses_Combined.csv"
)