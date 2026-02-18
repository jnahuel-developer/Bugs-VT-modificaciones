USE BugsDev;
GO

PRINT '=== BLOQUE 3: Borrando datos transaccionales y de stock ===';

-- 3.1 StockHistorico (depende de Stock y Usuario)
IF OBJECT_ID('dbo.StockHistorico', 'U') IS NOT NULL
BEGIN
    PRINT '> Borrando StockHistorico...';
    DELETE FROM StockHistorico;
    SELECT COUNT(*) AS StockHistoricoRestantes FROM StockHistorico;
END
ELSE
    PRINT '> Tabla StockHistorico no encontrada.';

-- 3.2 Stock
IF OBJECT_ID('dbo.Stock', 'U') IS NOT NULL
BEGIN
    PRINT '> Borrando Stock...';
    DELETE FROM Stock;
    SELECT COUNT(*) AS StockRestantes FROM Stock;
END
ELSE
    PRINT '> Tabla Stock no encontrada.';

-- 3.3 MercadoPagoTable
IF OBJECT_ID('dbo.MercadoPagoTable', 'U') IS NOT NULL
BEGIN
    PRINT '> Borrando MercadoPagoTable...';
    DELETE FROM MercadoPagoTable;
    SELECT COUNT(*) AS MercadoPagoRestantes FROM MercadoPagoTable;
END
ELSE
    PRINT '> Tabla MercadoPagoTable no encontrada.';

-- 3.3b MercadoPagoOperacionMixta
IF OBJECT_ID('dbo.MercadoPagoOperacionMixta', 'U') IS NOT NULL
BEGIN
    PRINT '> Borrando MercadoPagoOperacionMixta...';
    DELETE FROM MercadoPagoOperacionMixta;
    SELECT COUNT(*) AS MercadoPagoMixtaRestantes FROM MercadoPagoOperacionMixta;
END
ELSE
    PRINT '> Tabla MercadoPagoTable no encontrada.';

-- 3.4 TransaccionesMal
IF OBJECT_ID('dbo.TransaccionesMal', 'U') IS NOT NULL
BEGIN
    PRINT '> Borrando TransaccionesMal...';
    DELETE FROM TransaccionesMal;
    SELECT COUNT(*) AS TransaccionesMalRestantes FROM TransaccionesMal;
END
ELSE
    PRINT '> Tabla TransaccionesMal no encontrada.';

-- 3.5 Transaccion
IF OBJECT_ID('dbo.Transaccion', 'U') IS NOT NULL
BEGIN
    PRINT '> Borrando Transaccion...';
    DELETE FROM Transaccion;
    SELECT COUNT(*) AS TransaccionRestantes FROM Transaccion;
END
ELSE
    PRINT '> Tabla Transaccion no encontrada.';

PRINT '=== BLOQUE 3 completado ===';
GO
