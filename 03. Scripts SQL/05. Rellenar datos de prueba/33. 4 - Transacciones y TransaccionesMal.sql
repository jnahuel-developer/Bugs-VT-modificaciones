USE BugsDev;
GO

PRINT '============================================';
PRINT 'SCRIPT 4 - Transacciones y TransaccionesMal';
PRINT '============================================';

------------------------------------------------------------
-- 1) Obtener IDs base (Operador/Locación/.../Texto)
------------------------------------------------------------
DECLARE @OperadorDevId       UNIQUEIDENTIFIER;
DECLARE @LocacionDevId       UNIQUEIDENTIFIER;
DECLARE @JerarquiaDevId      UNIQUEIDENTIFIER;
DECLARE @MaquinaDevId        UNIQUEIDENTIFIER;
DECLARE @TerminalDevId       UNIQUEIDENTIFIER;
DECLARE @ModeloTerminalId    UNIQUEIDENTIFIER;
DECLARE @TransaccionTextoId  UNIQUEIDENTIFIER;

-- Operador Dev
SELECT @OperadorDevId =
       (SELECT TOP 1 OperadorID
        FROM Operador
        WHERE Nombre = N'Dario Conca');

-- Locación Dev
SELECT @LocacionDevId =
       (SELECT TOP 1 LocacionID
        FROM Locacion
        WHERE Nombre = N'Locación Dev Central'
          AND OperadorID = @OperadorDevId);

-- Jerarquía Dev
SELECT @JerarquiaDevId =
       (SELECT TOP 1 JerarquiaID
        FROM Jerarquia
        WHERE Nombre = N'Jerarquía General Dev'
          AND LocacionID = @LocacionDevId);

-- Terminal Dev (cualquier terminal del operador Dev)
SELECT @TerminalDevId =
       (SELECT TOP 1 TerminalID
        FROM Terminal
        WHERE OperadorID = @OperadorDevId
        ORDER BY NumeroSerie);

-- Máquina Dev: cualquier máquina del operador+locación Dev
SELECT @MaquinaDevId =
       (SELECT TOP 1 MaquinaID
        FROM Maquina
        WHERE OperadorID = @OperadorDevId
          AND LocacionID = @LocacionDevId
        ORDER BY NumeroSerie);

-- ModeloTerminal: primero por nombre, si no existe, cualquier registro
SELECT @ModeloTerminalId =
       (SELECT TOP 1 ModeloTerminalID
        FROM ModeloTerminal
        WHERE Modelo = N'Modelo Terminal VT Dev'
        ORDER BY ModeloTerminalID);

IF @ModeloTerminalId IS NULL
BEGIN
    SELECT @ModeloTerminalId =
           (SELECT TOP 1 ModeloTerminalID
            FROM ModeloTerminal
            ORDER BY ModeloTerminalID);
END

-- TransaccionTexto: intentamos por 'VTA' + ese modelo, si no, cualquiera
SELECT @TransaccionTextoId =
       (SELECT TOP 1 TransaccionTextoID
        FROM TransaccionTexto
        WHERE ModeloTerminalID = @ModeloTerminalId
          AND CodigoTransaccion = N'VTA'
        ORDER BY TransaccionTextoID);

IF @TransaccionTextoId IS NULL
BEGIN
    SELECT @TransaccionTextoId =
           (SELECT TOP 1 TransaccionTextoID
            FROM TransaccionTexto
            ORDER BY TransaccionTextoID);
END

------------------------------------------------------------
-- 1.b) Verificación y detalle de lo que falte
------------------------------------------------------------
PRINT '--- DEBUG IDs base ---';
PRINT '  OperadorDevId      = ' + ISNULL(CONVERT(NVARCHAR(36), @OperadorDevId),      'NULL');
PRINT '  LocacionDevId      = ' + ISNULL(CONVERT(NVARCHAR(36), @LocacionDevId),      'NULL');
PRINT '  JerarquiaDevId     = ' + ISNULL(CONVERT(NVARCHAR(36), @JerarquiaDevId),     'NULL');
PRINT '  MaquinaDevId       = ' + ISNULL(CONVERT(NVARCHAR(36), @MaquinaDevId),       'NULL');
PRINT '  TerminalDevId      = ' + ISNULL(CONVERT(NVARCHAR(36), @TerminalDevId),      'NULL');
PRINT '  ModeloTerminalId   = ' + ISNULL(CONVERT(NVARCHAR(36), @ModeloTerminalId),   'NULL');
PRINT '  TransaccionTextoId = ' + ISNULL(CONVERT(NVARCHAR(36), @TransaccionTextoId), 'NULL');

DECLARE @Missing NVARCHAR(4000) = N'';

IF @OperadorDevId IS NULL
    SET @Missing += N'Operador "Dario Conca"; ';
IF @LocacionDevId IS NULL
    SET @Missing += N'Locación "Locación Dev Central"; ';
IF @JerarquiaDevId IS NULL
    SET @Missing += N'Jerarquía "Jerarquía General Dev"; ';
IF @MaquinaDevId IS NULL
    SET @Missing += N'Máquina del operador/locación Dev; ';
IF @TerminalDevId IS NULL
    SET @Missing += N'Terminal del operador Dev; ';
IF @ModeloTerminalId IS NULL
    SET @Missing += N'ModeloTerminal (algún registro en ModeloTerminal); ';
IF @TransaccionTextoId IS NULL
    SET @Missing += N'TransaccionTexto (algún registro en TransaccionTexto); ';

IF (@Missing <> N'')
BEGIN
    RAISERROR(N'Faltan datos base: %s. Verifique los scripts anteriores.', 16, 1, @Missing);
    RETURN;
END;

PRINT ' - IDs base obtenidos correctamente.';



------------------------------------------------------------
-- 2) Construir conjunto de consumidores de prueba
--    (todos los usuarios ligados al Operador Dev)
------------------------------------------------------------
IF OBJECT_ID('tempdb..#ConsumidoresDev') IS NOT NULL
    DROP TABLE #ConsumidoresDev;

SELECT  u.UsuarioID,
        u.Numero,
        u.Nombre,
        u.Apellido
INTO    #ConsumidoresDev
FROM    Usuario u
WHERE   u.OperadorID = @OperadorDevId
        AND u.LocacionID = @LocacionDevId
        AND u.JerarquiaID = @JerarquiaDevId;

DECLARE @ConsumidoresCount INT;
SELECT @ConsumidoresCount = COUNT(*) FROM #ConsumidoresDev;
PRINT ' - Consumidores de prueba: ' + CAST(@ConsumidoresCount AS NVARCHAR(10));

------------------------------------------------------------
-- 3) Insertar 5 Transacciones "buenas" por consumidor
------------------------------------------------------------
PRINT '3) Insertando Transacciones normales...';

;WITH Tally AS (
    SELECT 1 AS n UNION ALL
    SELECT 2 UNION ALL
    SELECT 3 UNION ALL
    SELECT 4 UNION ALL
    SELECT 5
)
INSERT INTO Transaccion (
      TransaccionID,
      FechaAltaBase,
      FechaTransaccion,
      CodigoTransaccion,
      EfectivoInicial,
      EfectivoFinal,
      CreditoInicialZona1,
      CreditoFinalZona1,
      CreditoInicialZona2,
      CreditoFinalZona2,
      CreditoInicialZona3,
      CreditoFinalZona3,
      CreditoInicialZona4,
      CreditoFinalZona4,
      CreditoInicialZona5,
      CreditoFinalZona5,
      ValorVenta,
      ValorRecarga,
      DescuentoAplicado,
      UsuarioService,
      TransaccionOriginal,
      ValorRecorte,
      TransaccionTextoID,
      ArticuloID,
      ModeloTerminalID,
      TerminalID,
      MaquinaID,
      LocacionID,
      OperadorID,
      UsuarioID,
      JerarquiaID
)
SELECT  NEWID()                                           AS TransaccionID,
        DATEADD(DAY, -t.n, GETDATE())                     AS FechaAltaBase,
        DATEADD(DAY, -t.n, GETDATE())                     AS FechaTransaccion,
        N'VTA'                                            AS CodigoTransaccion,
        CAST(0    AS DECIMAL(18,2))                       AS EfectivoInicial,
        CAST(0    AS DECIMAL(18,2))                       AS EfectivoFinal,
        CAST(0    AS DECIMAL(18,2))                       AS CreditoInicialZona1,
        CAST(100  AS DECIMAL(18,2))                       AS CreditoFinalZona1,
        CAST(0    AS DECIMAL(18,2))                       AS CreditoInicialZona2,
        CAST(0    AS DECIMAL(18,2))                       AS CreditoFinalZona2,
        CAST(0    AS DECIMAL(18,2))                       AS CreditoInicialZona3,
        CAST(0    AS DECIMAL(18,2))                       AS CreditoFinalZona3,
        CAST(0    AS DECIMAL(18,2))                       AS CreditoInicialZona4,
        CAST(0    AS DECIMAL(18,2))                       AS CreditoFinalZona4,
        CAST(0    AS DECIMAL(18,2))                       AS CreditoInicialZona5,
        CAST(0    AS DECIMAL(18,2))                       AS CreditoFinalZona5,
        CAST(100  AS DECIMAL(18,2))                       AS ValorVenta,
        CAST(0    AS DECIMAL(18,2))                       AS ValorRecarga,
        CAST(0    AS DECIMAL(18,2))                       AS DescuentoAplicado,
        0                                                 AS UsuarioService,
        N'VT-TEST'                                        AS TransaccionOriginal,
        NULL                                              AS ValorRecorte,
        @TransaccionTextoId                               AS TransaccionTextoID,
        NULL                                              AS ArticuloID,
        @ModeloTerminalId                                 AS ModeloTerminalID,
        @TerminalDevId                                    AS TerminalID,
        @MaquinaDevId                                     AS MaquinaID,
        @LocacionDevId                                    AS LocacionID,
        @OperadorDevId                                    AS OperadorID,
        c.UsuarioID                                       AS UsuarioID,
        @JerarquiaDevId                                   AS JerarquiaID
FROM    #ConsumidoresDev c
CROSS JOIN Tally t;

PRINT '   -> Transacciones normales insertadas: ' 
      + CAST(@@ROWCOUNT AS NVARCHAR(10));

------------------------------------------------------------
-- 4) Insertar TransaccionesMal
--    Para algunos consumidores (ej: Numero par) 2 registros cada uno
------------------------------------------------------------
PRINT '4) Insertando TransaccionesMal...';

INSERT INTO TransaccionesMal (
      IdTransaccionMal,
      TerminalID,
      Transaccion,
      FechaDescarga,
      Motivo,
      MaquinaID,
      LocacionID,
      OperadorID
)
SELECT  NEWID()                                           AS IdTransaccionMal,
        @TerminalDevId                                    AS TerminalID,
        N'TRX_MAL_' + CAST(c.Numero AS NVARCHAR(10))
            + N'_' + CAST(v.n AS NVARCHAR(10))            AS Transaccion,
        DATEADD(HOUR, -v.n, GETDATE())                    AS FechaDescarga,
        N'Error simulado para pruebas de borrado'         AS Motivo,
        @MaquinaDevId                                     AS MaquinaID,
        @LocacionDevId                                    AS LocacionID,
        @OperadorDevId                                    AS OperadorID
FROM    #ConsumidoresDev c
CROSS JOIN (VALUES (1),(2)) AS v(n)
WHERE   c.Numero % 2 = 0;   -- sólo consumidores con número par

PRINT '   -> TransaccionesMal insertadas: ' 
      + CAST(@@ROWCOUNT AS NVARCHAR(10));

PRINT 'SCRIPT 4 finalizado correctamente.';
GO
