from src.db_connector import create_schema, conn
from src.config import LOAD_ORDER
from src.etl_strategy.etl_context import ETLContext

def main():
    # 1. Crear el esquema
    create_schema()

    # 2. Inicializar el contexto ETL con el orden de carga
    context = ETLContext(load_order=LOAD_ORDER)

    # 3. Ejecutar el ETL
    print("\nIniciando proceso de carga masiva de datos...")
    context.run_etl()

    # 4. Generar el reporte de integridad
    context.report_discarded()

    # 5. Cerrar la conexión
    if conn:
        conn.close()
    print("\n--- PROCESO DE CARGA DE DATOS FINALIZADO EXITOSAMENTE Y CONEXIÓN CERRADA ---")

if __name__ == '__main__':
    main()
