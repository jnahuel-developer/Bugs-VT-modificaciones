USE BugsDev;
GO

/* ============================================================
   Script 1 - Datos base de catálogo y operadores/locaciones
   - Operador Dario Conca (principal de pruebas)
   - Operador Ernesto Pérez (extra)
   - Dos locaciones de pruebas (una por operador)
   - Dos jerarquías (una por locación)
   - ModeloTerminal + TransaccionTexto base
   - El Usuario ADMIN NO queda asociado a ningún operador/locación
   ============================================================ */

-------------------------------------------------------------
-- 0) Declaración de IDs fijos para reutilizar en otros scripts
-------------------------------------------------------------
DECLARE @OperadorDarioId       UNIQUEIDENTIFIER = '11111111-1111-1111-1111-111111111111';
DECLARE @OperadorErnestoId      UNIQUEIDENTIFIER = '22222222-2222-2222-2222-222222222222';

DECLARE @LocacionPruebasId      UNIQUEIDENTIFIER = '33333333-3333-3333-3333-333333333333'; -- Locación Dev Central (Dario)
DECLARE @LocacionPruebas2Id     UNIQUEIDENTIFIER = '33333333-3333-3333-3333-333333333334'; -- Locación Dev Secundaria (Ernesto)

DECLARE @JerarquiaBasicaId      UNIQUEIDENTIFIER = '44444444-4444-4444-4444-444444444444'; -- Jerarquía para Locación Dev Central
DECLARE @JerarquiaBasica2Id     UNIQUEIDENTIFIER = '44444444-4444-4444-4444-444444444445'; -- Jerarquía para Locación Dev Secundaria

DECLARE @ModeloTerminalBaseId   UNIQUEIDENTIFIER = '55555555-5555-5555-5555-555555555555';
DECLARE @TransaccionTextoBaseId UNIQUEIDENTIFIER = '66666666-6666-6666-6666-666666666666';

PRINT '=== Script 1: Datos base de pruebas ===';

-------------------------------------------------------------
-- 1) Operadores de prueba
-------------------------------------------------------------
PRINT '1) Creando operadores de prueba...';

-- Operador principal: Dario Conca
DECLARE @TokenDario   NVARCHAR(200) = 'DEV-OP-101';

IF NOT EXISTS (SELECT 1 FROM Operador WHERE OperadorID = @OperadorDarioId)
BEGIN
    INSERT INTO Operador
        (OperadorID, Nombre, Numero, TiempoAvisoInhibicion, TiempoAvisoConexion, ClientId, SecretToken, AccessToken)
    VALUES
        (@OperadorDarioId, 'Dario Conca', 101, 10, 10, NULL, @TokenDario, NULL);
    
    PRINT '- Operador Dario Conca creado.';
END
ELSE
BEGIN
    UPDATE Operador
    SET SecretToken = CASE WHEN SecretToken IS NULL OR LTRIM(RTRIM(SecretToken)) = '' THEN @TokenDario ELSE SecretToken END
    WHERE OperadorID = @OperadorDarioId;

    PRINT '- Operador Dario Conca ya existía.';
END

-- Operador extra: Ernesto Perez
DECLARE @TokenErnesto NVARCHAR(200) = 'DEV-OP-102';

IF NOT EXISTS (SELECT 1 FROM Operador WHERE OperadorID = @OperadorErnestoId)
BEGIN
    INSERT INTO Operador
        (OperadorID, Nombre, Numero, TiempoAvisoInhibicion, TiempoAvisoConexion, ClientId, SecretToken, AccessToken)
    VALUES
        (@OperadorErnestoId, 'Ernesto Perez', 102, 10, 10, NULL, @TokenErnesto, NULL);

    PRINT '- Operador Ernesto Perez creado.';
END
ELSE
BEGIN
    UPDATE Operador
    SET SecretToken = CASE WHEN SecretToken IS NULL OR LTRIM(RTRIM(SecretToken)) = '' THEN @TokenDario ELSE SecretToken END
    WHERE OperadorID = @OperadorDarioId;

    PRINT '- Operador Ernesto Perez ya existía.';
END


-------------------------------------------------------------
-- 2) Locaciones de pruebas (una por operador)
-------------------------------------------------------------
PRINT '2) Creando locaciones de pruebas...';

-- Locación Dev Central -> Operador Dario
IF NOT EXISTS (SELECT 1 FROM Locacion WHERE LocacionID = @LocacionPruebasId)
BEGIN
    INSERT INTO Locacion
        (LocacionID, Nombre, CUIT, Direccion, Localidad, CodigoPostal, Provincia,
         NombreZona1, NombreZona2, NombreZona3, NombreZona4, NombreZona5,
         MostrarUsuario, SaludarUsuario, Numero, OperadorID)
    VALUES
        (@LocacionPruebasId,
         N'Locación Dev Central',
         N'20123456789',
         N'Av. Siempre Viva 123',
         N'Buenos Aires',
         N'C1000',
         N'Buenos Aires',
         N'Zona 1',
         N'Zona 2',
         N'Zona 3',
         N'Zona 4',
         N'Zona 5',
         1,      -- MostrarUsuario
         1,      -- SaludarUsuario
         1,      -- Numero de locación
         @OperadorDarioId);

    PRINT '- Locación Dev Central creada (Operador Dario Conca).';
END
ELSE
    PRINT '- Locación Dev Central ya existía.';

-- Locación Dev Secundaria -> Operador Ernesto
IF NOT EXISTS (SELECT 1 FROM Locacion WHERE LocacionID = @LocacionPruebas2Id)
BEGIN
    INSERT INTO Locacion
        (LocacionID, Nombre, CUIT, Direccion, Localidad, CodigoPostal, Provincia,
         NombreZona1, NombreZona2, NombreZona3, NombreZona4, NombreZona5,
         MostrarUsuario, SaludarUsuario, Numero, OperadorID)
    VALUES
        (@LocacionPruebas2Id,
         N'Locación Dev Secundaria',
         N'20987654321',
         N'Calle Falsa 456',
         N'Buenos Aires',
         N'C2000',
         N'Buenos Aires',
         N'Zona 1',
         N'Zona 2',
         N'Zona 3',
         N'Zona 4',
         N'Zona 5',
         1,      -- MostrarUsuario
         1,      -- SaludarUsuario
         2,      -- Numero de locación
         @OperadorErnestoId);

    PRINT '- Locación Dev Secundaria creada (Operador Ernesto Perez).';
END
ELSE
    PRINT '- Locación Dev Secundaria ya existía.';


-------------------------------------------------------------
-- 3) Jerarquías básicas para cada locación
-------------------------------------------------------------
PRINT '3) Creando jerarquías básicas...';

-- Jerarquía para Locación Dev Central
IF NOT EXISTS (SELECT 1 FROM Jerarquia WHERE JerarquiaID = @JerarquiaBasicaId)
BEGIN
    INSERT INTO Jerarquia
    (
        JerarquiaID,
        Nombre,
        RecargaZona1, RecargaZona2, RecargaZona3, RecargaZona4, RecargaZona5,
        DescuentoPorcentualZona1, DescuentoPorcentualZona2, DescuentoPorcentualZona3,
        DescuentoPorcentualZona4, DescuentoPorcentualZona5,
        MontoRecorteZona1, MontoRecorteZona2, MontoRecorteZona3,
        MontoRecorteZona4, MontoRecorteZona5,
        PeriodoRecargaZona1, PeriodoRecargaZona2, PeriodoRecargaZona3,
        PeriodoRecargaZona4, PeriodoRecargaZona5,
        LocacionID
    )
    VALUES
    (
        @JerarquiaBasicaId,
        N'Jerarquía General Dev',

        100.00, 100.00, 100.00, 100.00, 100.00,  -- Recargas
        0.00, 0.00, 0.00, 0.00, 0.00,            -- Descuentos
        0.00, 0.00, 0.00, 0.00, 0.00,            -- Montos recorte
        30, 30, 30, 30, 30,                      -- Períodos
        @LocacionPruebasId
    );

    PRINT '- Jerarquía General Dev creada para Locación Dev Central.';
END
ELSE
    PRINT '- Jerarquía General Dev ya existía.';

-- Jerarquía para Locación Dev Secundaria
IF NOT EXISTS (SELECT 1 FROM Jerarquia WHERE JerarquiaID = @JerarquiaBasica2Id)
BEGIN
    INSERT INTO Jerarquia
    (
        JerarquiaID,
        Nombre,
        RecargaZona1, RecargaZona2, RecargaZona3, RecargaZona4, RecargaZona5,
        DescuentoPorcentualZona1, DescuentoPorcentualZona2, DescuentoPorcentualZona3,
        DescuentoPorcentualZona4, DescuentoPorcentualZona5,
        MontoRecorteZona1, MontoRecorteZona2, MontoRecorteZona3,
        MontoRecorteZona4, MontoRecorteZona5,
        PeriodoRecargaZona1, PeriodoRecargaZona2, PeriodoRecargaZona3,
        PeriodoRecargaZona4, PeriodoRecargaZona5,
        LocacionID
    )
    VALUES
    (
        @JerarquiaBasica2Id,
        N'Jerarquía General Dev Secundaria',

        120.00, 120.00, 120.00, 120.00, 120.00,  -- Recargas
        5.00,  5.00,  5.00,  5.00,  5.00,        -- Descuentos
        0.00,  0.00,  0.00,  0.00,  0.00,        -- Montos recorte
        30,   30,   30,   30,   30,              -- Períodos
        @LocacionPruebas2Id
    );

    PRINT '- Jerarquía General Dev Secundaria creada para Locación Dev Secundaria.';
END
ELSE
    PRINT '- Jerarquía General Dev Secundaria ya existía.';


-------------------------------------------------------------
-- 4) Catálogos mínimos: ModeloTerminal + TransaccionTexto
-------------------------------------------------------------
PRINT '4) Creando ModeloTerminal y TransaccionTexto base...';

-- ModeloTerminal genérico (se usa sólo para que TransaccionTexto tenga FK válida)
IF NOT EXISTS (SELECT 1 FROM ModeloTerminal WHERE ModeloTerminalID = @ModeloTerminalBaseId)
BEGIN
    INSERT INTO ModeloTerminal (ModeloTerminalID, Modelo)
    VALUES (@ModeloTerminalBaseId, N'Modelo Terminal Genérico Dev');

    PRINT '- ModeloTerminal de pruebas creado.';
END
ELSE
    PRINT '- ModeloTerminal de pruebas ya existía.';

-- TransaccionTexto base para ventas
IF NOT EXISTS (SELECT 1 FROM TransaccionTexto WHERE TransaccionTextoID = @TransaccionTextoBaseId)
BEGIN
    INSERT INTO TransaccionTexto
        (TransaccionTextoID, CodigoTransaccion,
         SumaEnVentas, SumaEnRecargas, SumaEnEfectivo,
         TextoTransaccion, ModeloTerminalID)
    VALUES
        (@TransaccionTextoBaseId,
         N'VT',           -- Código de transacción "Venta"
         1,              -- SumaEnVentas
         0,              -- SumaEnRecargas
         0,              -- SumaEnEfectivo
         N'Venta estándar sistema VT',
         @ModeloTerminalBaseId);

    PRINT '- TransaccionTexto base creada.';
END
ELSE
    PRINT '- TransaccionTexto base ya existía.';


-------------------------------------------------------------
-- 5) El Usuario ADMIN no se asocia a ningún operador/locación
-------------------------------------------------------------
PRINT '5) Desasociando Usuario admin de operadores/locaciones/jerarquías...';

DECLARE @AdminUsuarioId UNIQUEIDENTIFIER;

SELECT TOP 1 @AdminUsuarioId = UsuarioID
FROM AspNetUsers
WHERE Email = 'jnahuel.developer@gmail.com';

IF @AdminUsuarioId IS NOT NULL
BEGIN
    UPDATE u
    SET OperadorID = NULL,
        LocacionID = NULL,
        JerarquiaID = NULL
    FROM Usuario u
    WHERE u.UsuarioID = @AdminUsuarioId;

    PRINT '- Usuario admin desasociado de Operador/Locación/Jerarquía (queda sólo como credencial web).';
END
ELSE
BEGIN
    PRINT '*** ATENCIÓN: No se encontró Usuario vinculado al mail jnahuel.developer@gmail.com en AspNetUsers.';
END

PRINT '=== Fin Script 1: Datos base de pruebas ===';
GO
