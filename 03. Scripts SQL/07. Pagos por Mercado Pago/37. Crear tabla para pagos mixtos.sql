USE BugsDev;
GO

-- Mercado Pago - Operaciones mixtas (pendientes)

IF OBJECT_ID('dbo.MercadoPagoOperacionMixta', 'U') IS NULL
BEGIN
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
        FechaUltimaActualizacionUtc DATETIME NOT NULL CONSTRAINT DF_MercadoPagoOperacionMixta_FechaUltimaActualizacionUtc DEFAULT (GETUTCDATE())
    );
END;

-- 1) El índice viejo (UNIQUE por Cerrada) rompe el historial (Cerrada=1).
--    Se elimina si existe.
IF EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_MercadoPagoOperacionMixta_Operador_External_Cerrada'
      AND object_id = OBJECT_ID('dbo.MercadoPagoOperacionMixta')
)
BEGIN
    DROP INDEX IX_MercadoPagoOperacionMixta_Operador_External_Cerrada
        ON dbo.MercadoPagoOperacionMixta;
END;

-- 2) Índice único filtrado: sólo permite UNA pendiente (Cerrada=0) por Operador + ExternalReference.
CREATE UNIQUE INDEX IX_MercadoPagoOperacionMixta_Operador_External_Cerrada
    ON dbo.MercadoPagoOperacionMixta (OperadorId, ExternalReference)
    WHERE Cerrada = 0;

-- 3) Índice de soporte no único (para búsquedas generales)
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_MercadoPagoOperacionMixta_Operador_External_Cerrada_All'
      AND object_id = OBJECT_ID('dbo.MercadoPagoOperacionMixta')
)
BEGIN
    CREATE INDEX IX_MercadoPagoOperacionMixta_Operador_External_Cerrada_All
        ON dbo.MercadoPagoOperacionMixta (OperadorId, ExternalReference, Cerrada);
END;