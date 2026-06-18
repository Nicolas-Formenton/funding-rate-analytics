# Superset configuration — Funding Rate Analytics
# Loaded via SUPERSET_CONFIG_PATH /app/pythonpath/superset_config.py
# Secrets are injected from the host .env file (gitignored).

import os


# ---- Core ----
SECRET_KEY = os.environ.get("SUPERSET_SECRET_KEY", "dev-only-not-for-prod-change-me")
WTF_CSRF_ENABLED = True
WTF_CSRF_EXEMPT_LIST = ["superset.views.core.log", "superset.charts.data.api.data"]
WTF_CSRF_TIME_LIMIT = 60 * 60 * 24 * 7  # 7 days

# ---- Metadata database ----
# Comes from the SUPERSET_DATABASE_URI env var set in docker-compose
SQLALCHEMY_DATABASE_URI = os.environ["SUPERSET_DATABASE_URI"]
SQLALCHEMY_TRACK_MODIFICATIONS = False
SQLALCHEMY_ENGINE_OPTIONS = {
    "pool_size": 5,
    "max_overflow": 10,
    "pool_timeout": 30,
    "pool_recycle": 1800,
    "pool_pre_ping": True,
}

# ---- Feature flags ----
# Enable the default config base
FEATURE_FLAGS = {
    "ENABLE_TEMPLATE_PROCESSING": True,
    "DASHBOARD_CROSS_FILTERS": True,
    "DASHBOARD_RBAC": True,
    "EMBEDDED_SUPERSET": False,
    "ALERT_REPORTS": False,  # turn on later if cron is added
    "THUMBNAILS": False,     # requires Celery + thumbnailing worker
}
SUPERSET_LOG_VIEW = True
LOG_LEVEL = "INFO"

# ---- Caching (in-process, no Redis required for this dev setup) ----
CACHE_CONFIG = {
    "CACHE_TYPE": "SimpleCache",
    "CACHE_DEFAULT_TIMEOUT": 300,
    "CACHE_KEY_PREFIX": "superset_",
}
DATA_CACHE_CONFIG = {
    "CACHE_TYPE": "SimpleCache",
    "CACHE_DEFAULT_TIMEOUT": 300,
    "CACHE_KEY_PREFIX": "superset_data_",
}
FILTER_STATE_CACHE_CONFIG = {
    "CACHE_TYPE": "SimpleCache",
    "CACHE_DEFAULT_TIMEOUT": 86400,
    "CACHE_KEY_PREFIX": "superset_filter_",
}
EXPLORE_FORM_DATA_CACHE_CONFIG = {
    "CACHE_TYPE": "SimpleCache",
    "CACHE_DEFAULT_TIMEOUT": 86400,
    "CACHE_KEY_PREFIX": "superset_explore_",
}

# ---- Supabase (target warehouse) — referenced by REST API on first login ----
# Host/port/user/database are stable; password is the only secret and is
# pulled from .env so it never lands in the tracked config.
SUPABASE_HOST = os.environ.get("SUPABASE_DB_HOST", "db.djtnqbvkhqftmtnsityx.supabase.co")
SUPABASE_PORT = int(os.environ.get("SUPABASE_DB_PORT", "5432"))
SUPABASE_DB = os.environ.get("SUPABASE_DB_NAME", "postgres")
SUPABASE_USER = os.environ.get("SUPABASE_DB_USER", "postgres")
SUPABASE_PASSWORD = os.environ.get("SUPABASE_DB_PASSWORD", "")
SUPABASE_SCHEMA = os.environ.get("SUPABASE_DB_SCHEMA", "marts")

SUPABASE_SQLALCHEMY_URI = (
    f"postgresql+psycopg2://{SUPABASE_USER}:{SUPABASE_PASSWORD}"
    f"@{SUPABASE_HOST}:{SUPABASE_PORT}/{SUPABASE_DB}"
)

# ---- Public role and row-level security ----
PUBLIC_ROLE_LIKE = "Gamma"
AUTH_USER_REGISTRATION = False
AUTH_USER_REGISTRATION_ROLE = "Public"

# ---- Misc ----
PREVIOUS_SECRET_KEY = None  # disable key rotation check
ENABLE_CORS = False
CORS_OPTIONS = {}
TRACK_USER_ACTIVITY = True
