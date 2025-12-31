import pandas as pd

# Data for Restaurant Sheet
restaurant_data = [
    {"Feature": "Dine-In Management", "Description": "Table service workflow with visual layout and status tracking."},
    {"Feature": "Active Orders (KOT)", "Description": "View and manage running Kitchen Order Tickets and open tables."},
    {"Feature": "Online Orders", "Description": "Dedicated tabs for In-Progress, Completed, and Missed online orders."},
    {"Feature": "Item Customization", "Description": "Support for Variants, Extras, Choices, and Notes on order items."},
    {"Feature": "Menu Management", "Description": "Create and organize Categories, Items, Variants, and Add-ons."},
    {"Feature": "Stock Management", "Description": "Track current inventory levels and view stock history logs."},
    {"Feature": "Expense Tracking", "Description": "Log and categorize daily restaurant expenses."},
    {"Feature": "Tax Configuration", "Description": "Setup global tax rates, multiple taxes, and item-specific rules."},
    {"Feature": "Sales Reports", "Description": "Analytics for Total Sales, Item Sales, Category Sales, and Top Sellers."},
    {"Feature": "Financial Reports", "Description": "Daily Closing (Z-Report), Refunds, Taxes, and Expense summaries."},
    {"Feature": "Operational Reports", "Description": "Insights on Void Orders, Discounts, and Staff Sales performance."},
    {"Feature": "Printer Connectivity", "Description": "Support for Bluetooth, USB, and WiFi thermal printers."},
    {"Feature": "Printer Roles", "Description": "Separate configuration for Bill (Front of House) and KOT (Kitchen) printing."},
    {"Feature": "Staff Management", "Description": "Add and manage staff accounts and access roles."},
    {"Feature": "End of Day", "Description": "Shift closing process with automatic reconciliation and summary."},
    {"Feature": "Order Notifications", "Description": "Customizable sound alerts and settings for incoming orders."},
    {"Feature": "Payment Methods", "Description": "Configure accepted payment types (Cash, Card, etc.)."}
]

# Data for Retail Sheet
retail_data = [
    {"Feature": "Point of Sale (POS)", "Description": "Fast checkout interface with barcode scanning support."},
    {"Feature": "Parked Sales", "Description": "Hold and retrieve customer transactions for later completion."},
    {"Feature": "Sales History & Returns", "Description": "View past transactions and process customer returns."},
    {"Feature": "Product Management", "Description": "Add/Edit products with attributes, variants, and categories."},
    {"Feature": "Bulk Import", "Description": "Import product data efficiently."},
    {"Feature": "Inventory Control", "Description": "Track stock levels, manage stock alerts, and view low stock warnings."},
    {"Feature": "Purchase Management", "Description": "Create purchase orders, record purchases, and receive materials."},
    {"Feature": "Supplier Management", "Description": "Manage supplier details and purchase history."},
    {"Feature": "Customer Management", "Description": "Maintain customer database with details and purchase history."},
    {"Feature": "Credit & Ledger", "Description": "Track customer credit, accept payments on account, and view ledgers."},
    {"Feature": "End of Day (EOD)", "Description": "Daily closing process with detailed sales and cash reconciliation reports."},
    {"Feature": "Tax (GST) Management", "Description": "Configure GST settings and generate detailed tax reports."},
    {"Feature": "Financial Reporting", "Description": "Sales history, credit reports, and comprehensive end-of-day summaries."},
    {"Feature": "Staff Management", "Description": "Setup and manage staff access and permissions."},
    {"Feature": "Backup & Security", "Description": "Data backup functionality and password management."},
    {"Feature": "Store Settings", "Description": "Configure store information and receipt details."}
]

# Create DataFrames
df_restaurant = pd.DataFrame(restaurant_data)
df_retail = pd.DataFrame(retail_data)

# Write to Excel
file_path = "POS_Features.xlsx"
with pd.ExcelWriter(file_path, engine='openpyxl') as writer:
    df_retail.to_excel(writer, sheet_name='Retail', index=False)
    df_restaurant.to_excel(writer, sheet_name='Restaurant', index=False)
    
    # Auto-adjust column width
    for sheet_name in writer.sheets:
        worksheet = writer.sheets[sheet_name]
        for column in worksheet.columns:
            max_length = 0
            column = [cell for cell in column]
            for cell in column:
                try:
                    if len(str(cell.value)) > max_length:
                        max_length = len(cell.value)
                except:
                    pass
            adjusted_width = (max_length + 2)
            worksheet.column_dimensions[column[0].column_letter].width = adjusted_width

print(f"Excel file created successfully: {file_path}")
