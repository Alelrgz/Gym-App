# Gym App Project Memory

## Stripe Payments
- Appointment booking uses **Stripe Checkout Sessions** (hosted payment page) - avoids all iframe rendering issues
- Flow: Frontend → POST `/api/client/appointment-checkout-session` → redirect to Stripe → success callback creates appointment
- Success redirect: `/api/client/appointment-checkout-success?session_id=...` → creates appointment → redirects to `/?role=client&booking_success=true`
- Subscription plans still use inline Stripe Card Element (works fine in subscription modal)
- The subscription card element in app.js uses `color: '#ffffff'` and works
- `color-scheme: dark` on `:root` can cause issues with Stripe iframe rendering in dark-themed modals

## Architecture
- FastAPI backend with SQLAlchemy ORM, SQLite DB
- Templates: base.html (base) -> client.html/staff.html/trainer.html (pages) + modals.html (shared modals)
- client.html has multiple script blocks with function override patterns using `typeof` guards
- base.html has fallback JS functions that client.html overrides
- Server runs on port 9008 via `start_server.bat`

## Raspberry Pi Kiosk
- Hostname: `gymkiosk`
- Username: `gymtest`
- Password: `gymtest`
- Device API key: `83875f18-500e-4ab9-b9d5-15e7f1c2a204`
- Kiosk URL: `http://SERVER:9008/kiosk?key=83875f18-500e-4ab9-b9d5-15e7f1c2a204`
- Relay service: `raspberry_pi/relay_service.py` (Flask on localhost:5555)
- USB relay module: Songle 5V, USB-B, serial commands at 9600 baud

## Flutter App — Cross-Platform Requirement
- **CRITICAL**: The Flutter app must work on ALL platforms: Web, iOS, Android, desktop
- Target: thousands of clients on diverse devices
- **NEVER use `dart:html`, `dart:ui_web`, or other web-only APIs directly** — they break native builds
- Use platform-agnostic packages (e.g., `image_picker`, `camera`) or conditional imports for platform-specific code
- Existing web-only code (`camera_scanner.dart`, parts of `workout_screen.dart`, `trainer_courses_screen.dart`) needs refactoring before native builds
- **Conditional import pattern** established: `chat_camera_stub.dart` / `chat_camera_web.dart` / `chat_camera_native.dart` — use this pattern for any platform-specific code

## Common Gotchas
- Tailwind loaded via CDN script tag (not build step)
- `glass-card` class has `backdrop-filter: blur(20px)` - avoid for containers with Stripe/iframes
- Modals use `hidden` class (Tailwind `display:none`) - elements inside need delay before measuring
