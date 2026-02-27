USE BugsDev;
GO

SET NOCOUNT ON;
GO

/* =========================================================================================
   Mercado Pago - Operaciones mixtas (pendientes)
   - Si la tabla existe: se elimina y se crea de nuevo.
   - Se crea índice único filtrado para permitir UNA sola operación abierta (Cerrada=0)
     por (OperadorId, ExternalReference).
   ========================================================================================= */

IF OBJECT_ID('dbo.MercadoPagoOperacionMixta', 'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.MercadoPagoOperacionMixta;
END;
GO

CREATE TABLE dbo.MercadoPagoOperacionMixta
(
    MercadoPagoOperacionMixtaId INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_MercadoPagoOperacionMixta PRIMARY KEY,

    OperadorId UNIQUEIDENTIFIER NOT NULL,
    ExternalReference NVARCHAR(200) NOT NULL,

    FechaAuthorized DATETIME NOT NULL
        CONSTRAINT DF_MercadoPagoOperacionMixta_FechaAuthorized
        DEFAULT (DATEADD(HOUR, -3, GETUTCDATE())),

    MontoAcumulado DECIMAL(18, 2) NOT NULL
        CONSTRAINT DF_MercadoPagoOperacionMixta_MontoAcumulado DEFAULT (0),

    ApprovedCount INT NOT NULL
        CONSTRAINT DF_MercadoPagoOperacionMixta_ApprovedCount DEFAULT (0),

    PaymentId1 BIGINT NULL,
    PaymentId2 BIGINT NULL,

    Cerrada BIT NOT NULL
        CONSTRAINT DF_MercadoPagoOperacionMixta_Cerrada DEFAULT (0),

    FechaCierre DATETIME NULL,

    FechaUltimaActualizacion DATETIME NOT NULL
        CONSTRAINT DF_MercadoPagoOperacionMixta_FechaUltimaActualizacion
        DEFAULT (DATEADD(HOUR, -3, GETUTCDATE()))
);
GO

-- 1) Único filtrado: SOLO una pendiente abierta por Operador + ExternalReference.
CREATE UNIQUE INDEX IX_MercadoPagoOperacionMixta_Operador_External_Cerrada
    ON dbo.MercadoPagoOperacionMixta (OperadorId, ExternalReference)
    WHERE Cerrada = 0;
GO

-- 2) Índice de soporte (no único) para búsquedas generales / reportes.
CREATE INDEX IX_MercadoPagoOperacionMixta_Operador_External_Cerrada_All
    ON dbo.MercadoPagoOperacionMixta (OperadorId, ExternalReference, Cerrada);
GO