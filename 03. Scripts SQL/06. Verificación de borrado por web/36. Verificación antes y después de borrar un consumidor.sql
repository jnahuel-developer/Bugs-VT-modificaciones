USE BugsDev;
GO

-------------------------------------------------------------
-- Chequeo integral de borrado de un Usuario
-- (antes y después de eliminarlo desde la web)
-------------------------------------------------------------
DECLARE @UsuarioId UNIQUEIDENTIFIER = '7C4406CD-4F9B-48FF-AA9D-F300ADD97E42';

PRINT '===============================================================';
PRINT ' CHEQUEO POR USUARIO';
PRINT '   UsuarioId = ' + CONVERT(NVARCHAR(36), @UsuarioId);
PRINT '===============================================================';

-------------------------------------------------------------
-- 0) Intentar obtener OperadorID y LocacionID asociados
--    (desde Usuario o Transaccion, por si el Usuario ya no existe)
-------------------------------------------------------------
DECLARE @OperadorId UNIQUEIDENTIFIER = NULL;
DECLARE @LocacionId UNIQUEIDENTIFIER = NULL;

SELECT TOP 1 
       @OperadorId = OperadorID,
       @LocacionId = LocacionID
FROM (
        SELECT OperadorID, LocacionID
        FROM Usuario
        WHERE UsuarioID = @UsuarioId

        UNION ALL

        SELECT OperadorID, LocacionID
        FROM Transaccion
        WHERE UsuarioID = @UsuarioId
     ) AS src;

-------------------------------------------------------------
-- 1) Resumen de filas vinculadas directamente al Usuario
-------------------------------------------------------------
DECLARE @CntUsuario        INT = (SELECT COUNT(*) FROM Usuario        WHERE UsuarioID = @UsuarioId);
DECLARE @CntAspNet         INT = (SELECT COUNT(*) FROM AspNetUsers    WHERE UsuarioID = @UsuarioId);
DECLARE @CntTransaccion    INT = (SELECT COUNT(*) FROM Transaccion    WHERE UsuarioID = @UsuarioId);
DECLARE @CntStockHistorico INT = (SELECT COUNT(*) FROM StockHistorico WHERE UsuarioID = @UsuarioId);

PRINT '======= RESUMEN (por UsuarioId) ===============================';
PRINT '  Usuario          : ' + CAST(@CntUsuario        AS NVARCHAR(10)) + ' fila(s)';
PRINT '  AspNetUsers      : ' + CAST(@CntAspNet         AS NVARCHAR(10)) + ' fila(s)';
PRINT '  Transaccion      : ' + CAST(@CntTransaccion    AS NVARCHAR(10)) + ' fila(s)';
PRINT '  StockHistorico   : ' + CAST(@CntStockHistorico AS NVARCHAR(10)) + ' fila(s)';
PRINT '===============================================================';

IF (@CntUsuario = 0)
BEGIN
    PRINT '*** Atención: no se encontró ningún Usuario con ese UsuarioID.';
    PRINT '    (Si esto es DESPUÉS del borrado, es esperable; antes no debería pasar)';
END
ELSE
BEGIN
    PRINT '*** El Usuario existe actualmente en tabla Usuario.';
END

-------------------------------------------------------------
-- 2) Detalle por tabla (vinculadas por UsuarioID)
-------------------------------------------------------------

PRINT CHAR(13) + '--- Detalle: Usuario ----------------------------------------';
SELECT *
FROM Usuario
WHERE UsuarioID = @UsuarioId;

PRINT CHAR(13) + '--- Detalle: AspNetUsers (credenciales web) -----------------';
SELECT *
FROM AspNetUsers
WHERE UsuarioID = @UsuarioId;

PRINT CHAR(13) + '--- Detalle: Transaccion (primeras 20 por Usuario) ----------';
SELECT TOP 20 *
FROM Transaccion
WHERE UsuarioID = @UsuarioId
ORDER BY FechaTransaccion DESC;

PRINT CHAR(13) + '--- Detalle: StockHistorico (primeras 20 por Usuario) -------';
SELECT TOP 20 *
FROM StockHistorico
WHERE UsuarioID = @UsuarioId
ORDER BY Fecha DESC;

-------------------------------------------------------------
-- 3) Detalle de TransaccionesMal y MercadoPago
--    Se filtra por Operador/Locación cuando es posible.
-------------------------------------------------------------

DECLARE @CntTM INT,
        @CntMP INT;

SET @CntTM = (
    SELECT COUNT(*)
    FROM TransaccionesMal tm
    WHERE (@OperadorId IS NULL OR tm.OperadorID = @OperadorId)
      AND (@LocacionId IS NULL OR tm.LocacionID = @LocacionId)
);

SET @CntMP = (
    SELECT COUNT(*)
    FROM MercadoPagoTable mp
    WHERE (@OperadorId IS NULL OR mp.OperadorId = @OperadorId)
);

PRINT CHAR(13) + '--- Resumen: TransaccionesMal / MercadoPago ------------------';
PRINT '  OperadorId inferido : ' + ISNULL(CONVERT(NVARCHAR(36), @OperadorId), '(NULL)');
PRINT '  LocacionId inferida : ' + ISNULL(CONVERT(NVARCHAR(36), @LocacionId), '(NULL)');
PRINT '  TransaccionesMal     : ' + CAST(@CntTM AS NVARCHAR(10)) + ' fila(s)';
PRINT '  MercadoPagoTable     : ' + CAST(@CntMP AS NVARCHAR(10)) + ' fila(s)';

PRINT CHAR(13) + '--- Detalle: TransaccionesMal (según Operador/Locación) -----';
SELECT *
FROM TransaccionesMal tm
WHERE (@OperadorId IS NULL OR tm.OperadorID = @OperadorId)
  AND (@LocacionId IS NULL OR tm.LocacionID = @LocacionId)
ORDER BY tm.FechaDescarga;

PRINT CHAR(13) + '--- Detalle: MercadoPagoTable (según Operador) --------------';
SELECT *
FROM MercadoPagoTable mp
WHERE (@OperadorId IS NULL OR mp.OperadorId = @OperadorId)
ORDER BY mp.Fecha;
