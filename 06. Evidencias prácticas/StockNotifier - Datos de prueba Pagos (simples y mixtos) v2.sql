USE BugsDev;
GO
/*
===============================================================================
BugsVT - Datos de prueba para StockNotifier (Pagos simples y pagos mixtos)
===============================================================================

Objetivo
--------
Cargar un conjunto compacto pero completo de casos de prueba para la rutina de
devoluciones del StockNotifier.

Este script:
- Inserta pagos "simples" en MercadoPagoTable.
- Inserta operaciones "mixtas" en MercadoPagoOperacionMixta y el registro único
  correspondiente en MercadoPagoTable (con Comprobante = uno de los PaymentId).

Notas importantes
-----------------
1) El StockNotifier interpreta MercadoPagoTable.Comprobante como PaymentId de MP
   (se convierte a BIGINT/LONG). Por eso, aquí los Comprobantes son numéricos.
2) Los PaymentId de este script son ficticios. Para pruebas end-to-end con la API
   de MercadoPago, reemplácelos por PaymentId reales de un entorno de pruebas.
3) Casuística cubierta (esperado por filtro de candidatos del StockNotifier):
   - ACREDITADO + TERMINADO_MAL      => candidato (refund/rechazo)
   - ACREDITADO + ERROR_CONEXION     => candidato
   - ACREDITADO + EN_PROCESO (viejo) => candidato (si > 5 min)
   - ACREDITADO + EN_PROCESO (nuevo) => NO candidato
   - ACREDITADO + TERMINADO_OK       => NO candidato
   - DEVUELTO/OTROS financieros      => NO candidato
   - Mixto: cuando el Comprobante pertenece a una operación mixta, el job debe
           devolver BOTH PaymentId1 y PaymentId2.

Precondición
------------
Ejecutar previamente:
- 30. 1 - Datos base de pruebas.sql
- 31. 2 - Infraestructura VT.sql
- 34. 5 - Tablas de Mercado Pago.sql  (al menos para estados lookup)

Idempotencia
------------
El script es idempotente por "clave" de pruebas:
- MercadoPagoTable.Comprobante (numérico, prefijo 91/92/93...)
- MercadoPagoOperacionMixta.ExternalReference (prefijo SNTEST-...)

===============================================================================
*/

SET NOCOUNT ON;

-------------------------------------------------------------
-- 0) IDs base (coherentes con scripts de prueba)
-------------------------------------------------------------
DECLARE @OperadorDarioId   UNIQUEIDENTIFIER = '11111111-1111-1111-1111-111111111111';
DECLARE @OperadorErnestoId UNIQUEIDENTIFIER = '22222222-2222-2222-2222-222222222222';

DECLARE @MaquinaDevId   UNIQUEIDENTIFIER = '88888888-8888-8888-8888-888888888888';
DECLARE @MaquinaQaId    UNIQUEIDENTIFIER = '99999999-9999-9999-9999-999999999999';
DECLARE @MaquinaProdId  UNIQUEIDENTIFIER = '77777777-7777-7777-7777-777777777777';

IF NOT EXISTS (SELECT 1 FROM Operador WHERE OperadorID = @OperadorDarioId)
BEGIN
    RAISERROR('No existe Operador 1111... Ejecute "30. 1 - Datos base de pruebas.sql".', 16, 1);
    RETURN;
END

IF NOT EXISTS (SELECT 1 FROM Operador WHERE OperadorID = @OperadorErnestoId)
BEGIN
    RAISERROR('No existe Operador 2222... Ejecute "30. 1 - Datos base de pruebas.sql".', 16, 1);
    RETURN;
END

IF NOT EXISTS (SELECT 1 FROM Maquina WHERE MaquinaID = @MaquinaDevId)
BEGIN
    RAISERROR('No existe Maquina 8888... Ejecute "31. 2 - Infraestructura VT.sql".', 16, 1);
    RETURN;

IF OBJECT_ID('dbo.MercadoPagoOperacionMixta', 'U') IS NULL
BEGIN
    RAISERROR('No existe la tabla MercadoPagoOperacionMixta. Ejecute el script de creación de pagos mixtos (por ejemplo "37. Crear tabla para pagos mixtos.sql").', 16, 1);
    RETURN;
END

END

-------------------------------------------------------------
-- 1) LOOKUPS de estados (idempotente)
-------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM MercadoPagoEstadoFinanciero WHERE Id = 1)
    INSERT INTO MercadoPagoEstadoFinanciero (Id, Descripcion) VALUES (1, N'DEVUELTO');
IF NOT EXISTS (SELECT 1 FROM MercadoPagoEstadoFinanciero WHERE Id = 2)
    INSERT INTO MercadoPagoEstadoFinanciero (Id, Descripcion) VALUES (2, N'ACREDITADO');
IF NOT EXISTS (SELECT 1 FROM MercadoPagoEstadoFinanciero WHERE Id = 3)
    INSERT INTO MercadoPagoEstadoFinanciero (Id, Descripcion) VALUES (3, N'AVISO_FALLIDO');
IF NOT EXISTS (SELECT 1 FROM MercadoPagoEstadoFinanciero WHERE Id = 4)
    INSERT INTO MercadoPagoEstadoFinanciero (Id, Descripcion) VALUES (4, N'NO_PROCESABLE');

IF NOT EXISTS (SELECT 1 FROM MercadoPagoEstadoTransmision WHERE Id = 1)
    INSERT INTO MercadoPagoEstadoTransmision (Id, Descripcion) VALUES (1, N'EN_PROCESO');
IF NOT EXISTS (SELECT 1 FROM MercadoPagoEstadoTransmision WHERE Id = 2)
    INSERT INTO MercadoPagoEstadoTransmision (Id, Descripcion) VALUES (2, N'TERMINADO_OK');
IF NOT EXISTS (SELECT 1 FROM MercadoPagoEstadoTransmision WHERE Id = 3)
    INSERT INTO MercadoPagoEstadoTransmision (Id, Descripcion) VALUES (3, N'TERMINADO_MAL');
IF NOT EXISTS (SELECT 1 FROM MercadoPagoEstadoTransmision WHERE Id = 4)
    INSERT INTO MercadoPagoEstadoTransmision (Id, Descripcion) VALUES (4, N'ERROR_CONEXION');
IF NOT EXISTS (SELECT 1 FROM MercadoPagoEstadoTransmision WHERE Id = 5)
    INSERT INTO MercadoPagoEstadoTransmision (Id, Descripcion) VALUES (5, N'NO_PROCESABLE');

-------------------------------------------------------------
-- 2) Parámetros de tiempo
-------------------------------------------------------------
DECLARE @NowLocal DATETIME = GETDATE();
DECLARE @NowUtc   DATETIME = GETUTCDATE();

-- Para simular EN_PROCESO viejo / nuevo respecto al umbral (5 min)
DECLARE @FechaVieja DATETIME = DATEADD(MINUTE, -10, @NowLocal);
DECLARE @FechaNueva DATETIME = DATEADD(MINUTE, -2,  @NowLocal);

-------------------------------------------------------------
-- 3) Pagos SIMPLES (MercadoPagoTable)
-------------------------------------------------------------
/*
Convención de IDs (Comprobante):
- 91xxxxxxxxxx => simple (Operador Dario / Maquina Dev)
- 92xxxxxxxxxx => simple (Operador Ernesto / sin Maquina)
*/

DECLARE @PagosSimples TABLE
(
    Comprobante NVARCHAR(50) NOT NULL,
    Fecha DATETIME NOT NULL,
    Monto DECIMAL(18,2) NOT NULL,
    OperadorId UNIQUEIDENTIFIER NULL,
    MaquinaId UNIQUEIDENTIFIER NULL,
    EstadoFinId INT NOT NULL,
    EstadoTransId INT NOT NULL,
    Descripcion NVARCHAR(200) NULL,
    Entidad NVARCHAR(10) NULL,
    Reintentos INT NOT NULL
);

-- S1: CANDIDATO -> ACREDITADO + TERMINADO_MAL
INSERT INTO @PagosSimples VALUES
(N'910000000001', @NowLocal, 100.00, @OperadorDarioId, @MaquinaDevId, 2, 3, N'SNTEST-SIMPLE-S1-ACR-TMAL', N'MP', 0);

-- S2: CANDIDATO -> ACREDITADO + ERROR_CONEXION
INSERT INTO @PagosSimples VALUES
(N'910000000002', @NowLocal, 120.00, @OperadorDarioId, @MaquinaDevId, 2, 4, N'SNTEST-SIMPLE-S2-ACR-ECON', N'MP', 0);

-- S3: CANDIDATO -> ACREDITADO + EN_PROCESO (viejo > 5 min)
INSERT INTO @PagosSimples VALUES
(N'910000000003', @FechaVieja, 130.00, @OperadorDarioId, @MaquinaDevId, 2, 1, N'SNTEST-SIMPLE-S3-ACR-EPRO-OLD', N'MP', 0);

-- S4: NO candidato -> ACREDITADO + EN_PROCESO (nuevo <= 5 min)
INSERT INTO @PagosSimples VALUES
(N'910000000004', @FechaNueva, 140.00, @OperadorDarioId, @MaquinaDevId, 2, 1, N'SNTEST-SIMPLE-S4-ACR-EPRO-NEW', N'MP', 0);

-- S5: NO candidato -> ACREDITADO + TERMINADO_OK
INSERT INTO @PagosSimples VALUES
(N'910000000005', @NowLocal, 150.00, @OperadorDarioId, @MaquinaDevId, 2, 2, N'SNTEST-SIMPLE-S5-ACR-TOK', N'MP', 0);

-- S6: NO candidato -> DEVUELTO + TERMINADO_MAL (ya devuelto)
INSERT INTO @PagosSimples VALUES
(N'910000000006', @NowLocal, 160.00, @OperadorDarioId, @MaquinaDevId, 1, 3, N'SNTEST-SIMPLE-S6-DEV-TMAL', N'MP', 0);

-- S7: CANDIDATO (otro operador) -> ACREDITADO + TERMINADO_MAL (Operador Ernesto, Maquina NULL)
INSERT INTO @PagosSimples VALUES
(N'920000000001', @NowLocal, 200.00, @OperadorErnestoId, NULL, 2, 3, N'SNTEST-SIMPLE-S7-ERN-ACR-TMAL', N'MP', 0);

INSERT INTO MercadoPagoTable
(
    Fecha, Monto, MaquinaId, MercadoPagoEstadoFinancieroId, MercadoPagoEstadoTransmisionId,
    OperadorId, Comprobante, Descripcion, FechaModificacionEstadoTransmision,
    Entidad, UrlDevolucion, Reintentos
)
SELECT
    p.Fecha,
    p.Monto,
    p.MaquinaId,
    p.EstadoFinId,
    p.EstadoTransId,
    p.OperadorId,
    p.Comprobante,
    p.Descripcion,
    -- fecha de modificación: para este set, se utiliza la misma "Fecha" como proxy de antigüedad
    p.Fecha,
    p.Entidad,
    NULL,
    p.Reintentos
FROM @PagosSimples p
WHERE NOT EXISTS (SELECT 1 FROM MercadoPagoTable mp WHERE mp.Comprobante = p.Comprobante);

-------------------------------------------------------------
-- 4) Pagos MIXTOS (MercadoPagoOperacionMixta + MercadoPagoTable)
-------------------------------------------------------------
/*
Convención de IDs (PaymentId):
- 9300000000xx => mix "M1.."
- 9400000000xx => mix "M2.."
- 9500000000xx => mix "M3.."

Estrategia:
- Insertar operación mixta con PaymentId1/PaymentId2.
- Insertar UN único registro en MercadoPagoTable (como hace el flujo real),
  donde Comprobante = (PaymentId1 o PaymentId2).
- El StockNotifier debe detectar la operación mixta por Comprobante y devolver
  ambos PaymentId.
*/

DECLARE @Mixtas TABLE
(
    ExternalReference NVARCHAR(200) NOT NULL,
    OperadorId UNIQUEIDENTIFIER NOT NULL,
    PaymentId1 BIGINT NULL,
    PaymentId2 BIGINT NULL,
    Monto1 DECIMAL(18,2) NOT NULL,
    Monto2 DECIMAL(18,2) NOT NULL,
    ComprobanteEnTabla BIGINT NOT NULL,
    FechaPago DATETIME NOT NULL,
    EstadoFinId INT NOT NULL,
    EstadoTransId INT NOT NULL,
    Descripcion NVARCHAR(200) NOT NULL,
    MaquinaId UNIQUEIDENTIFIER NULL,
    Cerrada BIT NOT NULL,
    ApprovedCount INT NOT NULL
);

-- M1: CANDIDATO -> mixto completo (dos IDs) - Comprobante = PaymentId2 - TERMINADO_MAL
INSERT INTO @Mixtas VALUES
(N'SNTEST-MIX-M1', @OperadorDarioId, 930000000001, 930000000002, 50.00, 60.00, 930000000002, @NowLocal, 2, 3,
 N'SNTEST-MIX-M1-ACR-TMAL', @MaquinaDevId, 1, 2);

-- M2: CANDIDATO -> mixto completo (dos IDs) - Comprobante = PaymentId1 - ERROR_CONEXION
INSERT INTO @Mixtas VALUES
(N'SNTEST-MIX-M2', @OperadorDarioId, 940000000001, 940000000002, 70.00, 80.00, 940000000001, @NowLocal, 2, 4,
 N'SNTEST-MIX-M2-ACR-ECON', @MaquinaQaId, 1, 2);

-- M3: CANDIDATO -> mixto "degenerado" (PaymentId2 NULL) - TERMINADO_MAL
INSERT INTO @Mixtas VALUES
(N'SNTEST-MIX-M3', @OperadorDarioId, 950000000001, NULL,         90.00,  0.00, 950000000001, @NowLocal, 2, 3,
 N'SNTEST-MIX-M3-ACR-TMAL-P2NULL', @MaquinaProdId, 1, 1);

-- M4: CANDIDATO -> mixto completo - EN_PROCESO viejo (> 5 min)
INSERT INTO @Mixtas VALUES
(N'SNTEST-MIX-M4', @OperadorDarioId, 930000000003, 930000000004, 15.00, 25.00, 930000000003, @FechaVieja, 2, 1,
 N'SNTEST-MIX-M4-ACR-EPRO-OLD', @MaquinaDevId, 1, 2);

-- M5: NO candidato -> mixto completo - TERMINADO_OK (no debería devolverse)
INSERT INTO @Mixtas VALUES
(N'SNTEST-MIX-M5', @OperadorDarioId, 930000000005, 930000000006, 10.00, 20.00, 930000000006, @NowLocal, 2, 2,
 N'SNTEST-MIX-M5-ACR-TOK', @MaquinaDevId, 1, 2);


-- M6: CANDIDATO -> mixto completo (dos IDs) - Operador Ernesto (AccessToken puede ser NULL) - TERMINADO_MAL
INSERT INTO @Mixtas VALUES
(N'SNTEST-MIX-M6-ERN', @OperadorErnestoId, 960000000001, 960000000002, 33.00, 44.00, 960000000002, @NowLocal, 2, 3,
 N'SNTEST-MIX-M6-ERN-ACR-TMAL', NULL, 1, 2);

-- M7: CANDIDATO -> mixto completo pero operación marcada como "abierta" (Cerrada=0) - TERMINADO_MAL
--      (Sirve para validar que el StockNotifier NO depende de Cerrada para resolver PaymentId1/2)
INSERT INTO @Mixtas VALUES
(N'SNTEST-MIX-M7-OPEN', @OperadorDarioId, 970000000001, 970000000002, 12.00, 13.00, 970000000001, @NowLocal, 2, 3,
 N'SNTEST-MIX-M7-OPEN-ACR-TMAL', @MaquinaDevId, 0, 2);

-- Insert idempotente de operaciones mixtas
INSERT INTO MercadoPagoOperacionMixta
(
    OperadorId, ExternalReference, FechaAuthorizedUtc,
    MontoAcumulado, ApprovedCount,
    PaymentId1, PaymentId2,
    Cerrada, FechaCierreUtc, FechaUltimaActualizacionUtc
)
SELECT
    m.OperadorId,
    m.ExternalReference,
    @NowUtc, -- fecha autorizada (UTC)
    (m.Monto1 + m.Monto2),
    m.ApprovedCount,
    m.PaymentId1,
    m.PaymentId2,
    m.Cerrada,
    CASE WHEN m.Cerrada = 1 THEN @NowUtc ELSE NULL END,
    @NowUtc
FROM @Mixtas m
WHERE NOT EXISTS
(
    SELECT 1
    FROM MercadoPagoOperacionMixta x
    WHERE x.OperadorId = m.OperadorId
      AND x.ExternalReference = m.ExternalReference
);

-- Insert del registro UNICO en MercadoPagoTable para cada operación mixta (idempotente por Comprobante)
INSERT INTO MercadoPagoTable
(
    Fecha, Monto, MaquinaId, MercadoPagoEstadoFinancieroId, MercadoPagoEstadoTransmisionId,
    OperadorId, Comprobante, Descripcion, FechaModificacionEstadoTransmision,
    Entidad, UrlDevolucion, Reintentos
)
SELECT
    m.FechaPago,
    (m.Monto1 + m.Monto2),
    m.MaquinaId,
    m.EstadoFinId,
    m.EstadoTransId,
    m.OperadorId,
    CONVERT(NVARCHAR(50), m.ComprobanteEnTabla),
    m.Descripcion,
    m.FechaPago,          -- proxy de antigüedad para EN_PROCESO viejo/nuevo
    N'MP',
    NULL,
    0
FROM @Mixtas m
WHERE NOT EXISTS
(
    SELECT 1
    FROM MercadoPagoTable mp
    WHERE mp.Comprobante = CONVERT(NVARCHAR(50), m.ComprobanteEnTabla)
);

-------------------------------------------------------------
-- 5) Resumen de lo insertado (útil para la prueba)
-------------------------------------------------------------
PRINT '=== StockNotifier: Pagos de prueba insertados/verificados ===';

SELECT
    'SIMPLE' AS Tipo,
    mp.MercadoPagoId,
    mp.Comprobante,
    mp.Fecha,
    mp.Monto,
    mp.OperadorId,
    mp.MaquinaId,
    mp.MercadoPagoEstadoFinancieroId AS EstadoFin,
    mp.MercadoPagoEstadoTransmisionId AS EstadoTrans,
    mp.Descripcion
FROM MercadoPagoTable mp
WHERE mp.Descripcion LIKE 'SNTEST-SIMPLE-%'
UNION ALL
SELECT
    'MIXTO' AS Tipo,
    mp.MercadoPagoId,
    mp.Comprobante,
    mp.Fecha,
    mp.Monto,
    mp.OperadorId,
    mp.MaquinaId,
    mp.MercadoPagoEstadoFinancieroId AS EstadoFin,
    mp.MercadoPagoEstadoTransmisionId AS EstadoTrans,
    mp.Descripcion
FROM MercadoPagoTable mp
WHERE mp.Descripcion LIKE 'SNTEST-MIX-%'
ORDER BY Tipo, Comprobante;

SELECT
    OperadorId,
    ExternalReference,
    PaymentId1,
    PaymentId2,
    ApprovedCount,
    Cerrada,
    FechaAuthorizedUtc,
    FechaCierreUtc
FROM MercadoPagoOperacionMixta
WHERE ExternalReference LIKE 'SNTEST-MIX-%'
ORDER BY ExternalReference;

PRINT '=== Fin ===';
GO
