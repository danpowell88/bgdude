---
name: user-guide-sync
description: Keep bgdude's user guide current on any user-visible change. Use whenever you add, change, or remove a feature, page, panel, icon, notification category, mode, report, or setting. doc/user-guide.html is the source of truth for how to use the app; doc/index.html is the marketing overview.
---

# Keep the user guide current

`doc/user-guide.html` is a page-by-page walk-through of every screen, panel, and icon
(purpose + how to use). **Whenever you add, change, or remove a feature, page, panel, icon,
notification category, mode, report, or setting, update `doc/user-guide.html` in the same
change** so it never drifts from the app. If the change is user-visible, it belongs in the
guide.

Keep the marketing/overview doc `doc/index.html` roughly in step too, but the user guide is
the source of truth for "how to use it".

## New screens → regenerate screenshots

When a change adds a new screen, also regenerate screenshots when an emulator is available,
then reference the new PNG in both docs:

```
flutter drive --driver=test_driver/screenshot_driver.dart \
  --target=integration_test/screenshots_test.dart -d <device>
```
