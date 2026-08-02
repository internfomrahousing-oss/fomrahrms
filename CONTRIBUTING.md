# Running checks locally

GitHub Actions has been removed (billing), so **nothing runs these
automatically any more**. Run them yourself before pushing:

```bash
flutter pub get
flutter analyze          # static analysis
flutter test             # unit tests
flutter build web --release --no-tree-shake-icons
```

## Why this matters more than it used to

The test suite in `test/` pins behaviour that decides real numbers —
permission minutes, earned-leave accrual, the 26th-to-25th attendance cycle,
and the payroll maths. Several of those tests are *characterisation* tests:
they assert current behaviour **including known bugs**, each marked `BUG` in a
comment. They are meant to fail when the bug is fixed, so the expectation is
updated in the same commit as the fix.

With no CI, a broken test is now invisible until someone runs it. If you change
anything in `lib/models/leave_store.dart`, `lib/utils/attendance_cycle.dart`,
`lib/utils/el_accrual.dart` or `lib/models/payslip_store.dart`, run
`flutter test` before you push.

## Deployment

- **Vercel** builds and deploys the web app automatically on push to `main`
  (see `vercel-build.sh`). This is unaffected by the removal of Actions.
- **GitHub Pages** was published by the deleted workflow and will now go
  stale. Vercel is the live deployment.
- **Supabase Edge Functions** and **migrations** are deployed separately and
  were never part of the workflow.
