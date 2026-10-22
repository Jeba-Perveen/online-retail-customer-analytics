# Online Retail II: Customer Revenue, Retention and Revenue-at-Risk Analytics

An end-to-end analytics project on real transaction data from a UK online retailer. The work covers data quality auditing, cleaning, a SQL pipeline, Python analysis and a Power BI dashboard.

> **Status: in progress.** Data quality checks are complete and cleaning is underway. The SQL, Python and Power BI stages are planned and are marked as such below.

## Business Problem

Which customers drive most of the revenue, which customers are likely to churn, and how much revenue is at risk if they do?

## Dataset

- **Source:** UCI Machine Learning Repository, Online Retail II (https://archive.ics.uci.edu/dataset/502/online+retail+ii)
- **Size:** 1,067,371 rows across 2 Excel sheets
- **Period:** 1 Dec 2009 to 9 Dec 2011
- **Columns:** `Invoice`, `StockCode`, `Description`, `Quantity`, `InvoiceDate`, `Price`, `Customer ID`, `Country`. The first sheet also has a calculated `Sales` column that the second sheet lacks.

## Project Status

| Stage | Notebook / Folder | Status |
|---|---|---|
| Load data and save raw backup | `01_data_loading_and_raw_backup` | Done |
| Data quality checks (12 checks and issue log) | `02_data_quality_checks` | Done |
| Data cleaning | `03_data_cleaning` | Done |
| SQL pipeline | `sql/` | Planned |
| Python analysis (EDA, statistical tests, churn) | `04_...` | Planned |
| Power BI dashboard | `powerbi/` | Planned |

## Key Findings So Far

These come from `02_data_quality_checks`, which documents 12 checks with a finding, impact and planned action for each.

- **Duplicates:** 34,335 rows (3.22%) are exact duplicates. A first check flagged only 12,133, because `Sales` exists in one sheet only, so repeated rows looked different. 22,523 of them come from the two sheets overlapping on 1 to 9 Dec 2010, and 11,812 occur within a single sheet.
- **Missing Customer ID:** 243,007 rows (22.77%) have no Customer ID, so customer-level analysis cannot cover them.
- **Returns and adjustments:** 22,950 rows (2.15%) have negative Quantity. 19,493 are cancelled invoices ('C' prefix) and 3,457 are zero-price rows with no Customer ID.
- **Non-product rows:** 6,093 rows across 62 StockCodes are charges, adjustments, test entries, gift vouchers or samples. A pattern-based filter also caught real products with non-standard codes (`DCGS...`), which were kept.
- **Outliers:** The two largest orders (80,995 and 74,215 units) were fully cancelled by the same customer within 12 and 16 minutes. The highest prices belong to non-product codes such as Manual, Bank Charges and Amazon Fee.
- **Text inconsistencies:** About 20% of Descriptions have a trailing space, and 1,210 of 4,950 StockCodes have more than one Description after cleaning spaces and case.

## Cleaning Approach

Rows are labelled, not deleted, so every row stays traceable. Labels are applied in a fixed order after removing the 22,523 overlap rows (1,044,848 rows remain):

| row_type | Rows |
|---|---|
| sale | 1,015,088 |
| return | 17,974 |
| zero_or_neg_price | 5,940 |
| charges_fees | 4,113 |
| adjustments_test | 1,496 |
| samples | 102 |
| gift_vouchers | 100 |
| unclear_dcgs | 33 |
| unclear | 2 |

## Other cleaning steps:
- **Description:** spaces and case standardised, and each StockCode now takes its most frequent Description (617 StockCodes had more than one). Distinct descriptions went from 5,698 to 4,748.
- **Country:** EIRE, USA and RSA renamed to Ireland, United States and South Africa. Non-country labels such as "Unspecified" are kept as separate categories.
- **Sales:** the original column existed in one sheet only, so it was dropped and recalculated as Quantity x Price for every row.
  
## Decisions and Assumptions
- Overlap-week rows were removed from the second sheet, because they are identical in both sheets.
- The 11,812 within-sheet duplicates were **kept**. They are 0.29% of revenue and appear on customer invoices where the same item can plausibly repeat, but the data cannot confirm whether they are errors.
- Rows without a Customer ID stay in revenue and product analysis and are excluded from customer-level analysis.
- Returns are kept as a separate group for return-rate and net revenue analysis.

## Planned Work

- **SQL:** staging tables, cleaning views, CTEs, window functions, stored procedures, historical and incremental loading (simulated on this historical data) and slowly changing dimensions for customer segments.
- **Python:** EDA, hypothesis testing and churn analysis.
- **Power BI:** time intelligence, field parameters and incremental refresh.

## Tools

Python (Pandas), SQL, Power BI

## How to Run

1. Download the dataset from the link above and place `online_retail_II.xlsx` in the data folder.
2. Install the requirements: `pip install pandas openpyxl`
3. Run the notebooks in order: `01`, `02`, `03`.

The raw CSV (`data/raw/`) is not included in the repository because of its size, and it is never modified by any notebook.

## Author

Jeba Perveen
