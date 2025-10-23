import pandas as pd
from typing import Set
from ..utils import format_column_names, execute_load
from ..db_connector import get_psycopg2_conn
from .base_loader import BaseLoader


class SalesLoader(BaseLoader):
    """
    Estrategia de carga para la tabla 'sales' (Ventas).
    Implementa la lógica de validación de Claves Foráneas (FK) 
    y captura los registros descartados para el reporte de integridad.
    """

    def _get_existing_ids(self, table_name: str, id_column: str) -> Set[int]:
        """Obtiene un conjunto de todos los IDs existentes de una tabla padre consultando la BD."""
        conn = get_psycopg2_conn()
        if not conn:
            print(f"Error de conexión al buscar IDs en '{table_name}'.")
            return set()
            
        try:
            with conn.cursor() as cur:
                # Selecciona el ID y lo convierte a INT para una comparación limpia
                cur.execute(f"SELECT {id_column} FROM {table_name}")
                # Usa un conjunto (set) para búsquedas O(1)
                return {int(row[0]) for row in cur.fetchall() if row[0] is not None}
        except Exception as e:
            print(f"ERROR al obtener IDs de {table_name}: {e}")
            return set()
    
    def _get_product_prices(self) -> dict[int, float]:
        """Obtiene un diccionario de ProductID a Price para recalcular TotalPrice."""
        conn = get_psycopg2_conn()
        if not conn:
            print("Error de conexión al buscar precios de productos.")
            return {}
            
        print("Buscando precios de productos para enriquecimiento...")
        try:
            with conn.cursor() as cur:
                # Seleccionamos el product_id y el price
                cur.execute("SELECT product_id, price FROM products")
                # Convertir a un diccionario para búsquedas rápidas
                return {int(row[0]): float(row[1]) for row in cur.fetchall() if row[0] is not None and row[1] is not None}
        except Exception as e:
            print(f"ERROR al obtener precios de products: {e}")
            return {}

    def clean(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Aplica limpieza, enriquecimiento (cálculo de precio) y validación de integridad referencial.
        """
        # ... (Mantener la sección inicial de copias y format_column_names) ...
        initial_df_for_report = df.copy() 
        df = format_column_names(df)
        df = df.dropna(how='all')

        # 1. Conversión de tipos de Claves Foráneas y valores. Convertir Discount a float.
        df['product_id'] = pd.to_numeric(df['product_id'], errors='coerce').astype('Int64')
        df['customer_id'] = pd.to_numeric(df['customer_id'], errors='coerce').astype('Int64')
        df['sales_person_id'] = pd.to_numeric(df['sales_person_id'], errors='coerce').astype('Int64')
        
        df['quantity'] = pd.to_numeric(df['quantity'], errors='coerce').astype('Int64')
        # Aseguramos que discount sea float para la multiplicación
        df['discount'] = pd.to_numeric(df['discount'], errors='coerce').fillna(0.0)
        
        # 2. Obtener IDs válidos y Precios (Consulta a la BD)
        product_ids = self._get_existing_ids('products', 'product_id')
        customer_ids = self._get_existing_ids('customers', 'customer_id')
        employee_ids = self._get_existing_ids('employees', 'employee_id')
        
        # --- NUEVO PASO: OBTENER Y ENRIQUECER PRECIOS ---
        product_prices = self._get_product_prices()
        
        # Crear una columna temporal con el precio unitario usando el diccionario de precios
        df['unit_price'] = df['product_id'].apply(lambda x: product_prices.get(x, None))

        # 3. Recalcular TotalPrice: Usamos unit_price, quantity y discount
        # Solo calculamos si unit_price y quantity no son nulos
        mask_calculable = df['unit_price'].notna() & df['quantity'].notna()
        
        # Recálculo: (quantity * unit_price) * (1 - discount)
        df.loc[mask_calculable, 'total_price'] = \
            (df.loc[mask_calculable, 'quantity'] * df.loc[mask_calculable, 'unit_price']) * \
            (1 - df.loc[mask_calculable, 'discount'])
            
        # IMPORTANTE: Eliminar la columna 'unit_price' para que no se inserte en la tabla 'sales'
        df = df.drop(columns=['unit_price'])
        
        # --- FIN DEL ENRIQUECIMIENTO ---

        # 4. Validar integridad (usando product_ids y las máscaras como antes)
        valid_mask_products = df['product_id'].isin(product_ids)
        valid_mask_customers = df['customer_id'].isin(customer_ids)
        valid_mask_employees = df['sales_person_id'].isin(employee_ids)
        
        # También descartamos cualquier fila donde el total_price no pudo calcularse (por producto faltante)
        # Aunque esto ya está cubierto por valid_mask_products, es una capa extra de seguridad.
        valid_mask_price = df['total_price'].notna() 
        
        valid_mask_total = valid_mask_products & valid_mask_customers & valid_mask_employees & valid_mask_price
        
        # ... (Resto del código de captura de descartados y reporte, sin cambios) ...

        # Capturar las filas a descartar (necesarias para el reporte final)
        df_discarded_report = df[~valid_mask_total].copy()
        self.discarded_records = df_discarded_report.to_dict('records')
        
        # Aplicar la limpieza final
        df_cleaned = df[valid_mask_total]
        
        # Almacenar conteos para el método load()
        self._initial_count = len(initial_df_for_report)
        self._final_count = len(df_cleaned)
        
        # Calcular los descartados por FK para el reporte (usando el DF original para conteo)
        df_initial_for_report = format_column_names(initial_df_for_report)
        self._dropped_prod = len(df_initial_for_report[~df_initial_for_report['product_id'].isin(product_ids)])
        self._dropped_cust = len(df_initial_for_report[~df_initial_for_report['customer_id'].isin(customer_ids)])
        self._dropped_emp = len(df_initial_for_report[~df_initial_for_report['sales_person_id'].isin(employee_ids)])

        return df_cleaned

    def load(self, df: pd.DataFrame) -> int:
        """
        Orquesta la limpieza, el reporte de integridad y la carga en la BD.
        """
        print(f"--- Procesando {self.file_name} -> Tabla: {self.table_name} ---")
        
        try:
            df_cleaned = self.clean(df.copy())
            
            total_dropped = self._initial_count - self._final_count
            
            # 1. Reporte de conteos
            if total_dropped > 0:
                print("\n ALERTA DE INTEGRIDAD: FILAS DESCARTADAS EN 'sales'")
                print(f"   Total de filas leídas: {self._initial_count}")
                print(f"   Total de filas cargadas: {self._final_count}")
                print(f"   Total de filas descartadas: {total_dropped}")
                print("   Detalle de filas descartadas por FK (puede haber superposición):")
                print(f"   - Productos ({self._dropped_prod} filas)")
                print(f"   - Clientes ({self._dropped_cust} filas)")
                print(f"   - Empleados ({self._dropped_emp} filas)")
            
            # 2. Carga en la BD
            execute_load(df_cleaned, self.table_name)
            
            print(f" Registros en el CSV de entrada: {self._initial_count}")
            print(f" Registros en la BD de salida: {self._final_count}")
            print(f" ¡{self._final_count} registros cargados MÁS RÁPIDO en la tabla '{self.table_name}'!")
            
            return self._final_count
            
        except Exception as e:
            print(f"ERROR inesperado al cargar datos de {self.file_name}: {e}")
            return 0