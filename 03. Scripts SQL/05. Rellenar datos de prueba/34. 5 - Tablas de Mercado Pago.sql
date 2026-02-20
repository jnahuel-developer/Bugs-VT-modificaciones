USE BugsDev;
GO

/* ============================================================
   CARGA DE PRUEBAS - MercadoPago
   Idempotente + limpieza opcional
   ============================================================ */

-- IDs base (coherentes con scripts de prueba)
DECLARE @OperadorDarioId   UNIQUEIDENTIFIER = '11111111-1111-1111-1111-111111111111';
DECLARE @OperadorErnestoId UNIQUEIDENTIFIER = '22222222-2222-2222-2222-222222222222';
DECLARE @MaquinaDevId      UNIQUEIDENTIFIER = '88888888-8888-8888-8888-888888888888';

-- Verificación operador base
IF NOT EXISTS (SELECT 1 FROM Operador WHERE OperadorID = @OperadorDarioId)
BEGIN
    RAISERROR('No existe Operador 1111... Ejecute el script "30. 1 - Datos base de pruebas.sql".', 16, 1);
    RETURN;
END

-- Resolver MaquinaID de pruebas (fallback si no existe la 8888)
IF NOT EXISTS (SELECT 1 FROM Maquina WHERE MaquinaID = @MaquinaDevId)
BEGIN
    SELECT TOP (1) @MaquinaDevId = MaquinaID
    FROM Maquina
    WHERE OperadorID = @OperadorDarioId
    ORDER BY MaquinaID;

    IF @MaquinaDevId IS NULL
    BEGIN
        RAISERROR('No existe ninguna Maquina para el Operador 1111... Ejecute el script "31. 2 - Infraestructura VT.sql".', 16, 1);
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
-- 2) Limpieza opcional (solo pruebas)
-------------------------------------------------------------
-- DELETE FROM MercadoPagoTable WHERE Comprobante LIKE 'MP-TEST-%';

-------------------------------------------------------------
-- 3) Insert de pagos de prueba (idempotente)
-------------------------------------------------------------
DECLARE @Now DATETIME = GETDATE();

-- Insertar 10 pagos de diciembre 2025
DECLARE @Pagos TABLE
(
    Comprobante NVARCHAR(50),
    Fecha DATETIME,
    Monto DECIMAL(18,2),
    OperadorId UNIQUEIDENTIFIER,
    MaquinaId UNIQUEIDENTIFIER,
    EstadoFinId INT,
    EstadoTransId INT,
    Descripcion NVARCHAR(200),
    Entidad NVARCHAR(10),
    Reintentos INT
);

INSERT INTO @Pagos VALUES
('MP-TEST-0001', '2025-12-05T10:00:00',  150.00, @OperadorDarioId,  @MaquinaDevId, 2, 2, NULL, N'MP', 0),
('MP-TEST-0002', '2025-12-06T11:00:00',  210.50, @OperadorDarioId,  @MaquinaDevId, 2, 1, NULL, N'MP', 0),
('MP-TEST-0003', '2025-12-07T12:00:00',  320.00, @OperadorDarioId,  @MaquinaDevId, 2, 2, NULL, N'MP', 0),
('MP-TEST-0004', '2025-12-08T13:00:00',   80.00, @OperadorErnestoId, NULL,         2, 2, NULL, N'MP', 0),
('MP-TEST-0005', '2025-12-09T14:00:00',  999.99, @OperadorErnestoId, NULL,         3, 4, NULL, N'MP', 1),
('MP-TEST-0006', '2025-12-10T15:00:00',   45.30, @OperadorDarioId,  @MaquinaDevId, 1, 3, NULL, N'MP', 0),
('MP-TEST-0007', '2025-12-11T16:00:00',  560.00, @OperadorDarioId,  @MaquinaDevId, 2, 2, NULL, N'MP', 0),
('MP-TEST-0008', '2025-12-12T17:00:00',   75.00, @OperadorDarioId,  @MaquinaDevId, 4, 5, NULL, N'MP', 0),
('MP-TEST-0009', '2025-12-13T18:00:00',  130.10, @OperadorErnestoId, NULL,         2, 2, NULL, N'MP', 0),
('MP-TEST-0010', '2025-12-14T19:00:00',  220.00, @OperadorDarioId,  @MaquinaDevId, 2, 2, NULL, N'MP', 0);

INSERT INTO MercadoPagoTable
(
    Fecha, Monto, MaquinaId, MercadoPagoEstadoFinancieroId, MercadoPagoEstadoTransmisionId,
    OperadorId, Comprobante, Descripcion, FechaModificacionEstadoTransmision,
    Entidad, UrlDevolucion, Reintentos
)
SELECT
    p.Fecha, p.Monto, p.MaquinaId, p.EstadoFinId, p.EstadoTransId,
    p.OperadorId, p.Comprobante, p.Descripcion, NULL,
    p.Entidad, NULL, p.Reintentos
FROM @Pagos p
WHERE NOT EXISTS (SELECT 1 FROM MercadoPagoTable mp WHERE mp.Comprobante = p.Comprobante);
