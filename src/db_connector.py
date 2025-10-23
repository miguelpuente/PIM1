from sqlalchemy import create_engine, text
import psycopg2
from .config import DATABASE_URL_SQLA, DB_HOST, DB_NAME, DB_USER, DB_PASS, DB_PORT, DDL_PATH

# --- Conexión SQLAlchemy (para DDL y transacciones simples) ---
try:
    engine = create_engine(DATABASE_URL_SQLA)
except Exception as e:
    print(f"ERROR al crear el motor de SQLAlchemy: {e}")
    engine = None

# --- Conexión Psycopg2 (para execute_values) ---
try:
    conn = psycopg2.connect(
        host=DB_HOST, database=DB_NAME, user=DB_USER, password=DB_PASS, port=DB_PORT
    )
    conn.autocommit = False
except Exception as e:
    print(f"ERROR al conectar con Psycopg2: {e}")
    conn = None

def create_schema():
    """Ejecuta el DDL desde el archivo SQL."""
    if not engine:
        print("No se pudo crear el esquema: motor de BD no disponible.")
        return
        
    print("\n--- Ejecutando DDL: Creando/Recreando el esquema de la base de datos ---")
    try:
        ddl_script = DDL_PATH.read_text(encoding='utf-8')
        with engine.begin() as connection:
            connection.execute(text(ddl_script))
        print("Esquema creado/recreado exitosamente.")
    except FileNotFoundError:
        print(f"ERROR: El archivo DDL '{DDL_PATH}' no fue encontrado.")
        exit()
    except Exception as e:
        print(f"ERROR al ejecutar el DDL: {e}")
        exit()

def get_psycopg2_conn():
    """Retorna la conexión psycopg2."""
    return conn