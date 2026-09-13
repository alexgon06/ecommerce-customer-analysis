import pandas as pd
import sqlite3


# =========================================================
# E-COMMERCE CUSTOMER ANALYSIS
# Dataset: UCI Online Retail
# =========================================================


# =========================================================
# 1. Load Raw Data
# =========================================================

df = pd.read_excel("Data/Online Retail.xlsx")

print("\nDATA PRE-CLEANING\n")
print(df.head())
print("\nShape:", df.shape)
print("\nColumns:")
print(df.columns)
print("\nData Types:")
print(df.dtypes)
print("\nMissing Values:")
print(df.isna().sum())
print("\nDuplicate Rows:", df.duplicated().sum())


# =========================================================
# 2. Clean and Prepare Data
# =========================================================

# Remove rows containing missing values
df = df.dropna()

# Remove duplicate rows
df = df.drop_duplicates()

# Remove rows with zero or negative prices
df = df[df["UnitPrice"] > 0]

# Create return/cancellation indicator
df["Returns"] = df["Quantity"] < 0

# Convert CustomerID from float to integer
df["CustomerID"] = df["CustomerID"].astype(int)

# Calculate transaction revenue
df["Revenue"] = df["Quantity"] * df["UnitPrice"]

# Create date/time features
df["Year"] = df["InvoiceDate"].dt.year
df["Month"] = df["InvoiceDate"].dt.month
df["DayOfWeek"] = df["InvoiceDate"].dt.dayofweek
df["Hour"] = df["InvoiceDate"].dt.hour


# =========================================================
# 3. Validate Cleaned Data
# =========================================================

print("\nDATA POST-CLEANING\n")
print("Shape:", df.shape)

print("\nMissing Values:")
print(df.isnull().sum())

print("\nDuplicate Rows:", df.duplicated().sum())

print("\nSummary Statistics:")
print(df.describe())

print("\nROWS WITH ZERO OR NEGATIVE UNIT PRICE\n")
print(
    df[df["UnitPrice"] <= 0][
        [
            "InvoiceNo",
            "StockCode",
            "Description",
            "Quantity",
            "UnitPrice",
            "Returns",
        ]
    ]
)

print("\nCANCELLED INVOICES\n")
print(
    df[df["InvoiceNo"].astype(str).str.startswith("C")][
        [
            "InvoiceNo",
            "StockCode",
            "Description",
            "Quantity",
            "UnitPrice",
            "Returns",
        ]
    ].head(20)
)


# =========================================================
# 4. Save Cleaned Data to SQLite
# =========================================================

conn = sqlite3.connect("ecommerce.db")

df.to_sql(
    "transactions",
    conn,
    if_exists="replace",
    index=False,
)

print("\nSaved cleaned data to ecommerce.db")


# =========================================================
# 5. Customer Value Analysis
# Question 15:
# Who are the most valuable customers based on
# spending and purchase frequency?
# =========================================================

customer_query = """
SELECT
    CustomerID,
    COUNT(DISTINCT InvoiceNo) AS Order_Count,
    SUM(Revenue) AS Total_Revenue
FROM transactions
GROUP BY CustomerID;
"""

customers_df = pd.read_sql_query(customer_query, conn)

print("\nCUSTOMER ORDER AND REVENUE ANALYSIS\n")
print(customers_df.head())


# Normalize customer revenue to a 0-1 scale
customers_df["Revenue_Score"] = (
    customers_df["Total_Revenue"] - customers_df["Total_Revenue"].min()
) / (
    customers_df["Total_Revenue"].max()
    - customers_df["Total_Revenue"].min()
)


# Normalize purchase frequency to a 0-1 scale
customers_df["Frequency_Score"] = (
    customers_df["Order_Count"] - customers_df["Order_Count"].min()
) / (
    customers_df["Order_Count"].max()
    - customers_df["Order_Count"].min()
)


# Equal weighting:
# 50% revenue + 50% purchase frequency
customers_df["Customer_Value_Score"] = (
    0.5 * customers_df["Revenue_Score"]
    + 0.5 * customers_df["Frequency_Score"]
)

print("\nTOP 10 CUSTOMERS BY VALUE SCORE\n")
print(
    customers_df.nlargest(
        10,
        "Customer_Value_Score",
    )[
        [
            "CustomerID",
            "Order_Count",
            "Total_Revenue",
            "Revenue_Score",
            "Frequency_Score",
            "Customer_Value_Score",
        ]
    ]
)


# =========================================================
# 6. Product Performance Analysis
# Question 16:
# Which products perform best based on revenue,
# quantity sold, and returns?
# =========================================================

product_query = """
SELECT
    Description,
    SUM(Revenue) AS Total_Revenue,
    SUM(Quantity) AS Total_Quantity
FROM transactions
WHERE Quantity > 0
GROUP BY Description;
"""

returns_query = """
SELECT
    Description,
    COUNT(DISTINCT InvoiceNo) AS Total_Returns
FROM transactions
WHERE Returns = TRUE
GROUP BY Description;
"""

product_df = pd.read_sql_query(product_query, conn)
returns_df = pd.read_sql_query(returns_query, conn)


print("\nPRODUCT SALES ANALYSIS\n")
print(product_df.head())

print("\nPRODUCT RETURNS ANALYSIS\n")
print(returns_df.head())


# Merge product sales data with product return data
product_df = pd.merge(
    product_df,
    returns_df,
    on="Description",
    how="left",
)

# Products with no matching return record had zero returns
product_df["Total_Returns"] = product_df["Total_Returns"].fillna(0)

print("\nMERGED PRODUCT ANALYSIS\n")
print(product_df.head())


# =========================================================
# 7. Normalize Product Metrics
# =========================================================

product_df["Revenue_Score"] = (
    product_df["Total_Revenue"] - product_df["Total_Revenue"].min()
) / (
    product_df["Total_Revenue"].max()
    - product_df["Total_Revenue"].min()
)

product_df["Quantity_Score"] = (
    product_df["Total_Quantity"] - product_df["Total_Quantity"].min()
) / (
    product_df["Total_Quantity"].max()
    - product_df["Total_Quantity"].min()
)

product_df["Return_Score"] = (
    product_df["Total_Returns"] - product_df["Total_Returns"].min()
) / (
    product_df["Total_Returns"].max()
    - product_df["Total_Returns"].min()
)


# =========================================================
# 8. Create Product Value Score
# =========================================================

# Revenue and quantity increase product performance.
# Returns reduce product performance.
product_df["Product_Value_Score"] = (
    0.4 * product_df["Revenue_Score"]
    + 0.4 * product_df["Quantity_Score"]
    - 0.2 * product_df["Return_Score"]
)

print("\nTOP 10 PRODUCTS BY VALUE SCORE\n")

print(
    product_df.nlargest(
        10,
        "Product_Value_Score",
    )[
        [
            "Description",
            "Total_Revenue",
            "Total_Quantity",
            "Total_Returns",
            "Revenue_Score",
            "Quantity_Score",
            "Return_Score",
            "Product_Value_Score",
        ]
    ]
)


# =========================================================
# 9. Close Database Connection
# =========================================================

conn.close()