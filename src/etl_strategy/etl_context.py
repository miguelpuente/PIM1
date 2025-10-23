from typing import List, Tuple, Dict, Any
import pandas as pd
from ..config import DATA_DIR
from .base_loader import BaseLoader
from .simple_loader import SimpleLoader
from .sales_loader import SalesLoader


class ETLContext:
    """Define el contexto y gestiona la ejecución de las estrategias de carga."""
    
    def __init__(self, load_order: List[Tuple[str, str, str]]) -> None:
        self.load_order = load_order
        self.strategies = {
            'simple': SimpleLoader,
            'sales_specific': SalesLoader 
        }
        self.all_discarded_records: List[Dict[str, Any]] = []

    def run_etl(self) -> None:
        """Ejecuta el proceso ETL en el orden definido."""
        for file_name, table_name, strategy_key in self.load_order:
            
            StrategyClass = self.strategies.get(strategy_key)
            if not StrategyClass:
                print(f"Error: Estrategia '{strategy_key}' no definida.")
                continue

            loader: BaseLoader = StrategyClass(file_name, table_name, DATA_DIR)
            
            try:
                df = pd.read_csv(loader.file_path)
                loader.load(df) # La función load llama a clean internamente
                
                # Si es la tabla sales, capturar los descartados para el reporte final
                if table_name == 'sales':
                    self.all_discarded_records.extend(loader.discarded_records)
                    
            except FileNotFoundError:
                print(f"ERROR: Archivo '{file_name}' no encontrado en {DATA_DIR}.")
            except Exception as e:
                print(f"Fallo crítico en la carga de {table_name}: {e}")

    def report_discarded(self) -> None:
        """Imprime el reporte de los registros de venta descartados."""
        if self.all_discarded_records:
            # ... (Lógica de reporte con pandas y to_markdown, similar a la anterior) ...
            df_report = pd.DataFrame(self.all_discarded_records)
            
            # ... (Imprimir el reporte con to_markdown) ...
            print("\n\n#########################################################")
            print("# REPORTE DETALLADO DE REGISTROS DESCARTADOS (SALES) #")
            print("#########################################################")
            print(f"Total de registros de ventas descartados: {len(self.all_discarded_records)}\n")
            
            # Mostrar solo las columnas clave y los IDs para el reporte
            columns_to_show = ['sales_id', 'product_id', 'customer_id', 'sales_person_id', 'quantity', 'total_price', 'sales_date']
            
            print(df_report[columns_to_show].to_markdown(index=False))
            
            # Muestra un resumen de los IDs de producto faltantes
            missing_product_ids = df_report['product_id'].unique().tolist()
            print(f"\nIDs de Productos Faltantes (Causa del Descarte): {missing_product_ids}")