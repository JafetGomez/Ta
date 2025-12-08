-- Borrar Todas las Tablas de la Base de Datos Facturacion
USE [Facturacion];
GO

SET NOCOUNT ON;

PRINT '--- INICIO DEL PROCESO DE ELIMINACIÓN DE OBJETOS ---';

-- =================================================================
-- PASO 1: ELIMINAR TODAS LAS RESTRICCIONES DE CLAVE FORÁNEA (FOREIGN KEYS)
-- Esto previene errores de dependencia al intentar borrar las tablas.
-- =================================================================
DECLARE @sql NVARCHAR(MAX) = N'';

SELECT @sql += N'ALTER TABLE ' 
    + QUOTENAME(OBJECT_SCHEMA_NAME(parent_object_id)) 
    + '.' 
    + QUOTENAME(OBJECT_NAME(parent_object_id)) 
    + ' DROP CONSTRAINT ' 
    + QUOTENAME(name) + ';' + CHAR(13) + CHAR(10)
FROM sys.foreign_keys
WHERE parent_object_id IN (
    SELECT object_id 
    FROM sys.tables 
    WHERE type = 'U' -- Tablas de usuario
);

-- Ejecutar el comando dinámico para eliminar todas las Foreign Keys
EXEC sp_executesql @sql;

PRINT 'Se han eliminado todas las Claves Foráneas (Foreign Keys).';


-- =================================================================
-- PASO 2: ELIMINAR TODAS LAS TABLAS DE USUARIO
-- =================================================================
SET @sql = N'';

SELECT @sql += N'DROP TABLE ' 
    + QUOTENAME(SCHEMA_NAME(schema_id)) 
    + '.' 
    + QUOTENAME(name) + ';' + CHAR(13) + CHAR(10)
FROM sys.tables
WHERE type = 'U'; -- Solo tablas de usuario

-- Ejecutar el comando dinámico para eliminar todas las tablas
EXEC sp_executesql @sql;

PRINT 'Se han eliminado todas las tablas de usuario de la base de datos Facturacion.';

-- =================================================================
-- PASO 3: ELIMINAR PROCEDIMIENTOS ALMACENADOS (Opcional, pero recomendado)
-- Incluyendo el que creamos previamente: ProcesarOperacionXML
-- =================================================================
IF OBJECT_ID('dbo.ProcesarOperacionXML', 'P') IS NOT NULL
    DROP PROCEDURE dbo.ProcesarOperacionXML;
    
PRINT 'Se han eliminado los procedimientos almacenados relevantes.';

PRINT '--- PROCESO COMPLETADO ---';
GO