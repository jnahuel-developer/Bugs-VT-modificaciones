/* 
    StockNotifier – Datos de prueba (Pagos simples y mixtos)
    Objetivo:
      - Cargar casos representativos para validar la lógica de selección de devoluciones del StockNotifier
      - Incluir pagos simples y pagos mixtos (MercadoPagoOperacionMixta) para verificar devolución doble

    Importante:
      - Este script NO crea Maquinas/Operadores: toma IDs existentes desde la base (evita conflictos de FK).
      - Los PaymentId (Comprobante) son valores ficticios. Si desea probar contra Mercado Pago real/sandbox,
        reemplace por PaymentId válidos.
*/

SET NOCOUNT ON;

BEGIN TRY

    -------------------------------------------------------------------------
    -- 0) Validaciones mínimas
    -------------------------------------------------------------------------
    IF OBJECT_ID('dbo.MercadoPagoTable') IS NULL
        THROW 50000, 'No existe dbo.MercadoPagoTable. Ejecute los scripts de creación/seed previos.', 1;

    IF OBJECT_ID('dbo.MercadoPagoOperacionMixta') IS NULL
        THROW 50000, 'No existe dbo.MercadoPagoOperacionMixta. Ejecute el script de creación de pagos mixtos.', 1;

    IF OBJECT_ID('dbo.MercadoPagoEstadoFinanciero') IS NULL OR OBJECT_ID('dbo.MercadoPagoEstadoTransmision') IS NULL
        THROW 50000, 'Faltan tablas de estados de Mercado Pago (EstadoFinanciero/EstadoTransmision).', 1;

    IF OBJECT_ID('dbo.Maquina') IS NULL OR OBJECT_ID('dbo.Operador') IS NULL
        THROW 50000, 'Faltan tablas Maquina u Operador.', 1;

    -------------------------------------------------------------------------
    -- 1) Resolver IDs (sin hardcodear GUIDs)
    -------------------------------------------------------------------------
    DECLARE 
        @Fin_ACREDITADO           INT,
        @Fin_DEVUELTO             INT,
        @Trans_EN_PROCESO         INT,
        @Trans_TERMINADO_OK       INT,
        @Trans_TERMINADO_MAL      INT,
        @Trans_ERROR_CONEXION     INT;

    SELECT @Fin_ACREDITADO = Id 
    FROM dbo.MercadoPagoEstadoFinanciero 
    WHERE UPPER(Descripcion) = 'ACREDITADO';

    SELECT @Fin_DEVUELTO = Id 
    FROM dbo.MercadoPagoEstadoFinanciero 
    WHERE UPPER(Descripcion) = 'DEVUELTO';

    SELECT @Trans_EN_PROCESO = Id
    FROM dbo.MercadoPagoEstadoTransmision
    WHERE UPPER(Descripcion) = 'EN_PROCESO';

    SELECT @Trans_TERMINADO_OK = Id
    FROM dbo.MercadoPagoEstadoTransmision
    WHERE UPPER(Descripcion) = 'TERMINADO_OK';

    SELECT @Trans_TERMINADO_MAL = Id
    FROM dbo.MercadoPagoEstadoTransmision
    WHERE UPPER(Descripcion) = 'TERMINADO_MAL';

    SELECT @Trans_ERROR_CONEXION = Id
    FROM dbo.MercadoPagoEstadoTransmision
    WHERE UPPER(Descripcion) = 'ERROR_CONEXION';

    IF @Fin_ACREDITADO IS NULL OR @Fin_DEVUELTO IS NULL
        THROW 50001, 'No se pudieron resolver estados financieros (ACREDITADO/DEVUELTO). Verifique seeds de estados.', 1;

    IF @Trans_EN_PROCESO IS NULL OR @Trans_TERMINADO_OK IS NULL OR @Trans_TERMINADO_MAL IS NULL OR @Trans_ERROR_CONEXION IS NULL
        THROW 50002, 'No se pudieron resolver estados de transmisión. Verifique seeds de estados.', 1;

    -- Elegir operadores (uno con AccessToken si existe y otro sin AccessToken si existe)
    DECLARE 
        @OperadorConToken UNIQUEIDENTIFIER,
        @OperadorSinToken UNIQUEIDENTIFIER;

    SELECT TOP 1 @OperadorConToken = OperadorID
    FROM dbo.Operador
    WHERE AccessToken IS NOT NULL AND LTRIM(RTRIM(AccessToken)) <> ''
    ORDER BY Numero;

    SELECT TOP 1 @OperadorSinToken = OperadorID
    FROM dbo.Operador
    WHERE AccessToken IS NULL OR LTRIM(RTRIM(AccessToken)) = ''
    ORDER BY Numero;

    -- Fallback: si no existe un operador con/sin token, usar cualquiera (para que el seed no falle)
    IF @OperadorConToken IS NULL
        SELECT TOP 1 @OperadorConToken = OperadorID FROM dbo.Operador ORDER BY Numero;

    IF @OperadorSinToken IS NULL
        SELECT TOP 1 @OperadorSinToken = OperadorID FROM dbo.Operador ORDER BY Numero DESC;

    IF @OperadorConToken IS NULL
        THROW 50003, 'No hay registros en Operador. Ejecute el seed de infraestructura primero.', 1;

    -- Elegir máquinas existentes (idealmente asociadas al operador con token)
    DECLARE 
        @Maquina1 UNIQUEIDENTIFIER,
        @Maquina2 UNIQUEIDENTIFIER;

    SELECT TOP 1 @Maquina1 = MaquinaID
    FROM dbo.Maquina
    WHERE OperadorID = @OperadorConToken
    ORDER BY NumeroSerie;

    IF @Maquina1 IS NULL
        SELECT TOP 1 @Maquina1 = MaquinaID FROM dbo.Maquina ORDER BY NumeroSerie;

    SELECT TOP 1 @Maquina2 = MaquinaID
    FROM dbo.Maquina
    WHERE MaquinaID <> @Maquina1
    ORDER BY NumeroSerie;

    IF @Maquina1 IS NULL
        THROW 50004, 'No hay registros en Maquina. Ejecute el seed de infraestructura primero.', 1;

    -------------------------------------------------------------------------
    -- 2) Limpieza previa (idempotencia)
    -------------------------------------------------------------------------
    DECLARE @Tag NVARCHAR(50) = N'SN_TEST:'; -- prefijo de Descripcion/ExternalReference

    DELETE FROM dbo.MercadoPagoTable
    WHERE Descripcion LIKE @Tag + N'%';

    DELETE FROM dbo.MercadoPagoOperacionMixta
    WHERE ExternalReference LIKE @Tag + N'%';

    -------------------------------------------------------------------------
    -- 3) Definición de casos de prueba
    --    - "CANDIDATO" = debería ser tomado por StockNotifier para devolución:
    --        Fin=ACREDITADO y Transmisión != TERMINADO_OK 
    --        y (Transmisión != EN_PROCESO o pago viejo > 5 min)
    -------------------------------------------------------------------------
    DECLARE @Pagos TABLE
    (
        Fecha                     DATETIME       NOT NULL,
        Monto                     DECIMAL(18,2)  NOT NULL,
        MaquinaId                 UNIQUEIDENTIFIER NULL,
        EstadoFinId               INT            NOT NULL,
        EstadoTransId             INT            NOT NULL,
        OperadorId                UNIQUEIDENTIFIER NULL,
        Comprobante               NVARCHAR(200)  NOT NULL,
        Descripcion               NVARCHAR(500)  NOT NULL,
        Entidad                   NVARCHAR(200)  NOT NULL,
        Reintentos                INT            NOT NULL
    );

    -------------------------------------------------------------------------
    -- A) Pagos simples
    -------------------------------------------------------------------------

    -- A1) SIMPLE - CANDIDATO (TERMINADO_MAL)
    INSERT INTO @Pagos VALUES
    (
        DATEADD(MINUTE, -30, GETDATE()), 1200.00, @Maquina1, @Fin_ACREDITADO, @Trans_TERMINADO_MAL,
        @OperadorConToken, N'900000000001', @Tag + N'SIMPLE:CANDIDATO:TERMINADO_MAL', N'MercadoPago', 0
    );

    -- A2) SIMPLE - CANDIDATO (EN_PROCESO viejo > 5 min)
    INSERT INTO @Pagos VALUES
    (
        DATEADD(MINUTE, -10, GETDATE()), 1300.00, @Maquina1, @Fin_ACREDITADO, @Trans_EN_PROCESO,
        @OperadorConToken, N'900000000002', @Tag + N'SIMPLE:CANDIDATO:EN_PROCESO_VIEJO', N'MercadoPago', 0
    );

    -- A3) SIMPLE - NO CANDIDATO (EN_PROCESO reciente <= 5 min)
    INSERT INTO @Pagos VALUES
    (
        DATEADD(MINUTE, -1, GETDATE()),  1400.00, @Maquina1, @Fin_ACREDITADO, @Trans_EN_PROCESO,
        @OperadorConToken, N'900000000003', @Tag + N'SIMPLE:NO_CANDIDATO:EN_PROCESO_RECIENTE', N'MercadoPago', 0
    );

    -- A4) SIMPLE - NO CANDIDATO (TERMINADO_OK)
    INSERT INTO @Pagos VALUES
    (
        DATEADD(MINUTE, -60, GETDATE()), 1500.00, @Maquina2, @Fin_ACREDITADO, @Trans_TERMINADO_OK,
        @OperadorConToken, N'900000000004', @Tag + N'SIMPLE:NO_CANDIDATO:TERMINADO_OK', N'MercadoPago', 0
    );

    -- A5) SIMPLE - NO CANDIDATO (ya DEVUELTO)
    INSERT INTO @Pagos VALUES
    (
        DATEADD(MINUTE, -120, GETDATE()), 1600.00, @Maquina2, @Fin_DEVUELTO, @Trans_TERMINADO_MAL,
        @OperadorConToken, N'900000000005', @Tag + N'SIMPLE:NO_CANDIDATO:YA_DEVUELTO', N'MercadoPago', 0
    );

    -- A6) SIMPLE - CANDIDATO, operador SIN token (ejercita rama "rechazo" en StockNotifier)
    INSERT INTO @Pagos VALUES
    (
        DATEADD(MINUTE, -25, GETDATE()), 1700.00, @Maquina2, @Fin_ACREDITADO, @Trans_ERROR_CONEXION,
        @OperadorSinToken, N'900000000006', @Tag + N'SIMPLE:CANDIDATO:OPERADOR_SIN_TOKEN', N'MercadoPago', 0
    );

    -------------------------------------------------------------------------
    -- B) Pagos mixtos (se crea 1 fila en MercadoPagoTable + 1 fila en MercadoPagoOperacionMixta)
    --    StockNotifier (modificado) detecta el mixto si el PaymentId (Comprobante) está en PaymentId1 o PaymentId2.
    -------------------------------------------------------------------------

    -- B1) MIXTO - CANDIDATO: debe devolver PaymentId1 y PaymentId2
    DECLARE @MixExtRef1 NVARCHAR(200) = @Tag + N'MIXTO:01';
    DECLARE @MixP1_1 BIGINT = 910000000001;
    DECLARE @MixP1_2 BIGINT = 910000000002;

    INSERT INTO dbo.MercadoPagoOperacionMixta
    (
        OperadorId, ExternalReference, FechaAuthorizedUtc,
        MontoAcumulado, ApprovedCount, PaymentId1, PaymentId2,
        Cerrada, FechaCierreUtc
    )
    VALUES
    (
        @OperadorConToken, @MixExtRef1, DATEADD(MINUTE, -40, GETUTCDATE()),
        2000.00, 2, @MixP1_1, @MixP1_2,
        1, DATEADD(MINUTE, -39, GETUTCDATE())
    );

    -- En MercadoPagoTable, por convención del sistema, Comprobante suele quedar con el último PaymentId aprobado.
    INSERT INTO @Pagos VALUES
    (
        DATEADD(MINUTE, -35, GETDATE()), 2000.00, @Maquina1, @Fin_ACREDITADO, @Trans_TERMINADO_MAL,
        @OperadorConToken, CONVERT(NVARCHAR(200), @MixP1_2), @Tag + N'MIXTO:CANDIDATO:DEVOLVER_AMBOS', N'MercadoPago', 0
    );

    -- B2) MIXTO - NO CANDIDATO (TERMINADO_OK): NO debería intentar devolver
    DECLARE @MixExtRef2 NVARCHAR(200) = @Tag + N'MIXTO:02';
    DECLARE @MixP2_1 BIGINT = 910000000003;
    DECLARE @MixP2_2 BIGINT = 910000000004;

    INSERT INTO dbo.MercadoPagoOperacionMixta
    (
        OperadorId, ExternalReference, FechaAuthorizedUtc,
        MontoAcumulado, ApprovedCount, PaymentId1, PaymentId2,
        Cerrada, FechaCierreUtc
    )
    VALUES
    (
        @OperadorConToken, @MixExtRef2, DATEADD(MINUTE, -50, GETUTCDATE()),
        2100.00, 2, @MixP2_1, @MixP2_2,
        1, DATEADD(MINUTE, -49, GETUTCDATE())
    );

    INSERT INTO @Pagos VALUES
    (
        DATEADD(MINUTE, -45, GETDATE()), 2100.00, @Maquina1, @Fin_ACREDITADO, @Trans_TERMINADO_OK,
        @OperadorConToken, CONVERT(NVARCHAR(200), @MixP2_2), @Tag + N'MIXTO:NO_CANDIDATO:TERMINADO_OK', N'MercadoPago', 0
    );

    -- B3) MIXTO - CANDIDATO (EN_PROCESO viejo) + Operador SIN token
    DECLARE @MixExtRef3 NVARCHAR(200) = @Tag + N'MIXTO:03';
    DECLARE @MixP3_1 BIGINT = 910000000005;
    DECLARE @MixP3_2 BIGINT = 910000000006;

    INSERT INTO dbo.MercadoPagoOperacionMixta
    (
        OperadorId, ExternalReference, FechaAuthorizedUtc,
        MontoAcumulado, ApprovedCount, PaymentId1, PaymentId2,
        Cerrada, FechaCierreUtc
    )
    VALUES
    (
        @OperadorSinToken, @MixExtRef3, DATEADD(MINUTE, -20, GETUTCDATE()),
        2200.00, 2, @MixP3_1, @MixP3_2,
        1, DATEADD(MINUTE, -19, GETUTCDATE())
    );

    INSERT INTO @Pagos VALUES
    (
        DATEADD(MINUTE, -15, GETDATE()), 2200.00, @Maquina2, @Fin_ACREDITADO, @Trans_EN_PROCESO,
        @OperadorSinToken, CONVERT(NVARCHAR(200), @MixP3_2), @Tag + N'MIXTO:CANDIDATO:OPERADOR_SIN_TOKEN', N'MercadoPago', 0
    );

    -------------------------------------------------------------------------
    -- 4) Inserción en MercadoPagoTable (sin MercadoPagoId, como en scripts oficiales)
    -------------------------------------------------------------------------
    INSERT INTO dbo.MercadoPagoTable
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
    WHERE NOT EXISTS (SELECT 1 FROM dbo.MercadoPagoTable mp WHERE mp.Comprobante = p.Comprobante);

    -------------------------------------------------------------------------
    -- 5) Resumen
    -------------------------------------------------------------------------
    PRINT '=== StockNotifier: Pagos de prueba insertados/verificados ===';
    SELECT 
        mp.MercadoPagoId,
        mp.Fecha,
        mp.Monto,
        mp.MaquinaId,
        mp.OperadorId,
        mp.Comprobante,
        mp.MercadoPagoEstadoFinancieroId,
        mp.MercadoPagoEstadoTransmisionId,
        mp.Descripcion
    FROM dbo.MercadoPagoTable mp
    WHERE mp.Descripcion LIKE @Tag + N'%'
    ORDER BY mp.MercadoPagoId;

    PRINT '--- Operaciones mixtas insertadas ---';
    SELECT 
        MercadoPagoOperacionMixtaId,
        OperadorId,
        ExternalReference,
        ApprovedCount,
        PaymentId1,
        PaymentId2,
        Cerrada
    FROM dbo.MercadoPagoOperacionMixta
    WHERE ExternalReference LIKE @Tag + N'%'
    ORDER BY MercadoPagoOperacionMixtaId;

    PRINT '=== Fin ===';

END TRY
BEGIN CATCH
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @Line INT = ERROR_LINE();
    RAISERROR('Error en seed de pagos de prueba. Línea %d. %s', 16, 1, @Line, @Err);
END CATCH;
