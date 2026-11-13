# Project State

Inventory captured 2026-10-14. This is a description of the checkout as read; it does not claim that every screen or backend path is production-ready. No feature implementation was performed during this inventory.

## Folder structure

- `lib/core/`: app router and auth refresh, theme, money formatter/utilities, shared loading/error/empty/status/button widgets, and an existing Drift database (`database/app_database.dart` plus generated `app_database.g.dart`).
- `lib/features/auth/`: `application/` Riverpod providers; `domain/` auth user and repository interface; `data/` fake and Firebase repositories; `presentation/` splash, role selection, login/signup pages and auth error text.
- `lib/features/manager/`: `application/` providers/controllers; `data/` fake and local Drift repositories; `domain/` models, repository interface, order draft, validation and commission calculation; `presentation/` manager home, waiter/menu/shift management, summary and close-day pages.
- `lib/features/owner/`: `application/` providers; `data/` fake shop, reports and governance repositories; `domain/` models and repository interfaces; `presentation/` owner home, branches/subshops, dashboard, reports, alerts, commission policy, adjustments and audit pages.
- `lib/features/navigation/presentation/`: placeholder/not-found page.
- `functions/src/index.ts`: callable Firebase Cloud Functions. `functions/test/` contains backend tests; `functions/lib/` and `functions/node_modules/` are generated/installed artifacts.
- Root Firebase rules: `firestore.rules`. Flutter dependencies and configuration: `pubspec.yaml`.

## Routes

Routes are declared directly in `lib/core/router/app_router.dart`; there is no separate `app_routes.dart` in this checkout.

| Route | Screen |
|---|---|
| `/splash` | Splash/auth gate |
| `/role-select` | Role selection |
| `/owner/login`, `/manager/login` | Login pages |
| `/owner/signup` | Owner signup |
| `/owner/home` | Owner home/tabs |
| `/owner/subshops/create` | Create subshop |
| `/owner/subshops/:subshopId` | Subshop detail |
| `/owner/reports/view` | Report detail (optional `ReportFilter` in `extra`) |
| `/owner/commission-policy` | Commission policy |
| `/owner/adjustments` | Day adjustments (`dayId` query parameter optional) |
| `/owner/audit` | Audit history |
| `/manager/home` | Manager order entry/home |
| `/manager/manage` | Manager management hub |
| `/manager/manage/summary` | Today summary |
| `/manager/manage/close-day` | Close day |
| `/manager/manage/waiters`, `/manager/manage/menu`, `/manager/manage/shifts` | Management pages |

Redirects are in `app_router.dart`. The router refresh listens to `fakeAuthRepository.currentUser`, while auth providers use `FirebaseAuthRepository`; this split can leave redirect state inconsistent with actual auth state.

## Models and key fields

- Auth (`features/auth/domain/auth_user.dart`): `AuthUser(id, role, name)`; `UserRole` owner/manager. Auth interface: `currentUser` stream, `signInManager(username,password)`, `signInOwner(email,password)`, `signUpOwner(name,email,password)`, `signOut()`.
- Manager (`features/manager/domain/manager_models.dart`): `SyncStatus`; `Waiter(id,name,isActive)`; `MenuCategory(id,name,isActive)`; `MenuItem(id,name,pricePaisa,categoryId,isActive)`; `Shift(id,name,startTime,endTime)`; `ManagerHomeData(shopName,shiftName,businessDayStatus,syncStatus,pendingCount,todaySalesPaisa,orderCount,waiters,categories,menuItems,shifts,activeShiftId)`; `SavedOrder(waiterId,lines,totalPaisa)`; `WaiterShiftSales`; `TodaySummary(rows,pendingSyncCount,syncStatus,isClosed)`; `ClosingTotals`; `WaiterTodayTotal`.
- Owner shop (`features/owner/domain/shop_models.dart`): `Subshop(id,name,referralId,managerUsername,isActive,dayStatus)`; `MainBranch(id,name,subshops)`; `SubshopCredentials(referralId,username,password)`.
- Reports (`owner_reports_models.dart`): live card metrics and sync/staleness state; `ReportType`, `ReportFilter(mainBranchId,subshopId,reportType,selectedDate,endDate,month,year)`, `ReportRow` with counts, sales, commission, collection and adjustment figures, and aggregate `ReportData`.
- Governance (`owner_governance_models.dart`): owner alerts; branch/shift/subshop commission policy; adjustment type and day adjustment; closed-day record with computed net/adjusted values; audit action and audit log entry.
- Local database currently has Drift rows `Waiters(id,name,isActive)`, `MenuCategories(id,name,isActive)`, `MenuItems(id,name,pricePaisa,categoryId,isActive)`, `Shifts(id,name,startTime,endTime)`, `Orders(id,operationId,waiterId,shiftId,totalPaisa,createdAt,syncedAt)`, `OrderItems(rowId,orderId,menuItemId,pricePaisa,quantity)`, and `PendingOps(operationId,type,payloadJson,createdAt,retryCount)`.

## Repository interfaces and methods

- `AuthRepository`: auth stream, owner/manager sign-in, owner signup, sign-out. Implementations: fake and Firebase.
- `ManagerRepository`: `watchHomeData`, add/deactivate waiter, add category/item, update item price, deactivate item, add/select shift, `saveOrder`, `watchTodaySummary`, and close day with actual collection amounts. Implementations: `FakeManagerRepository` and `LocalManagerRepository` (currently selected in providers).
- `OwnerShopRepository`: watch branches; create main branch/subshop; reset manager password; deactivate subshop.
- `OwnerReportsRepository`: watch live cards; fetch report by filter.
- `OwnerGovernanceRepository`: watch/mark alerts, watch/update policies, watch closed days, add/reverse adjustments, watch audit logs.
- Owner shop/reports/governance interfaces are currently backed by fake repositories. They do not yet use Firestore.

## Riverpod providers

- Auth: repository, auth user stream, auth controller in `features/auth/application/auth_providers.dart`.
- Manager: database/repository providers; home and summary streams; derived waiter totals and filtered menu; manager/order/closing controllers and draft state in `features/manager/application/manager_providers.dart`.
- Owner: repository providers, branches/subshop and mutation controllers; reports filters/data providers; alerts/policies/closed-day/audit and governance actions in the three `features/owner/application/*providers.dart` files.
- App entry point wraps the app in `ProviderScope` (`lib/main.dart`).

## Firestore paths and rules

Paths present in `functions/src/index.ts` and `firestore.rules`:

- `shops/{ownerId}`
- `shops/{ownerId}/branches/{branchId}`
- `shops/{ownerId}/branches/{branchId}/subshops/{subshopId}`
- `.../subshops/{subshopId}/orders/{orderId}`
- `.../subshops/{subshopId}/closed_days/{dayId}`
- `counters/referralId`
- `managerCredentials/{managerUid}`
- `audit_logs/{logId}`

Rules deny all by default, then allow role/UID based access to shop, branch, subshop, order and closed-day paths. Subshop writes and audit writes are denied to clients; counters are server-only. Client role/subshop claims are relied on by rules.

## Cloud Functions

- `createMainBranch({ownerId, name})` → `{branchId}`; writes a branch under the owner's shop.
- `createSubshop({ownerId, branchId, subshopName, managerUsername, managerPassword})` → `{subshopId, referralId}`; allocates a referral counter, creates a manager Auth user, writes the subshop and manager credentials mapping.
- `resetManagerPassword({managerUid, newPassword})` → `{success: true}`; updates the Auth password.

## Packages

Flutter SDK constraint: `^3.12.2`. Runtime dependencies: Flutter, `cupertino_icons ^1.0.8`, `firebase_core ^4.15.0`, `flutter_riverpod ^2.6.1`, `go_router ^16.2.4`, `share_plus ^13.3.1`, `firebase_auth ^6.7.0`, `drift ^2.20.0`, `drift_flutter ^0.2.4`, `path_provider ^2.1.4`, `path ^1.9.0`, `uuid ^4.5.1`. Dev: `flutter_test`, `flutter_lints ^6.0.0`, `drift_dev ^2.20.0`, `build_runner ^2.4.13`. Functions use Node 20, `firebase-admin ^12`, `firebase-functions ^5`; dev dependencies include TypeScript, Mocha, Chai, ts-node and Firebase Functions test helpers.

## Implemented vs fake/incomplete

- Screens/routes described by the project brief are present in the feature presentation folders.
- Owner auth uses Firebase Auth when Firebase is available, but includes a fake fallback. Manager auth also contains fallback behavior. No Firebase Firestore, Functions, or Messaging package appears in the current Flutter `pubspec.yaml`, so those capabilities are not wired from Flutter in this checkout.
- Cloud Functions and Firestore rules exist, but there are no Firestore-backed owner repositories in `lib/`; owner dashboards/reports/governance are fake data.
- Manager providers select `LocalManagerRepository`, backed by Drift. Fake manager repository remains available.
- The Drift layer is an existing partial local-first implementation, not the requested full Task 13 schema/repository set. It has schema version 1, generated code, and a transaction for order + items + pending op, but lacks cached shop config, business days, waiter/menu sync metadata and subshop IDs, required order snapshots/totals, complete pending operation fields, sync checkpoints, local audit events and indexes requested by Task 13. It does not currently include an audit event in the save transaction. There are no tests visible for the specified Drift behaviors.
- The local manager repository seeds hard-coded demo shop/menu/waiters/shifts, calculates local sales/count, and enqueues pending operations. Its pending count and local save behavior should not be interpreted as a completed server sync engine.

## Observed inconsistencies and risks

- The router refresh uses the fake auth repository despite the Firebase auth repository being the provider default.
- Firestore rules and the Functions code have no visible client-side Firestore/Functions integration here. Functions accept owner IDs and do not visibly verify caller authorization/claims in the callable handlers; deployment/security review is needed before production use.
- `createSubshop` synthesizes manager email as `@example.com`, while manager login mapping must agree with this fixed domain.
- The order model/database stores only total and menu item ID/price/quantity, so old-order name snapshots and subtotal/line totals are absent; manager stats query local timestamps and no business-day linkage exists.
- Existing `SyncStatus.synced` and `markOrderSynced` are present, but no sync worker/server acknowledgement flow was found in Flutter. Any current status display should not be taken as evidence that remote sync occurred.
- User-provided roles include waiter as a non-login staff name; waiters are local rows only in the current database and are not scoped to a subshop.
- `firebase_options.dart` is generated app configuration, not a service-account key. Do not treat its Firebase client identifiers as secret credentials.

## Analyzer

The most recent `flutter analyze --no-pub` completed successfully with `No issues found!` after Task 16 follow-up changes.

## Task 14 update

- Added `cloud_functions 6.5.0` as an exact Flutter dependency; `flutter pub get` succeeded and updated `pubspec.lock`.
- Added `OrderSyncService`, which watches the durable Drift queue while the manager home is active, sends queued `saveOrder` entries to the callable, checks the acknowledged operation ID, and only then marks the local order synced/removes its queue row. Failures persist an incremented retry count and retry with capped exponential backoff plus jitter. It never marks an operation synced on timeout/error.
- Local order payloads now include local creation time and shift ID fields to support consistent server submissions.
- Added the `submitOrder` callable. It authenticates the caller, resolves exactly one active subshop from the caller's manager UID, validates positive integer line prices/quantities and exact `totalPaisa` arithmetic, uses `operationId` as the Firestore document ID, and returns the same acknowledgement for a matching retry. Reusing an operation ID for different content is rejected.
- Manager account creation now uses the same `@manager.hisaab.internal` email domain as the Flutter login mapping. Existing accounts created under the former `@example.com` domain will not automatically migrate.
- The Functions TypeScript build (`npm run build`) succeeded. Flutter package resolution succeeded. `flutter analyze` did not return within about a minute and was interrupted; no Dart analyzer result is available. No tests were run.
- Scope limit: the current Task 13 schema still has no business-day/subshop/order-name snapshot fields. The callable validates arithmetic consistency, but cannot validate submitted item prices against an authoritative server menu because no server menu model/path is present. The worker runs when the manager home is active; it does not provide an OS background task.

## Task 16 update

- Added pinned Flutter packages for Firestore owner listeners, Firebase App Check, secure session storage, PDF and Excel export. `pdf` is pinned at 3.12.0 because the newer release depends on `xml ^7`, conflicting with the selected Excel package's XML constraint.
- Owner dashboard now reads the owner's branches and each branch's subshops with bounded queries (50 branches, at most 100 subshops per branch) and bounded live listeners (up to 5,000 cards). Dashboard status distinguishes pending, offline/cache, and a server-confirmed current-day update.
- Owner report export is implemented through PDF and Excel generation and the platform share sheet. Excel stores money as integer paisa; PDF renders PKR values from integer paisa.
- Device-session enforcement uses an install UUID in secure storage, an App-Check enforced `claimDeviceSession` callable, custom role/scope claims, a Firestore session listener and sign-out when another session replaces the current one. Credentials/tokens are not put in SQLite.
- App Check initializes before app startup and is enforced on callable Functions. Flutter uses debug providers in debug mode and platform attestation/reCAPTCHA providers in supported release platforms. Windows currently supports only the debug App Check provider in the pinned FlutterFire plugin; release startup fails explicitly there. Web release requires a deployment-supplied reCAPTCHA site key.
- `firestore.rules` now limits owner and manager reads to their claim/path scope and denies client writes to protected business/session data. Emulator-based security rules tests were added under `functions/test`.
- Verification: Flutter analysis passed with no issues; `npm run build` passed. The rules test TypeScript compilation passed, but emulator execution could not start because this machine has Java 17 and the installed Firebase CLI requires Java 21 or newer. `functions/package-lock.json` was refreshed with compatible pinned rules-test dependencies.
- Deployment follow-up: App Check enforcement must also be enabled for Firestore in the Firebase project console; callable enforcement is configured in code. No project deployment was run. Windows release startup is explicitly rejected because the selected FlutterFire App Check plugin offers only a debug provider for Windows; Windows debug requires a Firebase-registered debug token supplied through a build define. Dashboard repository currently expects a `dashboardDate`, `todaySalesPaisa`, `todayOrderCount`, `lastSyncedAt`, and `dayStatus` summary maintained by `submitOrder`; legacy subshops without those fields will initially appear waiting/pending.

## Local-first sync follow-up

- Manager waiter, menu category, menu item, and shift writes now commit to Drift and enqueue a `syncManagerData` operation in the same SQLite transaction. Existing order writes continue to use the durable outbox and `submitOrder`.
- The sync worker retries catalog mutations with the same bounded exponential backoff and removes the outbox entry only after the callable acknowledges the matching operation ID.
- `syncManagerData` validates manager scope and catalog fields, writes to subshop subcollections (`waiters`, `menu_categories`, `menu_items`, `shifts`) via Admin SDK, records idempotency receipts, and increments server versions. Client rules allow scoped reads and deny client writes for these collections.
- A Firestore listener caches those manager catalogs into Drift, protecting locally queued versions from server snapshots until their pending mutation is acknowledged. Hard-coded demo catalog seeding was removed from production repository startup.
- Owner dashboard cards remain Firestore-backed and real-time; their latest snapshots are stored in a local SQLite outbox-backed cache entry and emitted first when the owner next opens the dashboard. Cache entries are excluded from pending-sync counts and are never uploaded.
- The existing `ManagerRepository`, `OwnerReportsRepository`, model, and navigation interfaces were preserved. Owner shops/governance and detailed reports still use their existing fake repositories; only the live owner dashboard is currently sourced from Firestore. Cross-device catalog data is pulled from Firestore into local cache when the manager home opens.
- Modified additional files: `lib/core/database/app_database.dart`, `lib/core/database/database_provider.dart`, manager repository/sync/provider files, owner report repository/provider, `functions/src/index.ts`, `functions/test/firestore.rules.test.ts`, `firestore.rules`, `functions/package.json`, `functions/package-lock.json`, and Functions TypeScript configs.
