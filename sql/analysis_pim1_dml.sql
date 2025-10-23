-- ***************************************************************
-- PREGUNTA 1: Los 5 productos más vendidos y su vendedor líder
-- ***************************************************************

WITH Top5Products AS (
    -- 1. Identificar los 5 productos más vendidos por cantidad total
    SELECT 
        s.product_id,
        SUM(s.quantity) AS total_quantity_sold
    FROM sales s
    GROUP BY 1
    ORDER BY total_quantity_sold DESC
    LIMIT 5
),
SellerSales AS (
    -- 2. Ventas de cada vendedor para esos Top 5 productos
    SELECT 
        t5p.product_id,
        s.sales_person_id,
        SUM(s.quantity) AS units_sold_by_seller,
        t5p.total_quantity_sold
    FROM sales s
    JOIN Top5Products t5p ON s.product_id = t5p.product_id
    GROUP BY 1, 2, 4
),
RankedSellers AS (
    -- 3. Clasificar a los vendedores para encontrar al líder de cada producto
    SELECT
        product_id,
        sales_person_id,
        units_sold_by_seller,
        total_quantity_sold,
        -- Usamos RANK para manejar posibles empates de vendedores líderes
        RANK() OVER (PARTITION BY product_id ORDER BY units_sold_by_seller DESC) AS seller_rank
    FROM SellerSales
)
SELECT 
    p.product_id,
    p.product_name,
    rs.total_quantity_sold,
    e.first_name || ' ' || e.last_name AS leading_seller_name,
    rs.units_sold_by_seller AS leading_seller_units,
    -- Calcular el porcentaje del vendedor líder sobre el total del producto
    ROUND((rs.units_sold_by_seller * 100.0) / rs.total_quantity_sold, 2) AS seller_contribution_pct
FROM RankedSellers rs
JOIN products p ON rs.product_id = p.product_id
JOIN employees e ON rs.sales_person_id = e.employee_id
WHERE rs.seller_rank = 1
ORDER BY rs.total_quantity_sold DESC;


-- ***************************************************************
-- PREGUNTA 2: Penetración General y Ciudad Líder (6 Campos Solicitados)
-- ***************************************************************

WITH Top5Products AS (
    -- 1. Identificar los 5 productos más vendidos por cantidad total (base del análisis)
    SELECT 
        product_id,
        SUM(quantity) AS product_units_sold
    FROM sales
    GROUP BY 1
    ORDER BY product_units_sold DESC
    LIMIT 5
),
TotalCustomers AS (
    -- Conteo total de clientes en la base de datos
    SELECT COUNT(customer_id) AS total_customer_count
    FROM customers
),
ProductCitySales AS (
    -- 2. Ventas totales por producto y por ciudad (para identificar la ciudad líder)
    SELECT
        t5p.product_id,
        cust.city_id,
        SUM(s.quantity) AS units_sold_in_city
    FROM sales s
    JOIN Top5Products t5p ON s.product_id = t5p.product_id
    JOIN customers cust ON s.customer_id = cust.customer_id
    GROUP BY 1, 2
),
CityRank AS (
    -- 3. Identificar la ciudad con el mayor volumen de ventas (RANK = 1) para cada producto
    SELECT
        pcs.product_id,
        ci.city_name,
        pcs.units_sold_in_city,
        -- La contribución de la ciudad líder sobre el total del producto
        pcs.units_sold_in_city * 100.0 / SUM(pcs.units_sold_in_city) OVER (PARTITION BY pcs.product_id) AS city_contribution_pct,
        RANK() OVER (PARTITION BY pcs.product_id ORDER BY pcs.units_sold_in_city DESC) AS city_rank
    FROM ProductCitySales pcs
    JOIN cities ci ON pcs.city_id = ci.city_id
),
ProductPenetration AS (
    -- 4. Clientes únicos y penetración general del producto
    SELECT
        t5p.product_id,
        COUNT(DISTINCT s.customer_id) AS unique_customers_count,
        tc.total_customer_count,
        -- Penetración sobre el total de clientes
        COUNT(DISTINCT s.customer_id) * 100.0 / tc.total_customer_count AS penetration_pct
    FROM sales s
    JOIN Top5Products t5p ON s.product_id = t5p.product_id
    CROSS JOIN TotalCustomers tc
    GROUP BY 1, 3
)
SELECT
    pp.product_id,
    p.product_name,
    cr.city_name AS leading_sales_city,
    ROUND(cr.city_contribution_pct, 2) AS city_contribution_pct,
    pp.unique_customers_count,
    ROUND(pp.penetration_pct, 2) AS penetration_pct
FROM ProductPenetration pp
JOIN CityRank cr ON pp.product_id = cr.product_id
JOIN products p ON pp.product_id = p.product_id
WHERE cr.city_rank = 1
ORDER BY pp.penetration_pct DESC;


-- ***************************************************************
-- PREGUNTA 3: Categoría, Proporción y Relevancia Categórica
-- ***************************************************************

WITH AllCategorySales AS (
    -- 1. CTE para calcular el total de ventas (unidades) por Categoria para TODO el catálogo
    SELECT
        p.category_id,
        SUM(s.quantity) AS category_total_units_sold
    FROM sales s
    JOIN products p ON s.product_id = p.product_id
    GROUP BY 1
),
Top5Products AS (
    -- 2. Identificar los 5 productos más vendidos por cantidad total (unidades)
    SELECT 
        product_id,
        SUM(quantity) AS product_units_sold
    FROM sales
    GROUP BY 1
    ORDER BY product_units_sold DESC
    LIMIT 5
)
SELECT
    t5p.product_id,
    p.product_name,
    cat.category_name,
    t5p.product_units_sold,
    acs.category_total_units_sold,
    -- Proporción del producto sobre el total de su categoría (CÁLCULO CORRECTO)
    ROUND((t5p.product_units_sold * 100.0) / acs.category_total_units_sold, 2) AS proportion_in_category_pct
FROM Top5Products t5p
JOIN products p ON t5p.product_id = p.product_id
JOIN categories cat ON p.category_id = cat.category_id
JOIN AllCategorySales acs ON p.category_id = acs.category_id
ORDER BY t5p.product_units_sold DESC;


-- ***************************************************************
-- PREGUNTA 4: Top 10 Productos y su Ranking por Cantidad Vendida dentro de su Categoría
-- ***************************************************************

WITH ProductSales AS (
    -- 1. Calcular las ventas totales (unidades) de cada producto en el catálogo
    SELECT 
        product_id,
        SUM(quantity) AS total_units_sold
    FROM sales
    GROUP BY 1
),
CategoryRanking AS (
    -- 2. Asignar un rango a cada producto dentro de su categoría basado en las unidades vendidas
    SELECT
        ps.product_id,
        ps.total_units_sold,
        p.category_id,
        cat.category_name,
        -- FUNCIÓN DE VENTANA: Asigna un rango por ventas DENTRO de cada categoría
        RANK() OVER (
            PARTITION BY p.category_id
            ORDER BY ps.total_units_sold DESC
        ) AS category_rank
    FROM ProductSales ps
    JOIN products p ON ps.product_id = p.product_id
    JOIN categories cat ON p.category_id = cat.category_id
)
SELECT
    cr.product_id,
    p.product_name,
    cr.category_name,
    cr.total_units_sold,
    -- Ranking general del Top 10
    ROW_NUMBER() OVER (ORDER BY cr.total_units_sold DESC) AS over_all_rank, 
    cr.category_rank
FROM CategoryRanking cr
JOIN products p ON cr.product_id = p.product_id
ORDER BY over_all_rank
LIMIT 10;


-- ***************************************************************
-- PASO 5: Recalcular Volumen Categórico basado en Reclasificación
-- ***************************************************************

WITH ReclassifiedProducts AS (
    -- 1. CTE para reasignar las categorías de los 10 productos más vendidos
    SELECT
        p.product_id,
        CASE
            -- Yoghurt Tubes (179) reclasificado a Dairy (4)
            WHEN p.product_id = 179 THEN 4
            -- Longos - Chicken Wings (161) reclasificado a Poultry (9)
            WHEN p.product_id = 161 THEN 9
            -- Apricots - Dried (324) reclasificado a Produce (11)
            WHEN p.product_id = 324 THEN 11
            -- Cream Of Tartar (103) reclasificado a Confections (1)
            WHEN p.product_id = 103 THEN 1
            -- Towels - Paper / Kraft (319) reclasificado a una categoría general (usaremos 12, asumiendo que es "Suministros/Otros" y no existe aún)
            WHEN p.product_id = 319 THEN 12 -- ASUMIMOS ID 12 NO EXISTE O REPRESENTA OTRA COSA
            ELSE p.category_id -- Mantener la categoría original para el resto
        END AS corrected_category_id
    FROM products p
),
AllSalesReclassified AS (
    -- 2. CTE que combina todas las ventas con las categorías ACTUALES o RECLASIFICADAS
    SELECT
        s.product_id,
        s.quantity,
        -- Se obtiene el category_id corregido para los Top 10, o el original para el resto
        COALESCE(rp.corrected_category_id, p.category_id) AS final_category_id
    FROM sales s
    JOIN products p ON s.product_id = p.product_id
    LEFT JOIN ReclassifiedProducts rp ON s.product_id = rp.product_id -- LEFT JOIN solo reclasifica el Top 10
),
RecalculatedCategoryVolume AS (
    -- 3. Calcular el volumen total de unidades vendidas por la categoría CORREGIDA
    SELECT
        final_category_id,
        SUM(quantity) AS recalculated_total_units_sold
    FROM AllSalesReclassified
    GROUP BY 1
)
-- 4. Resultados: Comparar el volumen original de las categorías *afectadas* con el volumen recalculado
SELECT
    -- Se utilizan los IDs 4 (Dairy), 9 (Poultry), 11 (Produce), 1 (Confections) y 7 (Meat/Towel)
    acs.final_category_id,
    c.category_name,
    rcv.recalculated_total_units_sold,
    -- Obtenemos el volumen original de esas mismas categorías (para la comparación)
    (SELECT SUM(s.quantity) FROM sales s JOIN products p ON s.product_id = p.product_id WHERE p.category_id = acs.final_category_id) AS original_total_units_sold,
    
    -- Calculamos el cambio porcentual
    ROUND(
        (rcv.recalculated_total_units_sold - (SELECT SUM(s.quantity) FROM sales s JOIN products p ON s.product_id = p.product_id WHERE p.category_id = acs.final_category_id)) * 100.0 / 
        (SELECT SUM(s.quantity) FROM sales s JOIN products p ON s.product_id = p.product_id WHERE p.category_id = acs.final_category_id), 
    2) AS percent_change
FROM AllSalesReclassified acs
JOIN RecalculatedCategoryVolume rcv ON acs.final_category_id = rcv.final_category_id
LEFT JOIN categories c ON acs.final_category_id = c.category_id
GROUP BY 1, 2, 3
ORDER BY percent_change DESC
LIMIT 15;