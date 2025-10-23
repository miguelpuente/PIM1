import re
import pandas as pd
from psycopg2.extras import execute_values
from .db_connector import get_psycopg2_conn

def format_column_names(df: pd.DataFrame) -> pd.DataFrame:
    """Convierte los nombres de las columnas a snake_case."""
    def to_snake_case(name):
        name = re.sub('(.)([A-Z][a-z]+)', r'\1_\2', name)
        return re.sub('([a-z0-9])([A-Z])', r'\1_\2', name).lower()
    
    df.columns = [to_snake_case(col) for col in df.columns]
    
    # Manejo de casos específicos
    if 'category_i_d' in df.columns:
        df = df.rename(columns={'category_i_d': 'category_id'})
        
    return df

def execute_load(df: pd.DataFrame, table_name: str) -> None:
    """Ejecuta la carga masiva optimizada."""
    conn = get_psycopg2_conn()
    df = df.where(pd.notnull(df), None)
    
    data_values = [tuple(row) for row in df.values]
    columns = df.columns.tolist()

    try:
        with conn.cursor() as cur:
            insert_query = f"INSERT INTO {table_name} ({', '.join(columns)}) VALUES %s"
            execute_values(cur, insert_query, data_values, page_size=10000)
            conn.commit()
    except Exception as e:
        conn.rollback()
        raise e