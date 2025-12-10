# Restaurant Bulk Import Guide

## Overview

The improved bulk import system supports importing complete restaurant menu data including:
- Categories
- Variants (sizes)
- Extras (addon groups)
- Toppings (individual addons)
- Choices (option groups)
- Choice Options
- Items (products)
- Item-Variant mappings

## Excel Template Structure

The import template consists of **8 sheets**, each containing specific data:

### 1. Categories Sheet

Defines product categories.

| Column | Field | Type | Required | Example |
|--------|-------|------|----------|---------|
| A | id | String | Yes | cat_burgers |
| B | name | String | Yes | Burgers |
| C | imagePath | String | No | /images/burgers.png |

**Notes:**
- Use unique IDs (e.g., cat_burgers, cat_pizza)
- Image paths are optional

---

### 2. Variants Sheet

Defines global variant types (sizes, etc.) that can be reused across items.

| Column | Field | Type | Required | Example |
|--------|-------|------|----------|---------|
| A | id | String | Yes | var_small |
| B | name | String | Yes | Small |

**Notes:**
- Use consistent IDs (e.g., var_small, var_medium, var_large)
- These are referenced in ItemVariants and Topping sheets

---

### 3. Extras Sheet

Defines addon groups (e.g., "Cheese Options", "Sauces").

| Column | Field | Type | Required | Example |
|--------|-------|------|----------|---------|
| A | id | String | Yes | extra_toppings |
| B | name | String | Yes | Toppings |
| C | isEnabled | Yes/No | No | Yes |
| D | minimum | Number | No | 0 |
| E | maximum | Number | No | 5 |

**Notes:**
- `minimum` and `maximum` define constraints (e.g., "Select 1-2 sauces")
- Leave blank for no constraints

---

### 4. Toppings Sheet

Defines individual toppings/addons that belong to extras.

| Column | Field | Type | Required | Example |
|--------|-------|------|----------|---------|
| A | extraId | String | Yes | extra_toppings |
| B | name | String | Yes | Olives |
| C | isveg | Yes/No | Yes | Yes |
| D | price | Number | Yes | 15 |
| E | isContainSize | Yes/No | No | No |
| F | variantId | String | No* | var_small |
| G | variantPrice | Number | No* | 15 |

**Variant Pricing:**
If a topping has different prices for different sizes:
1. Set `isContainSize` = Yes
2. Add multiple rows with same name
3. Each row has different `variantId` and `variantPrice`

**Example - Regular topping (no variant pricing):**
```
extra_toppings | Olives | Yes | 15 | No | |
```

**Example - Topping with variant pricing:**
```
extra_cheese | Extra Cheese | Yes | 0 | Yes | var_small  | 15
extra_cheese | Extra Cheese | Yes | 0 | Yes | var_medium | 20
extra_cheese | Extra Cheese | Yes | 0 | Yes | var_large  | 25
```

---

### 5. Choices Sheet

Defines choice groups (e.g., "Crust Type", "Spice Level").

| Column | Field | Type | Required | Example |
|--------|-------|------|----------|---------|
| A | id | String | Yes | choice_crust |
| B | name | String | Yes | Crust Type |

---

### 6. ChoiceOptions Sheet

Defines the options within each choice group.

| Column | Field | Type | Required | Example |
|--------|-------|------|----------|---------|
| A | choiceId | String | Yes | choice_crust |
| B | id | String | Yes | opt_thin |
| C | name | String | Yes | Thin Crust |

**Example:**
```
choice_crust | opt_thin   | Thin Crust
choice_crust | opt_thick  | Thick Crust
choice_crust | opt_stuffed| Stuffed Crust
```

---

### 7. Items Sheet

Defines products/menu items.

| Column | Field | Type | Required | Example |
|--------|-------|------|----------|---------|
| A | id | String | Yes | item_burger |
| B | name | String | Yes | Chicken Burger |
| C | categoryOfItem | String | No | cat_burgers |
| D | description | String | No | Delicious chicken burger |
| E | price | Number | No* | 150 |
| F | isVeg | veg/non-veg | No | non-veg |
| G | unit | String | No | pcs |
| H | isSoldByWeight | Yes/No | No | No |
| I | trackInventory | Yes/No | No | Yes |
| J | stockQuantity | Number | No | 50 |
| K | allowOrderWhenOutOfStock | Yes/No | No | Yes |
| L | taxRate | Number (0-1) | No | 0.05 |
| M | isEnabled | Yes/No | No | Yes |
| N | hasVariants | Yes/No | No | No |
| O | choiceIds | Comma-separated | No | choice_crust,choice_spice |
| P | extraIds | Comma-separated | No | extra_toppings,extra_cheese |
| Q | imagePath | String | No | /images/burger.png |

**Notes:**
- `price` is required **only if** `hasVariants` = No
- If item has variants, set `price` = 0 and define prices in ItemVariants sheet
- `taxRate`: 0.05 = 5% tax
- `choiceIds` and `extraIds`: Reference IDs from Choices and Extras sheets

**Example - Simple item (no variants):**
```
item_burger | Chicken Burger | cat_burgers | Delicious chicken burger | 150 | non-veg | pcs | No | Yes | 50 | Yes | 0.05 | Yes | No | | extra_sauces |
```

**Example - Item with variants:**
```
item_veg_pizza | Veg Pizza | cat_pizza | Fresh vegetable pizza | 0 | veg | pcs | No | No | 0 | Yes | 0.05 | Yes | Yes | choice_crust,choice_spice | extra_toppings,extra_cheese |
```

---

### 8. ItemVariants Sheet

Defines variant pricing for items where `hasVariants` = Yes.

| Column | Field | Type | Required | Example |
|--------|-------|------|----------|---------|
| A | itemId | String | Yes | item_veg_pizza |
| B | variantId | String | Yes | var_small |
| C | price | Number | Yes | 200 |
| D | trackInventory | Yes/No | No | Yes |
| E | stockQuantity | Number | No | 10 |

**Example:**
```
item_veg_pizza | var_small  | 200 | Yes | 10
item_veg_pizza | var_medium | 300 | Yes | 15
item_veg_pizza | var_large  | 400 | Yes | 20
```

---

## Complete Example: Pizza with Variants and Toppings

### Categories
```
cat_pizza | Pizza |
```

### Variants
```
var_small  | Small
var_medium | Medium
var_large  | Large
```

### Extras
```
extra_cheese | Cheese Options | Yes | 1 | 3
extra_sauce  | Sauce Options  | Yes | 0 | 2
```

### Toppings
```
extra_cheese | Extra Cheese | Yes | 0  | Yes | var_small  | 15
extra_cheese | Extra Cheese | Yes | 0  | Yes | var_medium | 20
extra_cheese | Extra Cheese | Yes | 0  | Yes | var_large  | 25
extra_cheese | Mozzarella   | Yes | 0  | Yes | var_small  | 20
extra_cheese | Mozzarella   | Yes | 0  | Yes | var_medium | 25
extra_cheese | Mozzarella   | Yes | 0  | Yes | var_large  | 30
extra_sauce  | BBQ Sauce    | Yes | 10 | No  |            |
extra_sauce  | Hot Sauce    | Yes | 10 | No  |            |
```

### Choices
```
choice_crust | Crust Type
```

### ChoiceOptions
```
choice_crust | opt_thin   | Thin Crust
choice_crust | opt_thick  | Thick Crust
choice_crust | opt_stuffed| Stuffed Crust
```

### Items
```
item_veg_pizza | Veg Pizza | cat_pizza | Fresh vegetable pizza | 0 | veg | pcs | No | No | 0 | Yes | 0.05 | Yes | Yes | choice_crust | extra_cheese,extra_sauce |
```

### ItemVariants
```
item_veg_pizza | var_small  | 200 | Yes | 10
item_veg_pizza | var_medium | 300 | Yes | 15
item_veg_pizza | var_large  | 400 | Yes | 20
```

---

## Import Process

1. **Download Template**: Click "Download Template" to get the Excel file with all 8 sheets
2. **Fill Data**: Enter your menu data in each sheet
3. **Upload**: Click "Upload Excel" and select your file
4. **Review Results**: Check the import summary for any errors or warnings

---

## Important Notes

### ID Consistency
- IDs must be unique within each entity type
- IDs are case-sensitive
- Use consistent naming (e.g., `cat_`, `var_`, `extra_`, `choice_`, `item_`, `opt_`)

### Duplicate Detection
- The system checks for existing IDs
- If an ID already exists, that row is skipped with a warning
- To update existing items, delete them first or use different IDs

### Error Handling
- Errors are reported per row with sheet name and row number
- Import continues even if some rows fail
- Review the summary to identify and fix issues

### Data Validation
- Required fields cannot be empty
- Boolean fields accept: Yes/No, True/False, 1/0 (case-insensitive)
- Numbers are automatically parsed (commas and currency symbols removed)

### Best Practices
1. Start with Categories, Variants, Extras, and Choices
2. Then add Toppings and ChoiceOptions
3. Finally add Items and ItemVariants
4. Test with a few items first before bulk import
5. Keep a backup of your Excel file

---

## Troubleshooting

**Q: Import says "Category not found"**
A: Ensure the category ID in Items sheet exactly matches the ID in Categories sheet

**Q: Topping variant prices not working**
A: Check that `isContainSize` = Yes and variant IDs match those in Variants sheet

**Q: Items imported but no variants**
A: Ensure `hasVariants` = Yes in Items sheet and matching rows exist in ItemVariants sheet

**Q: Choices not showing on item**
A: Verify choice IDs in Items sheet match IDs in Choices sheet (comma-separated, no spaces)

---

## Support

For issues or questions, check the import summary for specific error messages.