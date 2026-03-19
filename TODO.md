# FitOS - Pending Tasks

## Supabase Migration (Phase 4) - NEXT STEP

We're migrating the database + file storage from Render to Supabase.

**Supabase project is already created** (EU region, org: FitOS, project: FitOS - db - storage).

### What needs to be done:
1. Get the Supabase **connection string** from: Supabase Dashboard > Settings > Database > Connection string > URI tab
2. Dump data from the current Render PostgreSQL database
3. Import schema + data into Supabase
4. Add Row-Level Security (RLS) policies for consent-based access
5. Migrate file storage (profile pictures, certificates, exercise videos) to Supabase Storage
6. Update Render's `DATABASE_URL` environment variable to point to Supabase
7. Test everything end-to-end

### Current Render DB credentials (to dump from):
```
postgresql://gym_user_eu:P3V0QtJ2VRbW35gUiwVoAgzPCmEc8JcW@dpg-d6t805aa214c73cdk0vg-a.frankfurt-postgres.render.com/gym_db_eu_jfdi
```

### What was already done:
- Phase 1: Consent tables + authorization module (authorization.py)
- Phase 2: 20 sensitive routes protected with gym isolation + consent checks
- Phase 3: Flutter consent management UI (grant/revoke permissions)

### Architecture after migration:
- **Render** = FastAPI backend only
- **Supabase** = PostgreSQL database + file storage + realtime
