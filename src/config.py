from decouple import config
from pathlib import Path

# --- Rutas de Archivos ---
BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "data"
DDL_PATH = BASE_DIR / "sql" / "schema_pim1_ddl.sql"

# --- Configuración de Base de Datos ---
try:
    DB_HOST = config('DB_HOST')
    DB_NAME = config('DB_NAME')
    DB_USER = config('DB_USER')
    DB_PASS = config('DB_PASS')
    DB_PORT = config('DB_PORT', default='5432')
except Exception as e:
    raise RuntimeError(f"Error al cargar la configuración desde .env: {e}")

DATABASE_URL_SQLA = f"postgresql+psycopg2://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

# Definición del orden de carga y su estrategia
LOAD_ORDER = [
    ('countries.csv', 'countries', 'simple'),
    ('cities.csv', 'cities', 'simple'),
    ('categories.csv', 'categories', 'simple'),
    ('customers.csv', 'customers', 'simple'),
    ('employees.csv', 'employees', 'simple'),
    ('products.csv', 'products', 'simple'),
    ('sales.csv', 'sales', 'sales_specific') # Usa la estrategia especial
]