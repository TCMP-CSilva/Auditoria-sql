-- ejemplo.sql

-- Caso 1: Falta NOLOCK en tabla física (error)
SELECT *
FROM dbo.Clientes WITH (NOLOCK);

-- Caso 2: Tiene hint WITH (NOLOCK) en mayúsculas (correcto)
SELECT *
FROM dbo.Empleados WITH (NOLOCK);

-- Caso 3: Variación sin espacio: WITH(NOLOCK) (correcto)
SELECT *
FROM dbo.Proveedores WITH(NOLOCK);

-- Caso 4: Hint combinado: WITH (NOLOCK, READUNCOMMITTED) (correcto)
SELECT *
FROM dbo.Productos WITH (NOLOCK, READUNCOMMITTED);

-- Caso 5: JOIN sin NOLOCK en segundas tablas (error)
SELECT a.Id, b.Total
FROM dbo.Ordenes a WITH (NOLOCK)
    JOIN dbo.DetalleVentas b WITH (NOLOCK) ON a.Id = b.VentaID;

-- Caso 6: JOIN con hint en primer tabla pero no en segunda (error)
SELECT a.Id, b.Cantidad
FROM dbo.Ventas a WITH (NOLOCK)
    JOIN dbo.DetalleVentas b WITH (NOLOCK) ON a.Id = b.VentaID;

-- Caso 7: JOIN con hint en ambas tablas (correcto)
SELECT a.Id, b.Cantidad
FROM dbo.Ventas a WITH (NOLOCK)
    JOIN dbo.DetalleVentas b WITH(NOLOCK) ON a.Id = b.VentaID;

-- Fin del archivo
