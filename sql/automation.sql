-- DDL: Creación de la Tabla de Monitoreo

CREATE TABLE product_monitoring (
    monitor_id SERIAL PRIMARY KEY, -- ID autoincremental para la tabla de registro
    product_id INT NOT NULL,
    product_name VARCHAR(45) NOT NULL,
    total_units_sold INT NOT NULL,
    exceeded_date TIMESTAMP WITHOUT TIME ZONE NOT NULL, -- Fecha de la venta que superó el umbral
    registered_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Análisis: Esta tabla registra eventos de negocio críticos, como un producto superando un volumen de ventas clave (200,000 unidades), proporcionando trazabilidad y datos históricos para la toma de decisiones.

-- DDL: Función para el Trigger (PostgreSQL/PL/pgSQL)

CREATE OR REPLACE FUNCTION check_sales_threshold()
RETURNS TRIGGER AS $$
DECLARE
    v_total_units_sold INT;
    v_product_name VARCHAR(45);
    v_threshold INT := 200000; -- Definición del umbral
BEGIN
    -- 1. Calcular la cantidad acumulada del producto después de la inserción (incluyendo la nueva venta)
    SELECT
        SUM(quantity) INTO v_total_units_sold
    FROM sales
    WHERE product_id = NEW.product_id;

    -- 2. Verificar si el total acumulado supera o iguala el umbral
    IF v_total_units_sold >= v_threshold THEN
        -- 3. Obtener el nombre del producto de la tabla products
        SELECT product_name INTO v_product_name FROM products WHERE product_id = NEW.product_id;

        -- 4. Insertar el registro en la tabla de monitoreo
        INSERT INTO product_monitoring (
            product_id,
            product_name,
            total_units_sold,
            exceeded_date
        )
        VALUES (
            NEW.product_id,
            v_product_name,
            v_total_units_sold,
            NEW.sales_date -- Usamos la fecha de la venta que activó el evento
        );
    END IF;

    RETURN NEW; -- Retorna el registro insertado (requerido para triggers AFTER INSERT)
END;
$$ LANGUAGE plpgsql;

-- DDL: Creación del Trigger

CREATE TRIGGER sales_threshold_trigger
AFTER INSERT ON sales
FOR EACH ROW -- Se activa por cada fila insertada
EXECUTE FUNCTION check_sales_threshold();

-- Análisis: El uso de un trigger AFTER INSERT con la cláusula FOR EACH ROW garantiza la verificación inmediata del umbral tras cada transacción. Esto es esencial para sistemas de monitoreo en tiempo casi real, pues verifica el estado ACUMULADO del producto, no solo la venta actual, asegurando la integridad del registro de eventos.