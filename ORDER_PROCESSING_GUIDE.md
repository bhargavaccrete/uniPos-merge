# Order Processing Settings - User Guide

## Overview
This guide explains all Order Processing settings in the restaurant customization screen and how they affect your workflow.

---

## ✅ WORKING SETTINGS

### 1. Tax Is Inclusive
**What it does**: Controls whether item prices include tax or tax is added separately.

**When to use**:
- **Tax Inclusive (ON)**: Item prices already include tax
  - Menu shows: ₹118 (includes ₹18 tax)
  - Customer pays: ₹118
  - Good for: Fixed-price menus, street food, cafes

- **Tax Exclusive (OFF)**: Tax added to item price
  - Menu shows: ₹100
  - Tax added: +₹18
  - Customer pays: ₹118
  - Good for: Formal restaurants, accounting clarity

**Default**: OFF (Tax Exclusive)

**Location**: Settings & Customization → Order Processing → Tax Is Inclusive

---

### 2. Discount On Items
**What it does**: Controls when discount is applied in calculation.

**How it works**:
- **ON**: Discount before tax
  - Item: ₹100
  - Discount: -₹10
  - Subtotal: ₹90
  - Tax (18%): +₹16.20
  - **Total: ₹106.20**

- **OFF**: Discount after tax (on total)
  - Item: ₹100
  - Tax (18%): +₹18
  - Subtotal: ₹118
  - Discount: -₹10
  - **Total: ₹108**

**Best Practice**: ON for tax compliance (discount before tax)

**Default**: OFF

**Location**: Settings & Customization → Order Processing → Discount On Items

---

### 3. Show Payment Method
**What it does**: Payment method selection in customer details.

**Current Status**: Always available in expandable section

**Features**:
- Shows only enabled payment methods
- Syncs with Payment Method settings
- Displays message if no methods enabled
- Methods: Cash, Card, UPI, and custom options

**How to configure payment methods**:
1. Go to Settings → Payment Methods
2. Enable/disable methods
3. Add custom methods (PhonePe, Google Pay, etc.)

**Location**: Customer Details screen → Payment Method section

---

### 4. Round Off
**What it does**: Rounds bill total to nearest value for easier cash handling.

**Options**:
- ₹0.50 - Rounds to nearest 50 paise
- ₹1.00 - Rounds to nearest rupee
- ₹5.00 - Rounds to nearest ₹5
- ₹10.00 - Rounds to nearest ₹10

**Example** (₹1.00 rounding):
```
Subtotal: ₹1,827.35
Tax: ₹328.92
Service Charge: ₹50.00
Round Off: +₹0.73
Grand Total: ₹2,207.00 (rounded from ₹2,206.27)
```

**Bill Display**: Shows round-off adjustment separately

**Default**: OFF

**Location**: Settings & Customization → Layout Settings → Round Off

---

## ⏳ PLACEHOLDER SETTINGS (Not Yet Functional)

### 5. Generate KOT
**Current Status**: KOT numbers always generated automatically

**What it should do**: Control automatic KOT number assignment

**Current Behavior**:
- Every new order gets a KOT number
- KOT numbers increment daily
- Tracked for order management

**Future**: Toggle to disable KOT for quick orders

**Default**: OFF (placeholder)

---

### 6. Auto Print KOT On Delete Item
**Current Status**: Not implemented

**What it should do**: Automatically print updated KOT when item is removed from order

**Use Case**: Kitchen gets cancellation notice immediately

**Default**: OFF

---

### 7. Estimate
**Current Status**: Not implemented

**What it should do**: Enable quotation/preview mode

**Use Case**:
- Show price to customer before ordering
- Generate quotes for events
- Preview bills without creating orders

**Default**: OFF

---

### 8. Separate Quantity
**Current Status**: Not implemented

**What it should do**: Show quantity controls as separate +/- buttons

**Current Behavior**: Quantity displayed inline with cart items

**Use Case**: Faster quantity adjustments on touch screens

**Default**: OFF

---

## 📋 QUICK REFERENCE

| Setting | Status | Impact | Recommended For |
|---------|--------|--------|-----------------|
| Tax Is Inclusive | ✅ Working | Tax calculation | Based on your pricing |
| Discount On Items | ✅ Working | Tax base | ON for compliance |
| Round Off | ✅ Working | Bill rounding | ON for cash payments |
| Show Payment Method | ✅ Working | Payment UI | Always useful |
| Generate KOT | ⏳ Placeholder | Order tracking | Leave default |
| Auto Print Delete | ⏳ Placeholder | Kitchen sync | Future feature |
| Estimate Mode | ⏳ Placeholder | Quotes | Future feature |
| Separate Quantity | ⏳ Placeholder | UI layout | Future feature |

---

## 🎯 RECOMMENDED SETTINGS BY RESTAURANT TYPE

### Fine Dining
```
✅ Tax Is Inclusive: OFF (show breakdown)
✅ Discount On Items: ON (proper tax)
✅ Round Off: ON (₹1.00)
✅ Show Payment Method: Available
```

### Fast Food / QSR
```
✅ Tax Is Inclusive: ON (simple pricing)
✅ Discount On Items: OFF
✅ Round Off: ON (₹5.00 or ₹10.00)
✅ Show Payment Method: Available
```

### Cafe / Small Restaurant
```
✅ Tax Is Inclusive: ON
✅ Discount On Items: ON
✅ Round Off: ON (₹1.00)
✅ Show Payment Method: Available
```

---

## 🔧 HOW TO CHANGE SETTINGS

1. **Access Settings**:
   - From restaurant menu → Settings & Customization
   - Or Settings icon in app

2. **Navigate to Order Processing**:
   - Scroll to "Order Processing" section
   - Settings are grouped logically

3. **Toggle Setting**:
   - Tap switch to enable/disable
   - Changes save automatically
   - Take effect immediately (no restart)

4. **Test Changes**:
   - Place a test order
   - Verify calculations are correct
   - Check bill display

---

## ❓ TROUBLESHOOTING

### Tax amounts seem wrong
- Check "Tax Is Inclusive" setting
- Verify item tax rates in product setup
- Test with simple order (1 item, no discount)

### Round-off not showing
- Ensure "Round Off" is enabled
- Check that round-off amount > ₹0.01
- View complete bill summary

### No payment methods available
- Go to Settings → Payment Methods
- Enable at least one payment method
- Cash, Card, and UPI are default options

### Discount calculation incorrect
- Check "Discount On Items" setting
- Verify discount type (amount vs percentage)
- Review tax calculation mode

---

## 📞 SUPPORT

For issues or questions:
1. Check `SETTINGS_IMPLEMENTATION.md` for technical details
2. Review this guide for usage instructions
3. Test in safe environment before production use

---

**Last Updated**: December 23, 2025
**Version**: 1.0
**Status**: 4 of 8 settings operational