-- ##########################################################################
-- # SCRIPT DE CREACIÓN DE BASE DE DATOS (DDL) - VENTAS POSTGRESQL          #
-- # Basado en el Diagrama Entidad-Relación proporcionado.                  #
-- # Autor: Miguel Puente                                                   #
-- ##########################################################################

-- 1. Tablas Geográficas (No tienen dependencias)

CREATE TABLE countries (
    country_id INT PRIMARY KEY,
    country_name VARCHAR(45) NOT NULL,
    country_code VARCHAR(2) UNIQUE
);

CREATE TABLE cities (
    city_id INT PRIMARY KEY,
    city_name VARCHAR(45) NOT NULL,
    zipcode DECIMAL(5, 0),
    country_id INT NOT NULL,
    FOREIGN KEY (country_id) REFERENCES countries (country_id)
);

-- 2. Tablas de Catálogo y Personas (Dependen de Geografía)

CREATE TABLE categories (
    category_id INT PRIMARY KEY,
    category_name VARCHAR(45) UNIQUE NOT NULL
);

CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    first_name VARCHAR(45) NOT NULL,
    middle_initial VARCHAR(1),
    last_name VARCHAR(45) NOT NULL,
    city_id INT,
    address VARCHAR(90),
    FOREIGN KEY (city_id) REFERENCES cities (city_id)
);

CREATE TABLE employees (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(45) NOT NULL,
    middle_initial VARCHAR(1),
    last_name VARCHAR(45) NOT NULL,
    birth_date DATE,
    gender VARCHAR(1), -- 'M' o 'F'
    city_id INT,
    hire_date DATE,
    FOREIGN KEY (city_id) REFERENCES cities (city_id)
);

-- 3. Tabla de Productos (Depende de Categorías)

CREATE TABLE products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(45) NOT NULL,
    price DECIMAL(10, 2) NOT NULL CHECK (price >= 0),
    category_id INT NOT NULL,
    class VARCHAR(45),
    modify_date VARCHAR(10),
    resistant VARCHAR(45),
    is_allergic VARCHAR(10),
    vitality_days DECIMAL(3, 0), -- Días de vida útil/vencimiento
    FOREIGN KEY (category_id) REFERENCES categories (category_id)
);

-- 4. Tabla de Transacciones (El corazón del modelo, depende de todo lo demás)

CREATE TABLE sales (
    sales_id INT PRIMARY KEY,
    sales_person_id INT NOT NULL,
    customer_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    discount DECIMAL(10, 2) DEFAULT 0.00 CHECK (discount >= 0),
    total_price DECIMAL(10, 2) NOT NULL CHECK (total_price >= 0),
    sales_date TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP, -- Usar TIMESTAMP para fecha y hora
    transaction_number VARCHAR(255) UNIQUE,
    FOREIGN KEY (sales_person_id) REFERENCES employees (employee_id),
    FOREIGN KEY (customer_id) REFERENCES customers (customer_id),
    FOREIGN KEY (product_id) REFERENCES products (product_id)
);

-- 5. Creación de Índices (Mejora de rendimiento en las búsquedas comunes)
-- ya que son usadas con frecuencia para JOINs.

CREATE INDEX idx_cities_country_id ON cities (country_id);
CREATE INDEX idx_customers_city_id ON customers (city_id);
CREATE INDEX idx_employees_city_id ON employees (city_id);
CREATE INDEX idx_products_category_id ON products (category_id);
CREATE INDEX idx_sales_customer_id ON sales (customer_id);
CREATE INDEX idx_sales_sales_person_id ON sales (sales_person_id);
CREATE INDEX idx_sales_product_id ON sales (product_id);

-- 6. Creación de Índice Compuesto para la Pregunta 4 (JOIN y PARTITION BY)
-- La consulta 4 hace un JOIN entre sales y products, y usa product_id y category_id en la ventana.

CREATE INDEX idx_sales_prod_quantity ON sales (product_id, quantity);
-- Optimiza el SUM(quantity) por product_id.

CREATE INDEX idx_products_cat_id ON products (product_id, category_id);
-- Optimiza el JOIN y la PARTITION BY.