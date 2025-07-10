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

Preload the Product name section with the following product name in the add new product screen, so that it is possible to select from the existing list or add a new one.


Sardine 2-4
Sardine 3-5
Sardine 2SLT
Argentine BIG
Argentine Mideum
Mackerel 3-5 
Mackerel 5-9 
Mackerel 9UP
Shawa Box
Shawa 150-200 2SLT 
Shawa 200-250
Shawa 250-300
Shawa 300+ 22KG
Shawa P Ocean Spirit
Shawa SMT 
Shawa Cornelius
Alaska
Argentine 
Mulet 
Hake 15KG
Hake 10KG
Turkey 306
Turkey 305
Turkey (Blanket)
Full Chicken
Chicken Half 
Chicken Breast 
Chicken Wings 
Chicken Laps
Minal Sursage
Golden Phonex
Confidence Sausage
Doux Sausage 
Gool Sausage
Frangosul Sausage 
Gurme Sausage 
ByKeskin Sausage 
Premium Sausage 
Pena
Sadia
Perdix
Seara
Minu
UME Sausage
Tika
Shrimps
Cow Meat
Goat Meat
Elubo 0.50
Elubo 1Kg
Elubo 2Kg
Shawama / Lebanese Bread
Puff Puff Mix
Spring Roll
Samosa
Garri Ijebu Drinking Bag
Garri Ijebu Drinking 1Kg
Garri Ijebu Drinking 2Kg
Garri Ijebu Drinking Mudu
Garri Ijebu Drinking Paint
Garri Lebu/Swallow 1Kg
Garri Lebu/Swallow 2Kg
Garri Lebu/Swallow Bag
Garri Lebu/Swallow Mudu
Garri Lebu/Swallow Paint
Vegitable Mixed 450g
Vegitable Mixed 400g
Palm Oil 5L
Palm Oil 10L
Palm Oil 20L
Pomo Ice 
Pomo Dry Big
Pomo Dry Small
Egg
Kulikuli Big
Kulikuli Small
Kulikuli Mudu
Panla BW Africa Medium
Panla BW Africa Big
Panla BW Africa Small
Panla BW PP
Panla BW 30KG 3Slates 
Crocker Large
Croker Medium
American Paco / Tilapia 
Original Tilapia 
Chicken Gizzard
Turkey Gizzard
Potato Cips 
Crabs
Prawns 
Frolic Tomato Ketchup
Heinz Tomato Ketchup
Alfa Tomato Ketchup
Light Soy Sauce 
Dark Soy Sauce 
Premium Oyster Sauce 
Sweet Chilli Sauce 
Prawn Crackers Chips 
Bay Leaves Big 
Bay Leaves Medium 
Bay Leaves Pieces 
Green Giant (Sweet Corn) 425ml
Green Giant (Sweet Corn) 212ml
Bakeon Baking Powder 100g
Bama Mayonnaise 226ml
Bama Mayonnaise 385ml
Bama Mayonnaise 810ml
Jago Mayonnaise 443ml
Laziz Salad Cream 285gm
Laziz Salad Cream gm
Ground Black Pepper 
Ground Light/White Pepper 
Royal Wrap Aluminium Foil Papper 8m
Know Seasoning Cubes/Beef 
Know Seasoning Chicken 
Mr Chef Beef Flavour
Mr Chef Mixed Spices Cubes
Maggi Star Seasoning Cube
Maggi Star Chicken Flavour
Maggi Jollof Seasoning Powder
Advance Cken Chicken Seasoning Powder
Mivina Chicken seasoning Powder
Tiger Tomato Stew Mix 
Spicity Seasoning Powder Stew & Jollof 100g 
Spicity Seasoning Powder Stew & Jollof 10g 
Spicity Seasoning Powder Fried Rice 10g
Mr Chef Seasoning Tomato Mix Powder 
Deco Seasoning Aromat Chicken 
Mr Chef Jollof Saghetti Seasoning Powder 
Mr Chef Seasoning Goat Meat Powder 10g
Ama Wonda Curry 5g
Ama Wonda Jollof Rice Spice 5g
Ama Wonda Fried Rice Spice 5g
Larsor Fish Seasoning 10g
Larsor Beef Seasoning 10g
Larsor Chicken Seasoning 10g
Larsor Peppersoup Seasoning 10g
Larsoe Fried Rice Seasoning 10g
Addme All Purpose Beef Flavour Seasoning 10g
Addme All Purpose Chicken Flavour Seasoning 10g
Tasty Tom 2in1 Seasoning Beef Powder 11g
Tasty Tom 2in1 Seasoning Chicken Powder 11g
Kitchen Glory Fish Seasoning Powder 10g
Kitchen Glory Chicken Seasoning Powder 10g
Mr Chef Crayfish Seasoning Powder 10g
Tiger Nutmeg Powder 10g
Intergrated Ingredients Mixed Spices 10g
Gino Curry Powder 
Gino Dried Thyme 
Forza Chicken Seasoning Powder 10g
Forza Jollof Seasoning Powder 10g
Dahir Spices Curry Powder 5g
Tiger Curry Masala 
Vitals Ginger Garlic Powder 5g
Mr Chef Ginger Onion Garlic Seasoning Powder 10g
Mr Chef Mixed Spices Seasoning Powder 10g
Gino Party Jollof Tomato Seasoning Mix Paste
Gino Peppered Chicken Flavoured Tomato Seasoning Mix Paste 
Tasty Tom Tomato Mix Paste 
Tasty Tom Jollof Mix Paste 
