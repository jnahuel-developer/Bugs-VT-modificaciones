USE BugsDev;
GO

/* ============================================================
   Script 2 - Infraestructura VT
   - 3 Terminales de pruebas asociadas al Operador 101 (ID 1111...)
   - 3 Máquinas de pruebas ligadas a Operador + Locación + Terminal
   ============================================================ */

PRINT '=== Script 2: Infraestructura VT (3 máquinas + 3 terminales) ===';

-------------------------------------------------------------
-- 0) IDs fijos (coherentes con Script 1)
-------------------------------------------------------------
DECLARE @OperadorNahuelId       UNIQUEIDENTIFIER = '11111111-1111-1111-1111-111111111111';
DECLARE @LocacionPruebasId      UNIQUEIDENTIFIER = '33333333-3333-3333-3333-333333333333';
DECLARE @ModeloTerminalBaseId   UNIQUEIDENTIFIER = '55555555-5555-5555-5555-555555555555';

DECLARE @TerminalDevId          UNIQUEIDENTIFIER = '77777777-7777-7777-7777-777777777777';
DECLARE @TerminalDev2Id         UNIQUEIDENTIFIER = '77777777-7777-7777-7777-777777777772';
DECLARE @TerminalDev3Id         UNIQUEIDENTIFIER = '77777777-7777-7777-7777-777777777773';

DECLARE @MaquinaDevId           UNIQUEIDENTIFIER = '88888888-8888-8888-8888-888888888888';
DECLARE @MaquinaDev2Id          UNIQUEIDENTIFIER = '88888888-8888-8888-8888-888888888882';
DECLARE @MaquinaDev3Id          UNIQUEIDENTIFIER = '88888888-8888-8888-8888-888888888883';

-------------------------------------------------------------
-- 1) Verificación de existencia de Operador / Locación / ModeloTerminal
-------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM Operador WHERE OperadorID = @OperadorNahuelId)
BEGIN
    RAISERROR('No se encontró el Operador (ID 1111...). Ejecute primero el Script 1.', 16, 1);
    RETURN;
END

IF NOT EXISTS (SELECT 1 FROM Locacion WHERE LocacionID = @LocacionPruebasId)
BEGIN
    RAISERROR('No se encontró la Locación de pruebas (ID 3333...). Ejecute primero el Script 1.', 16, 1);
    RETURN;
END

IF NOT EXISTS (SELECT 1 FROM ModeloTerminal WHERE ModeloTerminalID = @ModeloTerminalBaseId)
BEGIN
    RAISERROR('No se encontró el ModeloTerminal base (ID 5555...). Ejecute primero el Script 1.', 16, 1);
    RETURN;
END

-------------------------------------------------------------
-- 2) Obtener un MarcaModelo y un TipoProducto existentes
--    (se usan como catálogos de máquina)
-------------------------------------------------------------
PRINT '2) Obteniendo MarcaModelo y TipoProducto de catálogo...';

DECLARE @MarcaModeloDevId  UNIQUEIDENTIFIER;
DECLARE @TipoProductoDevId UNIQUEIDENTIFIER;

SELECT TOP (1) @MarcaModeloDevId = MarcaModeloID
FROM MarcaModelo
ORDER BY MarcaModeloID;

IF @MarcaModeloDevId IS NULL
BEGIN
    RAISERROR('No existen registros en MarcaModelo. Cree al menos uno antes de ejecutar este script.', 16, 1);
    RETURN;
END

SELECT TOP (1) @TipoProductoDevId = TipoProductoID
FROM TipoProducto
ORDER BY TipoProductoID;

IF @TipoProductoDevId IS NULL
BEGIN
    RAISERROR('No existen registros en TipoProducto. Cree al menos uno antes de ejecutar este script.', 16, 1);
    RETURN;
END

PRINT '   - MarcaModelo usado:   ' + CONVERT(NVARCHAR(36), @MarcaModeloDevId);
PRINT '   - TipoProducto usado:  ' + CONVERT(NVARCHAR(36), @TipoProductoDevId);

-------------------------------------------------------------
-- 3) Crear 3 Terminales de pruebas
-------------------------------------------------------------
PRINT '3) Creando Terminales de pruebas...';

-- Terminal 1
IF NOT EXISTS (SELECT 1 FROM Terminal WHERE TerminalID = @TerminalDevId)
BEGIN
    INSERT INTO Terminal
    (
        TerminalID,
        NumeroSerie,
        Interfaz,
        Version,
        FechaFabricacion,
        FechaEstadoSeteosEscritura,
        TipoLector_out,
        FechaAlta,
        MaquinaID,
        OperadorID,
        ModeloTerminalID,
        Perifericos,
        ModuloComunicacion,
        SimCard,
        NivelSenal1,
        NivelSenal2,
        NivelSenal3,
        FechaNivel1,
        FechaNivel2,
        FechaNivel3
    )
    VALUES
    (
        @TerminalDevId,
        10001,
        N'TCP/IP',
        1,
        GETDATE(),
        NULL,
        NULL,
        GETDATE(),
        NULL,
        @OperadorNahuelId,
        @ModeloTerminalBaseId,
        NULL,
        N'Módulo 4G de pruebas',
        N'SIM-PRUEBA-0001',
        80,
        75,
        70,
        DATEADD(DAY, -3, GETDATE()),
        DATEADD(DAY, -2, GETDATE()),
        DATEADD(DAY, -1, GETDATE())
    );

    PRINT '   - Terminal 1 creada.';
END
ELSE
    PRINT '   - Terminal 1 ya existía.';

-- Terminal 2
IF NOT EXISTS (SELECT 1 FROM Terminal WHERE TerminalID = @TerminalDev2Id)
BEGIN
    INSERT INTO Terminal
    (
        TerminalID,
        NumeroSerie,
        Interfaz,
        Version,
        FechaFabricacion,
        FechaEstadoSeteosEscritura,
        TipoLector_out,
        FechaAlta,
        MaquinaID,
        OperadorID,
        ModeloTerminalID,
        Perifericos,
        ModuloComunicacion,
        SimCard,
        NivelSenal1,
        NivelSenal2,
        NivelSenal3,
        FechaNivel1,
        FechaNivel2,
        FechaNivel3
    )
    VALUES
    (
        @TerminalDev2Id,
        10002,
        N'TCP/IP',
        1,
        GETDATE(),
        NULL,
        NULL,
        GETDATE(),
        NULL,
        @OperadorNahuelId,
        @ModeloTerminalBaseId,
        NULL,
        N'Módulo 4G de pruebas',
        N'SIM-PRUEBA-0002',
        80,
        75,
        70,
        DATEADD(DAY, -3, GETDATE()),
        DATEADD(DAY, -2, GETDATE()),
        DATEADD(DAY, -1, GETDATE())
    );

    PRINT '   - Terminal 2 creada.';
END
ELSE
    PRINT '   - Terminal 2 ya existía.';

-- Terminal 3
IF NOT EXISTS (SELECT 1 FROM Terminal WHERE TerminalID = @TerminalDev3Id)
BEGIN
    INSERT INTO Terminal
    (
        TerminalID,
        NumeroSerie,
        Interfaz,
        Version,
        FechaFabricacion,
        FechaEstadoSeteosEscritura,
        TipoLector_out,
        FechaAlta,
        MaquinaID,
        OperadorID,
        ModeloTerminalID,
        Perifericos,
        ModuloComunicacion,
        SimCard,
        NivelSenal1,
        NivelSenal2,
        NivelSenal3,
        FechaNivel1,
        FechaNivel2,
        FechaNivel3
    )
    VALUES
    (
        @TerminalDev3Id,
        10003,
        N'TCP/IP',
        1,
        GETDATE(),
        NULL,
        NULL,
        GETDATE(),
        NULL,
        @OperadorNahuelId,
        @ModeloTerminalBaseId,
        NULL,
        N'Módulo 4G de pruebas',
        N'SIM-PRUEBA-0003',
        80,
        75,
        70,
        DATEADD(DAY, -3, GETDATE()),
        DATEADD(DAY, -2, GETDATE()),
        DATEADD(DAY, -1, GETDATE())
    );

    PRINT '   - Terminal 3 creada.';
END
ELSE
    PRINT '   - Terminal 3 ya existía.';

-------------------------------------------------------------
-- 4) Crear 3 Máquinas de pruebas ligadas a Operador + Locación + Terminal
-------------------------------------------------------------
PRINT '4) Creando Máquinas de pruebas...';

-- Máquina 1
IF NOT EXISTS (SELECT 1 FROM Maquina WHERE MaquinaID = @MaquinaDevId)
BEGIN
    INSERT INTO Maquina
    (
        MaquinaID,
        FechaAviso,
        FechaEstado,
        AlarmaActiva,
        Zona,
        NumeroSerie,
        NombreAlias,
        Ubicacion,
        Estado,
        EstadoConexion,
        Mensaje,
        NotasService,
        ContadorVentasParcial,
        MontoVentasParcial,
        ContadorVentasHistorico,
        MontoVentasHistorico,
        FechaUltimoService,
        FechaUltimaRecaudacion,
        FechaUltimaReposicion,
        FechaUltimoOk,
        FechaUltimaConexion,
        TotalRecaudado,
        SoloVentaEfectivo,
        ValorVenta,
        Decimales,
        FactorEscala,
        TiempoSesion,
        CreditoMaximoCash,
        ValorChannelA,
        ValorChannelB,
        ValorChannelC,
        ValorChannelD,
        ValorChannelE,
        ValorChannelF,
        ValorBillete1,
        ValorBillete2,
        ValorBillete3,
        ValorBillete4,
        ValorBillete5,
        ValorBillete6,
        DescuentoPorcentual,
        LocacionID,
        MarcaModeloID,
        TerminalID,
        OperadorID,
        TipoProductoID
    )
    VALUES
    (
        @MaquinaDevId,
        GETDATE(),
        GETDATE(),
        0,
        1,
        N'MQ-DEV-0001',
        N'MQ Dev 1',
        N'Lobby Sede Central',
        N'Operativa',
        N'Conectada',
        N'OK',
        N'Revisión inicial completada',
        0,
        0.00,
        0,
        0.00,
        NULL,
        NULL,
        NULL,
        NULL,
        GETDATE(),
        0.00,
        0,
        200.00,
        2,
        1,
        60,
        1000.00,
        10.00,
        20.00,
        50.00,
        100.00,
        200.00,
        500.00,
        10.00,
        20.00,
        50.00,
        100.00,
        200.00,
        500.00,
        0.00,
        @LocacionPruebasId,
        @MarcaModeloDevId,
        @TerminalDevId,
        @OperadorNahuelId,
        @TipoProductoDevId
    );

    PRINT '   - Máquina 1 creada.';
END
ELSE
    PRINT '   - Máquina 1 ya existía.';

-- Máquina 2
IF NOT EXISTS (SELECT 1 FROM Maquina WHERE MaquinaID = @MaquinaDev2Id)
BEGIN
    INSERT INTO Maquina
    (
        MaquinaID,
        FechaAviso,
        FechaEstado,
        AlarmaActiva,
        Zona,
        NumeroSerie,
        NombreAlias,
        Ubicacion,
        Estado,
        EstadoConexion,
        Mensaje,
        NotasService,
        ContadorVentasParcial,
        MontoVentasParcial,
        ContadorVentasHistorico,
        MontoVentasHistorico,
        FechaUltimoService,
        FechaUltimaRecaudacion,
        FechaUltimaReposicion,
        FechaUltimoOk,
        FechaUltimaConexion,
        TotalRecaudado,
        SoloVentaEfectivo,
        ValorVenta,
        Decimales,
        FactorEscala,
        TiempoSesion,
        CreditoMaximoCash,
        ValorChannelA,
        ValorChannelB,
        ValorChannelC,
        ValorChannelD,
        ValorChannelE,
        ValorChannelF,
        ValorBillete1,
        ValorBillete2,
        ValorBillete3,
        ValorBillete4,
        ValorBillete5,
        ValorBillete6,
        DescuentoPorcentual,
        LocacionID,
        MarcaModeloID,
        TerminalID,
        OperadorID,
        TipoProductoID
    )
    VALUES
    (
        @MaquinaDev2Id,
        GETDATE(),
        GETDATE(),
        0,
        1,
        N'MQ-DEV-0002',
        N'MQ Dev 2',
        N'Pasillo Sede Central',
        N'Operativa',
        N'Conectada',
        N'OK',
        N'Revisión inicial completada',
        0,
        0.00,
        0,
        0.00,
        NULL,
        NULL,
        NULL,
        NULL,
        GETDATE(),
        0.00,
        0,
        200.00,
        2,
        1,
        60,
        1000.00,
        10.00,
        20.00,
        50.00,
        100.00,
        200.00,
        500.00,
        10.00,
        20.00,
        50.00,
        100.00,
        200.00,
        500.00,
        0.00,
        @LocacionPruebasId,
        @MarcaModeloDevId,
        @TerminalDev2Id,
        @OperadorNahuelId,
        @TipoProductoDevId
    );

    PRINT '   - Máquina 2 creada.';
END
ELSE
    PRINT '   - Máquina 2 ya existía.';

-- Máquina 3
IF NOT EXISTS (SELECT 1 FROM Maquina WHERE MaquinaID = @MaquinaDev3Id)
BEGIN
    INSERT INTO Maquina
    (
        MaquinaID,
        FechaAviso,
        FechaEstado,
        AlarmaActiva,
        Zona,
        NumeroSerie,
        NombreAlias,
        Ubicacion,
        Estado,
        EstadoConexion,
        Mensaje,
        NotasService,
        ContadorVentasParcial,
        MontoVentasParcial,
        ContadorVentasHistorico,
        MontoVentasHistorico,
        FechaUltimoService,
        FechaUltimaRecaudacion,
        FechaUltimaReposicion,
        FechaUltimoOk,
        FechaUltimaConexion,
        TotalRecaudado,
        SoloVentaEfectivo,
        ValorVenta,
        Decimales,
        FactorEscala,
        TiempoSesion,
        CreditoMaximoCash,
        ValorChannelA,
        ValorChannelB,
        ValorChannelC,
        ValorChannelD,
        ValorChannelE,
        ValorChannelF,
        ValorBillete1,
        ValorBillete2,
        ValorBillete3,
        ValorBillete4,
        ValorBillete5,
        ValorBillete6,
        DescuentoPorcentual,
        LocacionID,
        MarcaModeloID,
        TerminalID,
        OperadorID,
        TipoProductoID
    )
    VALUES
    (
        @MaquinaDev3Id,
        GETDATE(),
        GETDATE(),
        0,
        1,
        N'MQ-DEV-0003',
        N'MQ Dev 3',
        N'Sala de reuniones',
        N'Operativa',
        N'Conectada',
        N'OK',
        N'Revisión inicial completada',
        0,
        0.00,
        0,
        0.00,
        NULL,
        NULL,
        NULL,
        NULL,
        GETDATE(),
        0.00,
        0,
        200.00,
        2,
        1,
        60,
        1000.00,
        10.00,
        20.00,
        50.00,
        100.00,
        200.00,
        500.00,
        10.00,
        20.00,
        50.00,
        100.00,
        200.00,
        500.00,
        0.00,
        @LocacionPruebasId,
        @MarcaModeloDevId,
        @TerminalDev3Id,
        @OperadorNahuelId,
        @TipoProductoDevId
    );

    PRINT '   - Máquina 3 creada.';
END
ELSE
    PRINT '   - Máquina 3 ya existía.';

-------------------------------------------------------------
-- 5) Resumen
-------------------------------------------------------------
PRINT '5) Resumen de infraestructura creada:';

SELECT 
    t.TerminalID,
    t.NumeroSerie,
    t.Interfaz,
    t.Version,
    t.OperadorID
FROM Terminal t
WHERE t.TerminalID IN (@TerminalDevId, @TerminalDev2Id, @TerminalDev3Id);

SELECT 
    m.MaquinaID,
    m.NumeroSerie,
    m.NombreAlias,
    m.Ubicacion,
    m.LocacionID,
    m.OperadorID,
    m.TerminalID,
    m.MarcaModeloID,
    m.TipoProductoID
FROM Maquina m
WHERE m.MaquinaID IN (@MaquinaDevId, @MaquinaDev2Id, @MaquinaDev3Id);

PRINT '=== Fin Script 2: Infraestructura VT ===';
GO
