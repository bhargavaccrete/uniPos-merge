# 🧪 Bulk Import V3 - Quick Test Guide

## 🚀 Access the Test Screen

### Option 1: From Add Product Screen (Recommended)
1. Open your restaurant POS app
2. Navigate to **Add Product** screen
3. Scroll down to "Bulk Import via Excel" section
4. Click the **"Test V3"** button (orange button)

### Option 2: Direct Navigation
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const BulkImportTestScreenV3(),
  ),
);
```

## 📝 Quick Test (5 minutes)

### Step 1: Download Template
1. Click **"Download Template V3"**
2. Open the downloaded Excel file
3. Go to the **Items** sheet

### Step 2: Add Test Data
Copy this data into your Items sheet:

| ItemName | Price | CategoryName | VegType | Description | ImageURL | IsSoldByWeight | Unit | TrackInventory | StockQuantity | AllowOutOfStock | TaxRate | IsEnabled | HasVariants | ChoiceIds | ExtraIds |
|----------|-------|--------------|---------|-------------|----------|----------------|------|----------------|---------------|-----------------|---------|-----------|-------------|-----------|----------|
| Test Pizza | 200 | TestCategory | Veg | Delicious test pizza | https://images.unsplash.com/photo-1565299624946-b28f40a0ae38 | No | pcs | Yes | 50 | Yes | 5 | Yes | No | | |
| Test Burger | 150 | TestCategory | Non-Veg | Test burger | | No | pcs | No | 0 | Yes | 5 | Yes | No | | |
| Invalid Item | 0 | | Veg | This should fail | | No | pcs | No | 0 | Yes | 5 | Yes | No | | |

**What this tests:**
- ✅ Auto-category creation ("TestCategory" will be created)
- ✅ Image URL download (Pizza image)
- ✅ Validation error (Invalid Item has Price=0 and empty CategoryName)

### Step 3: Import
1. Click **"Pick Excel and Import"**
2. Select your edited template
3. Watch the progress bar and status messages

### Step 4: Verify Results

**Expected Output:**
```
✅ Import completed successfully!

📊 Import Statistics:
  Total Items: 2
  Categories: 0 (+ 1 auto-created)
  Variants: 0
  Item Variants: 0
  Extras: 0
  Toppings: 0
  Choices: 0
  Choice Options: 0
  Images Downloaded: 1

❌ Failed Rows (1):
  - Row 4: Price must be greater than 0, CategoryName is required

⚠️ Warnings (1):
  - Auto-created category: TestCategory
```

**Verify:**
1. Go to **Manage Menu**
2. Check "TestCategory" exists
3. Check "Test Pizza" and "Test Burger" exist
4. Check "Invalid Item" was NOT created
5. Check Pizza has an image (downloaded from URL)

## 🎯 Feature-Specific Tests

### Test 1: Auto-Category Creation
**Template:**
```excel
CategoryName: NewCat1
CategoryName: NewCat2
CategoryName: NewCat1  (reuse same category)
```

**Expected:** 2 categories created, 3rd item reuses NewCat1

### Test 2: Image URL Download
**Template:**
```excel
ImageURL: https://images.unsplash.com/photo-1565299624946-b28f40a0ae38
ImageURL: https://picsum.photos/200/300
ImageURL: invalid-url  (should show warning)
```

**Expected:** 2 images downloaded, 1 warning for invalid URL

### Test 3: Validation Errors
**Template:**
```excel
Row 1: ItemName="", Price=100, CategoryName="Food"
Row 2: ItemName="Item", Price=-50, CategoryName="Food"
Row 3: ItemName="Item", Price=100, CategoryName=""
Row 4: ItemName="Item", Price=100, CategoryName="Food", VegType="Maybe"
Row 5: ItemName="Item", Price=100, CategoryName="Food", IsSoldByWeight="YES", Unit=""
```

**Expected Errors:**
- Row 1: ItemName is required
- Row 2: Price must be greater than 0
- Row 3: CategoryName is required
- Row 4: VegType must be "Veg" or "Non-Veg"
- Row 5: Unit required when IsSoldByWeight is YES

### Test 4: Progress Callbacks
**Template:** Add 50+ items

**Expected:** Progress bar should update smoothly:
- "Loading existing data..."
- "Importing categories..."
- "Importing items... (10/50)"
- "Importing items... (20/50)"
- ...
- "Saving to database..."
- "Import complete!"

### Test 5: Inventory & Weight Items
**Template:**
```excel
ItemName: Weighted Item
Price: 100
CategoryName: Food
IsSoldByWeight: YES
Unit: kg
TrackInventory: YES
StockQuantity: 25.5
```

**Expected:** Item created with weight tracking and inventory

## 🐛 Common Issues

### Issue: "Failed to parse file"
**Solution:** Ensure Excel file format is .xlsx or .xls

### Issue: "Image download failed"
**Solution:**
- Check internet connection
- Verify URL is accessible
- Try a different image URL

### Issue: Categories not auto-created
**Solution:** Check CategoryName column has values (not IDs)

### Issue: Progress not showing
**Solution:** Ensure you're using V3 test screen (not old import)

### Issue: All rows fail validation
**Solution:**
- Check required columns: ItemName, Price, CategoryName
- Verify Price > 0 (or HasVariants = YES)
- Check VegType is "Veg" or "Non-Veg"

## 📊 Performance Benchmarks

Test import with different sizes:

| Item Count | Expected Time | Items/Second |
|------------|---------------|--------------|
| 10 items   | < 1 second    | 10+          |
| 50 items   | 2-3 seconds   | 20+          |
| 100 items  | 4-5 seconds   | 20+          |
| 500 items  | 20-25 seconds | 20-25        |

*Performance depends on image downloads and device speed*

## ✅ Success Criteria

After testing, you should see:
- ✅ Template downloaded with new columns (CategoryName, ImageURL)
- ✅ Categories auto-created from names (not IDs)
- ✅ Images downloaded from URLs
- ✅ Validation errors shown before save
- ✅ Progress updates in real-time
- ✅ Failed rows clearly reported
- ✅ Import completes successfully
- ✅ Items appear in Manage Menu

## 🔜 Report Issues

If you find any issues:
1. Note the exact error message
2. Check the failed row details in results
3. Verify your template format matches examples
4. Review `PHASE_1_IMPLEMENTATION_SUMMARY.md` for details
5. Check `BULK_IMPORT_CODE_REVIEW.md` for known limitations

---

**Happy Testing!** 🎉

For detailed implementation details, see: `PHASE_1_IMPLEMENTATION_SUMMARY.md`
