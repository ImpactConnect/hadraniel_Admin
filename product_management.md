# 📦 Product Management - Development Guide (Admin App)

This document outlines the development process for the **Product Management** module in the **Admin Desktop App** for a frozen food sales inventory system. This app is built using **Flutter Desktop** with an **offline-first** architecture using **SQLite** and **Supabase** for cloud sync.

---

## 🧱 Objective

Allow the Admin to manage products (create, update, delete, view) per outlet. All products should be stored **locally first** and then synced to Supabase when online.

---

## 🗃️ Database Tables

### 🔹 Supabase `products` Table (Cloud)

```sql
create table products (
  id uuid primary key default gen_random_uuid(),
  product_name text not null,
  quantity numeric not null,
  unit text not null,
  cost_per_unit numeric not null,
  total_cost numeric not null,
  date_added timestamp default now(),
  last_updated timestamp,
  description text,
  outlet_id uuid not null references outlets(id),
  created_at timestamp default now()
);
```

### 🔹 SQLite `products` Table (Local)

```sql
CREATE TABLE products (
  id TEXT PRIMARY KEY,
  product_name TEXT NOT NULL,
  quantity REAL NOT NULL,
  unit TEXT NOT NULL,
  cost_per_unit REAL NOT NULL,
  total_cost REAL NOT NULL,
  date_added TEXT,
  last_updated TEXT,
  description TEXT,
  outlet_id TEXT NOT NULL,
  created_at TEXT
);
```

---

## 📁 Folder Structure

```
lib/
├── screens/products/
│   ├── products_screen.dart         # Main product list screen
│   ├── product_form_screen.dart     # Add/Edit form
│   └── product_detail_popup.dart    # View detail popup
├── core/services/
│   ├── product_service.dart         # Local DB operations
│   └── sync_service.dart            # Cloud sync for products
├── core/models/
│   └── product_model.dart
```

---

## 🛠️ Development Steps

### 1. Product Model

Implement the `Product` class in `product_model.dart`.

- Include `fromMap`, `toMap`, `fromJson`, `toJson` methods.
- Include logic to convert between Supabase and SQLite formats.

### 2. Product Service (Local DB)

Implement CRUD operations in `product_service.dart`:

- `insertProduct()`
- `getAllProducts()`
- `getProductById()`
- `updateProduct()`
- `deleteProduct()`

### 3. Sync Logic

In `sync_service.dart`, implement:

- `fetchProductsFromSupabase()` to pull products into local DB
- `pushUnsyncedProductsToSupabase()` to push offline-created products

### 4. UI Development

#### products_screen.dart

- Display product list in a `PaginatedDataTable` or table view
- Include filter/search bar
- Each product entry should show:
  - Name, Unit, Cost/Unit, Quantity, Total Cost, Outlet, Date Added, Date Updated
- Provide buttons:
  - Add Product (opens form)
  - View Details
  - Sync Button

#### product_form_screen.dart

- Form fields: product name, quantity, unit, cost/unit, description, outlet selector, Total Cost
- Preload the product name field with some products (Chicken, Turkey, Gari, Titus, Shawa, Egg, Titus, Beef, Goat meat), the user can select from existing product list or create a new one. Also, preload the unit with (KG, PCS, Carton, Paint, Cup). The user can select from the drop down or create a new one.
- Validate fields before saving
- Submit should write to local DB and mark as unsynced

#### product_detail_popup.dart

- Show extended details of the product in a dialog
- Option to close only (admin cannot edit from this view)

---

## 🔁 Sync Considerations

- Maintain a `synced` flag in the local DB.
- Only push unsynced records.
- When pulling from Supabase, handle updates using `last_updated` timestamps.

---

## ✅ Acceptance Criteria

- [ ] Admin can add/edit/delete products locally.
- [ ] All products are assigned to outlets.
- [ ] Products sync successfully to and from Supabase.
- [ ] UI supports product filtering and detailed viewing.
- [ ] All operations are offline-capable with retry sync.

---

## 📌 Notes

- Use `uuid` package to generate IDs locally.
- Ensure validation for duplicate product names within the same outlet.
- Add feedback (e.g., Snackbars) after operations like add, update, delete.
