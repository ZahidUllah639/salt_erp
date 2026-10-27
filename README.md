# SaltFlow - Salt Factory ERP (Flutter)

A faithful, exact pixel-perfect Flutter port of the **SaltFlow** Factory ERP web application (`salt_react`).

## Architecture & Structure

The codebase is structured under `lib/`:

- [main.dart](file:///f:/salt/salt_flutter/lib/main.dart): Application entry point configuring Material 3, light theme, and root `SaltFlowApp`.
- [theme/app_theme.dart](file:///f:/salt/salt_flutter/lib/theme/app_theme.dart): Design tokens directly matching `index.css`:
  - Curated color palette: `#111C33` (Sidebar), `#14213D` (Hero & Day summary), `#2563EB` (Primary), `#15803D` (Green), `#DC2626` (Red), `#B45309` (Amber), `#7C3AED` (Violet), `#8A6848` (Raw Salt Brown), `#F4F6F8` (App background).
  - Inter typography via Google Fonts.
  - Multi-tier elevation shadows and border radiuses.
- [components/app_icons.dart](file:///f:/salt/salt_flutter/lib/components/app_icons.dart): Exact 27 vector SVG paths converted directly from React's SVG dictionary:
  - `grid`, `box`, `cart`, `sale`, `stock`, `factory`, `truck`, `users`, `calendar`, `wallet`, `report`, `settings`, `search`, `bell`, `plus`, `arrow`, `print`, `download`, `filter`, `more`, `check`, `warning`, `cash`, `trend`, `close`, `menu`, `eye`.
- [components/app_components.dart](file:///f:/salt/salt_flutter/lib/components/app_components.dart): Core reusable ERP elements:
  - `AppButton`: `primary`, `secondary`, `ghost` with icon support and hover states.
  - `AppBadge`: Status badges (`green`, `red`, `amber`, `blue`, `neutral`) with circular indicator dots.
  - `MetricCard`: Multi-colored metric statistics with trend indicators.
  - `MiniMetric`: Compact stat cards with alert highlighting.
  - `AppToolbar`: Global table toolbar with search field, `⌘ K` pill, filter badges, and date filters.
  - `DangerNotice`: High-priority operational warning banners.
- [components/module_page.dart](file:///f:/salt/salt_flutter/lib/components/module_page.dart): Canonical page shell providing consistent ERP header, breadcrumbs, action buttons, and responsive layouts.
- [components/receipt_modal.dart](file:///f:/salt/salt_flutter/lib/components/receipt_modal.dart): Interactive Thermal Receipt Preview dialog:
  - 58 mm and 80 mm paper width toggle switch.
  - Live printer connection indicator.
  - Authentic monospace thermal printing receipt with dashed dividers, itemized rows, tax/discount math, and double border totals.
- [pages/app_shell.dart](file:///f:/salt/salt_flutter/lib/pages/app_shell.dart): Full ERP navigation layout:
  - Collapsible sidebar with brand mark (`S`), 12 modules, unread badge on Stock Management, data synchronization status pulse, and collapse toggle.
  - Sticky topbar with breadcrumb, global search, unread notification bell, and user profile (`Adnan Khan • Owner`).
- **ERP Pages**:
  - [pages/dashboard_page.dart](file:///f:/salt/salt_flutter/lib/pages/dashboard_page.dart): 6 live factory metrics, Sales & Profit 7-day dual-bar trend chart, available wallets breakdown, stock status strip, and live transactions table.
  - [pages/products_page.dart](file:///f:/salt/salt_flutter/lib/pages/products_page.dart): 4 mini metrics, interactive product selection table, and live conversion / stock configuration side panel.
  - [pages/stock_page.dart](file:///f:/salt/salt_flutter/lib/pages/stock_page.dart): Negative stock alert banner, material stock valuations, and stock health table with negative values highlighted in red.
  - [pages/production_page.dart](file:///f:/salt/salt_flutter/lib/pages/production_page.dart): Negative stock reconciliation flow track (`0 − 200 + 300 = 100`), batch cost recipe card, and verified production table.
  - [pages/parties_page.dart](file:///f:/salt/salt_flutter/lib/pages/parties_page.dart): Reusable Suppliers & Customers ledger with 2-letter avatar pills, balance status badges, and contact directories.
  - [pages/transactions_page.dart](file:///f:/salt/salt_flutter/lib/pages/transactions_page.dart): Purchases & Sales invoices, outstanding tracking, and thermal receipt print actions.
  - [pages/daily_records_page.dart](file:///f:/salt/salt_flutter/lib/pages/daily_records_page.dart): 6 quick accounting action buttons, dark navy Day Summary equation bar (`Opening + In − Out = Closing`), and money movement register.
  - [pages/wallets_page.dart](file:///f:/salt/salt_flutter/lib/pages/wallets_page.dart): Color-coded wallet cards (Cash in Hand, UBL Bank, EasyPaisa, HGM Work) and live cash drawer reconciliation calculator.
  - [pages/reports_page.dart](file:///f:/salt/salt_flutter/lib/pages/reports_page.dart): Monthly Snapshot October 2026 hero banner, Financial, Ledger, Inventory, and Production report directory.
  - [pages/settings_page.dart](file:///f:/salt/salt_flutter/lib/pages/settings_page.dart): Backup schedule and snapshot verification, Thermal Printer selection and test print triggers.

## Running the Application

### Windows Desktop:
```bash
flutter run -d windows
```

### Web Browser:
```bash
flutter run -d chrome
```

### Tests & Quality Verification:
```bash
flutter analyze
flutter test
```
