from abc import ABC, abstractmethod
import pandas as pd

class BaseLoader(ABC):
    """Interfaz para la Estrategia de Carga de Datos."""
    
    def __init__(self, file_name: str, table_name: str, data_dir) -> None:
        self.file_name = file_name
        self.table_name = table_name
        self.file_path = data_dir / file_name
        self.discarded_records = []

    @abstractmethod
    def clean(self, df: pd.DataFrame) -> pd.DataFrame:
        """Aplica la lógica de limpieza y transformación específica."""
        pass

    @abstractmethod
    def load(self, df: pd.DataFrame) -> int:
        """Carga el DataFrame limpio en la base de datos."""
        pass