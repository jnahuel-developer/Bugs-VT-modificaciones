/* Reset total MercadoPagoOperacionMixta + índice correcto
   Objetivo del índice:
   - Permitir múltiples filas históricas cerradas (Cerrada=1) para el mismo (OperadorId, ExternalReference)
   - Garantizar 1 sola fila ABIERTA (Cerrada=0) por (OperadorId, ExternalReference)
*/

USE [BugsDev];
GO

SET NOCOUNT ON;

------------------------------------------------------------
-- 1) Drop FKs que apunten a la tabla (si existieran)
------------------------------------------------------------
DECLARE @sql NVARCHAR(MAX) = N'';

SELECT @sql = @sql + N'
ALTER TABLE ' + QUOTENAME(SCHEMA_NAME(fk.schema_id)) + N'.' + QUOTENAME(OBJECT_NAME(fk.parent_object_id)) +
N' DROP CONSTRAINT ' + QUOTENAME(fk.name) + N';'
FROM sys.foreign_keys fk
WHERE fk.referenced_object_id = OBJECT_ID(N'dbo.MercadoPagoOperacionMixta');

IF (@sql <> N'')
BEGIN
    PRINT 'Dropping FKs referencing dbo.MercadoPagoOperacionMixta...';
    EXEC sp_executesql @sql;
END

------------------------------------------------------------
-- 2) Drop tabla si existe
------------------------------------------------------------
IF OBJECT_ID(N'dbo.MercadoPagoOperacionMixta', N'U') IS NOT NULL
BEGIN
    PRINT 'Dropping dbo.MercadoPagoOperacionMixta...';
    DROP TABLE dbo.MercadoPagoOperacionMixta;
END
GO

------------------------------------------------------------
-- 3) Crear tabla desde cero
------------------------------------------------------------
PRINT 'Creating dbo.MercadoPagoOperacionMixta...';

CREATE TABLE dbo.MercadoPagoOperacionMixta
(
    MercadoPagoOperacionMixtaId INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    OperadorId UNIQUEIDENTIFIER NOT NULL,
    ExternalReference NVARCHAR(200) NOT NULL,
    FechaAuthorizedUtc DATETIME NOT NULL,
    MontoAcumulado DECIMAL(18, 2) NOT NULL CONSTRAINT DF_MercadoPagoOperacionMixta_MontoAcumulado DEFAULT (0),
    ApprovedCount INT NOT NULL CONSTRAINT DF_MercadoPagoOperacionMixta_ApprovedCount DEFAULT (0),
    PaymentId1 BIGINT NULL,
    PaymentId2 BIGINT NULL,
    Cerrada BIT NOT NULL CONSTRAINT DF_MercadoPagoOperacionMixta_Cerrada DEFAULT (0),
    FechaCierreUtc DATETIME NULL,
    FechaUltimaActualizacionUtc DATETIME NOT NULL
        CONSTRAINT DF_MercadoPagoOperacionMixta_FechaUltimaActualizacionUtc DEFAULT (GETUTCDATE())
);
GO

------------------------------------------------------------
-- 4) Índice único correcto: SOLO para Cerrada=0 (abiertas)
------------------------------------------------------------
PRINT 'Creating UNIQUE filtered index for open operations (Cerrada=0)...';

CREATE UNIQUE INDEX IX_MercadoPagoOperacionMixta_Operador_External_Cerrada
    ON dbo.MercadoPagoOperacionMixta (OperadorId, ExternalReference)
    WHERE Cerrada = 0;
GO

------------------------------------------------------------
-- 5) (Opcional pero recomendado) Índice no-único para búsquedas generales
------------------------------------------------------------
PRINT 'Creating non-unique helper index for lookups...';

CREATE INDEX IX_MercadoPagoOperacionMixta_Operador_External
    ON dbo.MercadoPagoOperacionMixta (OperadorId, ExternalReference);
GO