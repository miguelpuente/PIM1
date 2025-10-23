import pandas as pd
from ..utils import format_column_names, execute_load
from .base_loader import BaseLoader


class SimpleLoader(BaseLoader):
    """Estrategia de carga para tablas simples (sin FKs de entrada complejas)."""

    def clean(self, df: pd.DataFrame) -> pd.DataFrame:
        df = format_column_names(df)
        df = df.dropna(how='all')

        # Conversión de tipos genérica
        for col in df.columns:
            if col.endswith('_id') or col.endswith('_days') or col == 'zipcode' or col == 'price' or col == 'total_price' or col == 'discount':
                df[col] = pd.to_numeric(df[col], errors='coerce') 

        return df

    def load(self, df: pd.DataFrame) -> int:
        print(f"--- Procesando {self.file_name} -> Tabla: {self.table_name} ---")
        initial_count = len(pd.read_csv(self.file_path))

        try:
            df_cleaned = self.clean(df.copy())
            final_count = len(df_cleaned)

            execute_load(df_cleaned, self.table_name)

            if final_count == 0:
                print(f"ADVERTENCIA: No se cargaron registros en la tabla '{self.table_name}'. Verifique los datos de entrada.")
            if final_count < initial_count:
                print(f"ADVERTENCIA: Se eliminaron {initial_count - final_count} registros durante la limpieza de datos.")
                print("Detalle de registros eliminados:")
                for record in self.discarded_records:
                    print(f" - {record}")

            print(f"¡{final_count} registros cargados en la tabla '{self.table_name}'!")

            return final_count
        except Exception as e:
            print(f"ERROR inesperado al cargar datos de {self.file_name}: {e}")
            return 0
