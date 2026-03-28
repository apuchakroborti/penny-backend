# Wishing Well Django Backend

This repository now contains a Django + Django REST Framework backend scaffolded around the existing PostgreSQL schema in [`database`](./database). The SQL files remain the source of truth for the product schema and are intentionally not modified.

## What This Project Includes

- Django project configured for PostgreSQL
- Django admin for operational management
- DRF CRUD endpoints for all schema tables
- Read-only DRF endpoints for the SQL views
- Token authentication for API consumers
- Admin-managed API access grants for Django users and groups
- OpenAPI schema plus Swagger/ReDoc docs
- Request middleware that sets `app.current_user_id` from `X-Current-User-Id` so the database RLS policies can work as designed

## Project Structure

```text
.
├── api/                       # Unmanaged models, serializers, viewsets, endpoint registry
├── access_control/            # Managed models for API catalog and endpoint grants
├── config/                    # Django settings, URL config, ASGI/WSGI
├── database/                  # Existing PostgreSQL schema files (unchanged)
├── templates/admin/           # Admin landing page links for docs and access control
├── manage.py
└── requirements.txt
```

## Important Design Decision

The tables and views defined in [`database/003_tables.sql`](./database/003_tables.sql) and [`database/007_views.sql`](./database/007_views.sql) are mapped as `managed = False` Django models. That means:

- Django will not try to recreate or alter the Wishing Well product schema.
- Your SQL files remain canonical.
- You should load the SQL files first, then run Django migrations only for Django/admin/auth/access-control tables.

## Setup

1. Create a virtual environment and install dependencies.

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

2. Copy the environment template and set the PostgreSQL connection.

```bash
cp .env.example .env
```

3. Load the Wishing Well database schema in PostgreSQL without changing the SQL files.

```bash
psql "$DATABASE_URL" -f database/001_extensions.sql
psql "$DATABASE_URL" -f database/002_enums.sql
psql "$DATABASE_URL" -f database/003_tables.sql
psql "$DATABASE_URL" -f database/004_indexes.sql
psql "$DATABASE_URL" -f database/005_functions.sql
psql "$DATABASE_URL" -f database/006_triggers.sql
psql "$DATABASE_URL" -f database/007_views.sql
psql "$DATABASE_URL" -f database/008_rls.sql
psql "$DATABASE_URL" -f database/009_seed.sql
```

4. Run Django migrations for admin/auth/token/access-control tables.

```bash
python manage.py migrate
```

5. Build the admin API catalog.

```bash
python manage.py sync_api_endpoints
```

6. Create an admin user.

```bash
python manage.py createsuperuser
```

7. Start the server.

```bash
python manage.py runserver
```

## Admin Experience

Open `http://127.0.0.1:8000/admin/`.

From the admin home page you can:

- open Swagger UI
- open ReDoc
- review the API endpoint catalog
- assign endpoint access to specific Django users or groups
- manage all business tables directly through Django admin

## Authentication And Access Control

### Django Admin / Session Auth

- Staff and superusers can sign into `/admin/`.
- Staff and superusers bypass API endpoint grant checks.

### Django Admin Token Auth

Request a DRF token:

```bash
curl -X POST http://127.0.0.1:8000/api/auth/token/ \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"your-password"}'
```

Use it in admin/internal API calls:

```bash
curl http://127.0.0.1:8000/api/users/ \
  -H "Authorization: Token YOUR_TOKEN"
```

This token endpoint authenticates against Django's `auth_user` table and is intended for admin/internal access, not app-user signup/login.

### App User Auth

App users should use the product auth flow instead:

1. `POST /api/users/` to sign up
2. `POST /api/login/` to log in with `email` and `password`
3. Reuse the returned app token on protected endpoints

Example login:

```bash
curl -X POST http://127.0.0.1:8000/api/login/ \
  -H "Content-Type: application/json" \
  -d '{"email":"flow-check@example.com","password":"Secret123"}'
```

Example response:

```json
{
  "authenticated": true,
  "token": "APP_USER_TOKEN",
  "user_id": "948a7f5c-28b2-4280-82b4-6eb5bfcb5041"
}
```

Use that token on protected endpoints:

```bash
curl http://127.0.0.1:8000/api/me/ \
  -H "Authorization: Bearer APP_USER_TOKEN"
```

`Token APP_USER_TOKEN` is also accepted for compatibility, but `Bearer` is the preferred format for app users.

### Endpoint Grants

Non-staff authenticated users need explicit grants in admin:

- add or sync records in `Api Endpoint`
- create `Api Access Grant` rows for a user or group

This lets admin control which REST endpoints each consumer can call.

## RLS Header

The SQL in [`database/008_rls.sql`](./database/008_rls.sql) expects `app.current_user_id` to be set in PostgreSQL.

This Django project sets it from the request header:

```http
X-Current-User-Id: 00000000-0000-0000-0000-000000000000
```

Use that header when testing routes that read RLS-protected tables such as `users`, `wishes`, `messages`, `notifications`, `conversations`, and `blocks`.

For app-user requests authenticated with the new bearer token or login session, the backend also sets the PostgreSQL user context automatically.

## API Surface

### Table-backed endpoints

- `/api/users/`
- `/api/user-tags/`
- `/api/wishes/`
- `/api/wish-tags/`
- `/api/interactions/`
- `/api/matches/`
- `/api/conversations/`
- `/api/messages/`
- `/api/emotional-patterns/`
- `/api/moderation-logs/`
- `/api/reports/`
- `/api/blocks/`
- `/api/notifications/`
- `/api/subscriptions/`
- `/api/aura-customizations/`

### View-backed endpoints

- `/api/views/public-wish-feed/`
- `/api/views/user-emotional-summary/`
- `/api/views/active-matches/`
- `/api/views/match-graph/`

### API docs

- `/api/schema/`
- `/api/docs/swagger/`
- `/api/docs/redoc/`
- `/api/login/`
- `/api/me/`
- `/api/logout/`

## Notes

- The project uses PostgreSQL-specific fields such as `ArrayField` and `VectorField`.
- `users.email_hash` is exposed as a hex string in the API serializer.
- The built-in Django auth tables are separate from the product `users` table defined in the SQL schema.
- Because the business schema is unmanaged in Django, structural changes to product tables should continue to happen in the SQL files under [`database`](./database).
