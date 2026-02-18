USE BugsDev;
GO

SELECT TOP 200
    StockID,
    Cantidad,
    ArticuloAsignacionID,
    UsuarioIDEdicionWeb,
    FechaAviso,
    FechaEdicionWeb,
    FechaEdicionVT
FROM Stock
ORDER BY StockID;

SELECT TOP 200
    StockHistoricoID,
    StockID,
    TipoDeMovimientoID,
    Fecha,
    UsuarioID,
    Cantidad,
    FechaAviso
FROM StockHistorico
ORDER BY Fecha DESC;
