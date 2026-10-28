# sai_mate

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Manual-payment subscriptions

Open the account menu → **Subscription**. A shop owner can choose a configured
plan, transfer the displayed MMK amount, enter the transfer reference/date, and
upload a JPEG/PNG slip (maximum 5 MB). Submissions remain pending until a billing
reviewer verifies the actual incoming transfer. Approval starts or extends the
subscription; rejection shows the review note and allows a new submission.

### One-time Supabase setup

1. Run `supabase/upgrade_v7_subscriptions.sql` in your project's SQL Editor after
   the existing schema/upgrades. It creates billing tables, private slip storage,
   RLS policies and submission/review functions. It does not modify existing shop
   records. The migration is safe to rerun.
2. Register the account that will review payments in the app. In the SQL Editor,
   replace the email below with that account's actual email and run:

   ```sql
   insert into public.billing_reviewers(user_id)
   select id from auth.users where lower(email) = lower('YOUR_ADMIN_EMAIL')
   on conflict do nothing;

   select u.email
   from public.billing_reviewers r join auth.users u on u.id = r.user_id;
   ```

   Confirm that the intended account appears in the result. Reviewer privileges
   can only be provisioned through trusted database administration, never signup
   metadata or the mobile app.
3. Sign in as that reviewer, open **Subscription → Plans & payment accounts**,
   and add real plan prices/durations and bank/mobile-wallet recipient details.
   Disable an entry to stop offering it without deleting payment history.
   Checkout remains disabled until at least one plan and payment account exist.
4. Review submissions under **Subscription → Payment review**. Compare each slip
   to actual credits in your bank/wallet account before approval. The app does not
   automatically verify transfers and never automatically deducts money.

Prices, duration, and recipient details are captured on submission. The server
rejects a checkout when its displayed price, duration or account number changed.
A shop can have one pending payment. Repeated submission of the same request is
idempotent; repeated review cannot extend expiry twice. Renewal adds time after
any remaining active period. Slips cannot be overwritten or deleted by clients.

This adds subscription management and expiry tracking. It does not impose a
paywall on existing shop operations or define paid feature limits. Status refresh
uses pull-to-refresh/the refresh button. Submitting and reviewing need internet;
slips are not queued in the offline shop sync. Plan changes do not retroactively
change submitted requests. Failed submissions may leave private orphan uploads;
review storage retention before production cleanup and never delete referenced
slips. No live database migration or real payment was executed during development.

Storage and function permissions follow the official
[Supabase storage access-control](https://supabase.com/docs/guides/storage/security/access-control)
and [database function](https://supabase.com/docs/guides/database/functions) guidance.

### Verification

```sh
flutter analyze
flutter test
npm install --prefix /tmp/sai-billing-db-test --cache /tmp/sai-billing-npm-cache @electric-sql/pglite
PGLITE_MODULE=/tmp/sai-billing-db-test/node_modules/@electric-sql/pglite/dist/index.js node supabase/tests/subscriptions.mjs
```

The isolated PostgreSQL test uses minimal Supabase auth/storage fixtures, not the
live project. It checks reviewer authorization, cross-user isolation, immutable
slips, pending/duplicate checks, idempotency, rejection, renewal, quote changes,
and repeatable migration. Real Storage uploads, camera permissions, and payments
must still be checked against the configured Supabase project on a device.

For the existing relay test build:

```sh
flutter build apk --release --dart-define=SUPABASE_URL=https://sai-mate-api.winzawhein214199667.workers.dev
```
