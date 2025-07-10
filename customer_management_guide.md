# 👥 Customer Management – Admin Panel Development Guide

## 📌 Objective

Enable the admin to create, view, and manage customer profiles across all outlets. This includes customer profile registration, purchase history tracking, outstanding balance monitoring, and sales association.

---

## 🧩 Features to Implement

1. **Customer Profile Registration**
   - Form fields:
     - Full Name (Required)
     - Phone Number (Optional)
     - Assigned Outlet (Dropdown)
   - Assign a customer to a specific outlet
   - Save data to Supabase and local SQLite

2. **Customer List View**
   - Display customers in a tabular format
   - Columns: Name, Phone, Outlet, Total Purchases, Outstanding Balance
   - Support pagination and search/filter

3. **Customer Sales History**
   - On tap, show a detailed view of each customer's purchase history
   - List of transactions with:
     - Date
     - Items bought
     - Amount paid
     - Outstanding amount

4. **Outstanding Balance Monitoring**
   - Compute outstanding balances per customer
   - Show total outstanding across all customers in a metric card

5. **Filtering Options**
   - Filter customers by outlet
   - Filter by outstanding balance (e.g., customers with balance > 0)

---

## 🗃️ Database Table Schema

### Supabase Table: `customers`

```sql
create table customers (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  phone text,
  outlet_id uuid references outlets(id),
  total_outstanding numeric default 0,
  created_at timestamp default now()
);
```

### Local SQLite Table: `customers`

```sql
CREATE TABLE customers (
  id TEXT PRIMARY KEY,
  full_name TEXT NOT NULL,
  phone TEXT,
  outlet_id TEXT,
  total_outstanding REAL DEFAULT 0,
  created_at TEXT
);
```

---

## 🔁 Sync Strategy

- Fetch all customers from Supabase and store in local DB.
- On customer creation, insert locally first, then sync to Supabase when online.
- Ensure unique IDs using UUID for both online and offline consistency.
- Update total_outstanding when a new sale with a balance is recorded.

---

## ✅ Deliverables

- [ ] Customer registration form with validations
- [ ] Outlet dropdown with outlet list fetched from local DB
- [ ] Customer list screen with search and filter
- [ ] Customer detail page with purchase history
- [ ] Metric cards: Total Customers, Total Outstanding, etc.
- [ ] Sync logic between Supabase and SQLite for customers
- [ ] Offline support for listing and creating customers

---

## 🧪 Test Scenarios

1. Add new customer with and without internet
2. View customer list offline and online
3. Check sales history linkage
4. Add new sale and verify outstanding is updated
5. Sync customer changes to cloud and validate

---

**Generated on:** 2025-07-10 20:38:23
