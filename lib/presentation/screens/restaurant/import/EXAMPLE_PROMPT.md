# Example Prompts for Restaurant Bulk Import

Use these example prompts to quickly generate bulk import data for your restaurant.

---

## Example 1: Simple Pizza Restaurant

**Prompt:**
```
Create a bulk import Excel for my pizza restaurant with:

Categories:
- Pizza
- Beverages
- Desserts

Variants (sizes):
- Small, Medium, Large

Pizza items with variants:
1. Margherita Pizza - Veg
   - Small: ₹200, Medium: ₹300, Large: ₹400
   - Stock: 10, 15, 20

2. Pepperoni Pizza - Non-veg
   - Small: ₹250, Medium: ₹350, Large: ₹450
   - Stock: 8, 12, 15

3. BBQ Chicken Pizza - Non-veg
   - Small: ₹280, Medium: ₹380, Large: ₹480
   - Stock: 8, 12, 15

Extras (toppings):
- Cheese Options (min: 0, max: 3):
  * Extra Cheese - ₹15 (Small), ₹20 (Medium), ₹25 (Large) - Veg
  * Mozzarella - ₹20 (Small), ₹25 (Medium), ₹30 (Large) - Veg

- Vegetables (min: 0, max: 5):
  * Olives - ₹15 - Veg
  * Mushrooms - ₹20 - Veg
  * Bell Peppers - ₹15 - Veg

- Sauces (min: 1, max: 2):
  * BBQ Sauce - ₹10 - Veg
  * Hot Sauce - ₹10 - Veg
  * Ranch - ₹15 - Veg

Choices (free selections):
- Crust Type: Thin Crust, Thick Crust, Stuffed Crust, Gluten-Free (+₹50)
- Spice Level: Mild, Medium, Hot, Extra Hot

Beverages (no variants):
- Coca Cola - ₹50 - Veg
- Sprite - ₹50 - Veg
- Fresh Lime Soda - ₹40 - Veg

Desserts (no variants):
- Chocolate Brownie - ₹80 - Veg
- Vanilla Ice Cream - ₹60 - Veg

All items:
- 5% tax rate
- Track inventory
- Allow orders when out of stock
- Unit: pcs
```

---

## Example 2: Burger Restaurant

**Prompt:**
```
Create bulk import data for my burger restaurant:

Categories:
- Burgers
- Sides
- Drinks
- Combos

Variants:
- Regular, Large (for drinks and fries)

Burgers (no size variants):
1. Classic Beef Burger - ₹150 - Non-veg - Stock: 30
2. Chicken Burger - ₹140 - Non-veg - Stock: 25
3. Veggie Burger - ₹120 - Veg - Stock: 20
4. Cheese Burger - ₹160 - Non-veg - Stock: 30
5. Double Patty Burger - ₹220 - Non-veg - Stock: 15

Extras for burgers:
- Patty Options (min: 0, max: 2):
  * Extra Beef Patty - ₹60 - Non-veg
  * Extra Chicken Patty - ₹50 - Non-veg
  * Extra Veggie Patty - ₹40 - Veg

- Cheese (min: 0, max: 3):
  * American Cheese - ₹20 - Veg
  * Cheddar - ₹25 - Veg
  * Mozzarella - ₹30 - Veg

- Veggies (min: 0, max: 10):
  * Lettuce - ₹10 - Veg
  * Tomato - ₹10 - Veg
  * Onions - ₹10 - Veg
  * Pickles - ₹15 - Veg
  * Jalapenos - ₹15 - Veg

- Sauces (min: 1, max: 3):
  * Ketchup - ₹0 - Veg
  * Mayo - ₹0 - Veg
  * BBQ - ₹10 - Veg
  * Hot Sauce - ₹10 - Veg
  * Mustard - ₹0 - Veg

Choices:
- Bun Type: Regular, Whole Wheat, Brioche (+₹20)
- Cook Level: Medium, Medium-Well, Well Done

Sides with variants:
1. French Fries
   - Regular: ₹60 - Stock: 50
   - Large: ₹80 - Stock: 40

2. Onion Rings
   - Regular: ₹70 - Stock: 30
   - Large: ₹90 - Stock: 25

Sides without variants:
- Coleslaw - ₹50 - Stock: 40
- Potato Wedges - ₹70 - Stock: 30

Drinks with variants:
1. Soft Drink (Coke/Pepsi)
   - Regular: ₹40
   - Large: ₹60

2. Fresh Juice
   - Regular: ₹60
   - Large: ₹80

All items: 5% tax, track inventory, allow backorders, unit: pcs
```

---

## Example 3: Indian Restaurant

**Prompt:**
```
Create bulk import for Indian restaurant menu:

Categories:
- Starters
- Main Course
- Breads
- Rice
- Desserts
- Beverages

Variants for curries:
- Half, Full

Main Course items with portions:
1. Butter Chicken - Non-veg
   - Half: ₹180 - Stock: 20
   - Full: ₹320 - Stock: 15

2. Paneer Butter Masala - Veg
   - Half: ₹150 - Stock: 25
   - Full: ₹280 - Stock: 20

3. Dal Makhani - Veg
   - Half: ₹120 - Stock: 30
   - Full: ₹220 - Stock: 25

4. Chicken Tikka Masala - Non-veg
   - Half: ₹200 - Stock: 20
   - Full: ₹350 - Stock: 15

Starters (no variants):
- Paneer Tikka - ₹180 - Veg - Stock: 20
- Chicken Tikka - ₹220 - Non-veg - Stock: 15
- Veg Pakora - ₹100 - Veg - Stock: 30
- Chicken Wings - ₹240 - Non-veg - Stock: 15

Breads (no variants):
- Butter Naan - ₹40 - Veg - Stock: 100
- Garlic Naan - ₹50 - Veg - Stock: 80
- Tandoori Roti - ₹30 - Veg - Stock: 100
- Laccha Paratha - ₹45 - Veg - Stock: 60

Rice (no variants):
- Steamed Rice - ₹80 - Veg - Stock: 50
- Jeera Rice - ₹100 - Veg - Stock: 40
- Veg Biryani - ₹180 - Veg - Stock: 20
- Chicken Biryani - ₹220 - Non-veg - Stock: 15

Choices for curries:
- Spice Level: Mild, Medium, Spicy, Extra Spicy

Extras for curries:
- Add-ons (min: 0, max: 5):
  * Extra Paneer - ₹60 - Veg
  * Extra Chicken - ₹80 - Non-veg
  * Extra Gravy - ₹30 - Veg

Desserts (no variants):
- Gulab Jamun (2 pcs) - ₹60 - Veg - Stock: 40
- Rasmalai (2 pcs) - ₹80 - Veg - Stock: 30
- Ice Cream - ₹70 - Veg - Stock: 50

Beverages (no variants):
- Masala Chai - ₹30 - Veg
- Lassi - ₹60 - Veg
- Soft Drink - ₹40 - Veg

All items: 5% GST, track inventory, unit: serving
```

---

## Example 4: Cafe Menu

**Prompt:**
```
Create bulk import for my cafe:

Categories:
- Coffee
- Tea
- Sandwiches
- Pastries
- Smoothies

Variants for beverages:
- Small, Regular, Large

Coffee with variants:
1. Cappuccino
   - Small: ₹80 - Stock: 50
   - Regular: ₹100 - Stock: 60
   - Large: ₹120 - Stock: 40

2. Latte
   - Small: ₹90 - Stock: 50
   - Regular: ₹110 - Stock: 60
   - Large: ₹130 - Stock: 40

3. Americano
   - Small: ₹70 - Stock: 50
   - Regular: ₹90 - Stock: 60
   - Large: ₹110 - Stock: 40

Extras for coffee:
- Milk Options (min: 1, max: 1):
  * Regular Milk - ₹0 - Veg
  * Almond Milk - ₹30 - Veg
  * Soy Milk - ₹25 - Veg
  * Oat Milk - ₹35 - Veg

- Shots (min: 0, max: 3):
  * Extra Espresso Shot - ₹30 - Veg

- Sweeteners (min: 0, max: 3):
  * Sugar - ₹0 - Veg
  * Honey - ₹15 - Veg
  * Stevia - ₹10 - Veg

- Toppings (min: 0, max: 5):
  * Whipped Cream - ₹20 - Veg
  * Chocolate Syrup - ₹15 - Veg
  * Caramel Syrup - ₹15 - Veg
  * Vanilla Syrup - ₹15 - Veg

Choices for coffee:
- Temperature: Hot, Iced
- Strength: Regular, Strong, Extra Strong

Tea with variants:
1. Green Tea
   - Small: ₹50
   - Regular: ₹60
   - Large: ₹70

2. Masala Chai
   - Small: ₹40
   - Regular: ₹50
   - Large: ₹60

Sandwiches (no variants):
- Veg Grilled Sandwich - ₹100 - Veg - Stock: 30
- Chicken Sandwich - ₹140 - Non-veg - Stock: 25
- Paneer Sandwich - ₹120 - Veg - Stock: 25

Pastries (no variants):
- Chocolate Muffin - ₹80 - Veg - Stock: 40
- Blueberry Muffin - ₹80 - Veg - Stock: 35
- Croissant - ₹70 - Veg - Stock: 30
- Chocolate Cake Slice - ₹120 - Veg - Stock: 20

Smoothies with variants:
1. Mango Smoothie
   - Regular: ₹100
   - Large: ₹130

2. Berry Blast
   - Regular: ₹110
   - Large: ₹140

All items: 5% tax, track inventory, unit: serving/pcs
```

---

## Example 5: Quick Service Restaurant (QSR)

**Prompt:**
```
Create bulk import for quick service restaurant:

Categories:
- Value Meals
- Fried Chicken
- Wraps
- Sides
- Desserts
- Beverages

Variants:
- 6pc, 9pc, 12pc (for chicken)
- Regular, Large (for beverages and fries)

Fried Chicken with piece variants:
1. Crispy Fried Chicken
   - 6pc: ₹280 - Stock: 40
   - 9pc: ₹400 - Stock: 30
   - 12pc: ₹520 - Stock: 20

2. Spicy Chicken
   - 6pc: ₹300 - Stock: 35
   - 9pc: ₹420 - Stock: 25
   - 12pc: ₹550 - Stock: 18

Choices for chicken:
- Spice Level: Mild, Medium, Hot, Extra Hot
- Coating: Original, Crispy, Extra Crispy

Wraps (no variants):
- Chicken Wrap - ₹140 - Non-veg - Stock: 40
- Veg Wrap - ₹110 - Veg - Stock: 35
- Paneer Wrap - ₹130 - Veg - Stock: 30

Extras for wraps:
- Add-ons (min: 0, max: 5):
  * Extra Chicken - ₹50 - Non-veg
  * Extra Cheese - ₹20 - Veg
  * Extra Veggies - ₹15 - Veg

Sides with variants:
1. French Fries
   - Regular: ₹60 - Stock: 100
   - Large: ₹90 - Stock: 80

2. Peri Peri Fries
   - Regular: ₹80 - Stock: 80
   - Large: ₹110 - Stock: 60

Sides without variants:
- Coleslaw - ₹50 - Stock: 60
- Corn on Cob - ₹60 - Stock: 40
- Mashed Potato - ₹70 - Stock: 50

Desserts (no variants):
- Chocolate Brownie - ₹90 - Veg - Stock: 50
- Apple Pie - ₹80 - Veg - Stock: 45
- Ice Cream Sundae - ₹100 - Veg - Stock: 40

Beverages with variants:
1. Pepsi
   - Regular: ₹40 - Stock: 200
   - Large: ₹60 - Stock: 150

2. Fresh Lemonade
   - Regular: ₹50 - Stock: 100
   - Large: ₹70 - Stock: 80

All items: 5% GST, track inventory, allow backorders, unit: pcs/serving
```

---

## How to Use These Prompts

1. **Copy** the prompt that matches your restaurant type
2. **Customize** the items, prices, and quantities
3. **Paste** into your data entry tool or Excel generator
4. **Generate** the Excel file
5. **Upload** to UniPOS bulk import

## Tips for Creating Your Own Prompts

✅ **Be Specific**: Include exact prices, stock quantities, and variant details
✅ **Use Clear Structure**: Separate categories, variants, extras, and choices
✅ **Specify Constraints**: Mention min/max for extras
✅ **Include All Details**: Tax rates, units, veg/non-veg, stock tracking
✅ **Group Similar Items**: Keep related items together for clarity
✅ **Mention Pricing**: Specify different prices for different sizes
✅ **List All Options**: Include all toppings, sauces, choices

## Prompt Template

```
Create bulk import for [restaurant type]:

Categories:
- [List categories]

Variants:
- [List size/portion names]

[Category name] with variants:
1. [Item name] - [Veg/Non-veg]
   - [Variant 1]: ₹[price] - Stock: [qty]
   - [Variant 2]: ₹[price] - Stock: [qty]

[Category name] without variants:
- [Item name] - ₹[price] - [Veg/Non-veg] - Stock: [qty]

Extras:
- [Extra group name] (min: [n], max: [m]):
  * [Topping name] - ₹[price] - [Veg/Non-veg]
  * [For variant pricing]: ₹[price] ([Variant name])

Choices:
- [Choice group name]: [Option 1], [Option 2], [Option 3]

Global settings:
- Tax: [%]
- Track inventory: [Yes/No]
- Allow backorders: [Yes/No]
- Unit: [pcs/serving/kg]
```

---

## Need Help?

Refer to `IMPORT_GUIDE.md` for detailed Excel structure and field descriptions.