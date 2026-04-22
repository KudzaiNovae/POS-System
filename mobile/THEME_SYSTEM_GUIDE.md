# TillPro Theme System Guide

## Overview

A comprehensive, centralized theme system has been implemented to ensure consistency across the entire TillPro mobile app. This replaces scattered color values and spacing constants with a unified design language.

---

## Architecture

### 4 Core Theme Files

```
lib/core/theme/
├── app_colors.dart      # Color palette & semantic colors
├── app_spacing.dart     # Spacing units & layout constants
├── app_typography.dart  # Text styles & font system
└── app_theme.dart       # Material Theme generation
```

### 4 Reusable Component Files

```
lib/core/widgets/
├── app_card.dart        # Card components (AppCard, AppCardWithHeader, AppAlertCard)
├── app_badge.dart       # Badge/tag components (AppBadge, StockBadge, PaymentBadge, FiscalStatusBadge)
└── app_empty_state.dart # Empty/Loading/Error states & skeletons
```

---

## Quick Reference

### Colors

```dart
// Import
import 'core/theme/app_colors.dart';

// Primary brand
AppColors.primary             // #6366F1 (Indigo)
AppColors.primaryLight        // #818CF8
AppColors.primaryDark         // #4F46E5
AppColors.primaryVeryLight    // #EEF2FF

// Semantic colors
AppColors.success             // #10B981 (Emerald)
AppColors.warning             // #A16207 (Amber)
AppColors.error               // #DC2626 (Red)
AppColors.info                // #0EA5E9 (Sky)

// Neutrals (Slate)
AppColors.slate50 - slate900  // Grayscale palette

// Text colors
AppColors.textPrimary         // slate900
AppColors.textSecondary       // slate600
AppColors.textTertiary        // slate500
AppColors.textDisabled        // slate400

// Status colors
AppColors.outOfStock          // error
AppColors.lowStock            // warning
AppColors.inStock             // success
AppColors.completed           // success
AppColors.pending             // warning
AppColors.voided              // slate400
```

### Spacing (8pt grid)

```dart
// Import
import 'core/theme/app_spacing.dart';

// Base units
AppSpacing.xxs    // 2px
AppSpacing.xs     // 4px
AppSpacing.sm     // 8px
AppSpacing.md     // 12px
AppSpacing.lg     // 16px (most common)
AppSpacing.xl     // 24px
AppSpacing.xxl    // 32px
AppSpacing.xxxl   // 48px

// Common gaps
AppSpacing.gapSm  // SizedBox(8, 8)
AppSpacing.gapMd  // SizedBox(12, 12)
AppSpacing.gapLg  // SizedBox(16, 16)

// Radius
AppSpacing.radiusSm   // 8px
AppSpacing.radiusMd   // 12px
AppSpacing.radiusLg   // 16px
AppSpacing.radiusXl   // 24px
```

### Typography

```dart
// Import
import 'core/theme/app_typography.dart';

// Display (large headlines)
AppTypography.displayLarge()
AppTypography.displayMedium()
AppTypography.displaySmall()

// Headlines (section headers)
AppTypography.headlineLarge()
AppTypography.headlineMedium()
AppTypography.headlineSmall()

// Body (regular content)
AppTypography.bodyLarge()
AppTypography.bodyMedium()
AppTypography.bodySmall()

// Specialized
AppTypography.currency(color: color)      // Large, bold money
AppTypography.button()                     // Button text
AppTypography.badge()                      // Small badges
AppTypography.monospace()                  // Code/receipt
AppTypography.muted(color: color)          // Secondary text
```

---

## Using Components

### AppCard

```dart
// Basic card
AppCard(
  child: Text('Card content'),
)

// Card with tap
AppCard(
  onTap: () => print('Tapped'),
  child: Text('Tappable card'),
)

// Card with header
AppCardWithHeader(
  title: 'Products',
  action: IconButton(icon: Icon(Icons.add), onPressed: () {}),
  child: ProductsList(),
)

// Alert card
AppAlertCard(
  title: 'Low Stock',
  message: 'You have 5 products below reorder level',
  type: AlertType.warning,
  icon: Icons.warning_outlined,
  onDismiss: () => Navigator.pop(context),
)
```

### Badges

```dart
// Status badge
AppBadge(
  label: 'Completed',
  type: BadgeType.success,
  icon: Icons.check_circle_outlined,
)

// Stock badge (auto-color)
StockBadge(
  qty: 5,
  reorderLevel: 10,
  unit: 'pcs',
)

// Payment badge
PaymentBadge(paymentMethod: 'MPESA')

// Fiscal status
FiscalStatusBadge(fiscalStatus: 'SUBMITTED')
```

### Empty/Loading States

```dart
// Empty state
AppEmptyState(
  icon: Icons.shopping_cart_outlined,
  title: 'No sales yet',
  subtitle: 'Start by creating your first sale',
  action: FilledButton(
    onPressed: () => context.go('/pos'),
    child: Text('New Sale'),
  ),
)

// Loading state
AppLoadingState(message: 'Loading sales...')

// Error state
AppErrorState(
  title: 'Could not load',
  message: 'Check your connection and try again',
  onRetry: () => _refresh(),
)

// Skeleton loader
SkeletonLoader(count: 3, height: 16)
```

---

## Implementation Patterns

### Pattern 1: Padded Container with Content

```dart
// BAD - Hardcoded values
Container(
  padding: EdgeInsets.all(16),
  color: Colors.white,
  child: Text('Hello'),
)

// GOOD - Use theme
AppCard(
  padding: AppSpacing.lg,
  child: Text('Hello'),
)
```

### Pattern 2: Styled Text

```dart
// BAD - Hardcoded styles
Text('$199.99', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))

// GOOD - Use theme
Text('\$199.99', style: AppTypography.currency())
```

### Pattern 3: Conditional Colors

```dart
// BAD - Hardcoded conditions
color: product.stockQty == 0 ? Colors.red : Colors.green

// GOOD - Use theme utilities
color: AppColors.getStockStatusColor(product.stockQty, product.reorderLevel)
```

### Pattern 4: Lists with Consistent Spacing

```dart
// BAD - Inconsistent spacing
ListView(
  children: [
    Text('Item 1'),
    SizedBox(height: 8),
    Text('Item 2'),
    SizedBox(height: 12),  // Inconsistent!
  ],
)

// GOOD - Use gap constants
ListView(
  children: [
    Text('Item 1'),
    AppSpacing.gapHMd,
    Text('Item 2'),
    AppSpacing.gapHMd,
  ],
)
```

---

## Color Usage Guide

### When to Use Each Color

| Color | Use Case | Example |
|-------|----------|---------|
| **primary** | Main actions, links, focus | Buttons, highlights, active tabs |
| **success** | Positive status, complete | "In stock", "Synced", checkmarks |
| **warning** | Caution, attention needed | "Low stock", pending, warnings |
| **error** | Errors, failures, danger | "Out of stock", failed syncs, errors |
| **info** | Informational, neutral | Info messages, new features |
| **textPrimary** | Main text, labels | Titles, body text, labels |
| **textSecondary** | Secondary info | Subtitles, helper text, metadata |
| **textTertiary** | De-emphasized text | Timestamps, secondary metadata |
| **surfaceAlt** | Backgrounds, inputs | Input fields, alternative areas |
| **border** | Dividers, borders | Card borders, lines, separators |

---

## Migration Checklist

When updating existing screens:

- [ ] Replace hardcoded colors with `AppColors.*`
- [ ] Replace hardcoded spacing with `AppSpacing.*`
- [ ] Replace TextStyle objects with `AppTypography.*`
- [ ] Use `AppCard` instead of raw Container + decoration
- [ ] Use badge components instead of raw Chips
- [ ] Add proper empty/loading states with provided components
- [ ] Test on both light backgrounds and alternative surfaces
- [ ] Verify text contrast meets accessibility standards

---

## Adding New Colors

If you need a new color:

1. **First, check if it exists** - Look in `AppColors` for semantic options
2. **If adding custom color**, follow this structure:

```dart
// In app_colors.dart
static const Color newColor = Color(0xFFXXXXXX);
static const Color newColorLight = Color(0xFFXXXXXX);
static const Color newColorBg = Color(0xFFXXXXXX);
```

3. **Document the use case** - Add a comment explaining when to use it
4. **Update this guide** - Keep the color table in sync

---

## Testing the Theme

### Visual Testing Checklist

- [ ] All buttons look consistent
- [ ] All cards have same border radius and shadow
- [ ] All text sizes are readable
- [ ] All colors meet WCAG contrast ratios
- [ ] All spacing is aligned to 8pt grid
- [ ] Icons are consistently sized
- [ ] Empty states look polished
- [ ] Error messages are clear
- [ ] Loading states are smooth

### Device Testing

Test on:
- [ ] iOS (light mode)
- [ ] Android (light mode)
- [ ] Small screens (320px)
- [ ] Large screens (600px+)
- [ ] Tablets

---

## FAQ

**Q: Can I override theme colors locally?**
A: Yes, but only for exceptional cases. Use `AppColors` constant as the base and only adjust opacity or slightly different shades if absolutely necessary.

**Q: What about dark mode?**
A: Dark mode support can be added by creating `AppTheme.darkTheme()` and generating `AppColors` variants for dark surfaces.

**Q: Should I use Material widgets or custom widgets?**
A: Use Material widgets (Button, TextField, etc.) but wrap them in app-specific components like `AppCard` for consistency.

**Q: How do I add custom font sizes?**
A: Add a new static method to `AppTypography` following the existing pattern.

**Q: Can components have their own overrides?**
A: Yes, expose `color` or `style` parameters on components, but keep defaults aligned to theme.

---

## References

- **Color System**: Based on Tailwind CSS color palette
- **Spacing**: 8pt grid system (Material Design 3 aligned)
- **Typography**: Google Fonts "Outfit" with Material 3 scale
- **Components**: Material Design 3 patterns and conventions

---

**Last Updated**: 2026-04-21
**Status**: Active - Ready for implementation across all screens

