USE BugsDev;
GO

SELECT TOP 200
    TransaccionID,
    FechaTransaccion,
    CodigoTransaccion,
    ValorVenta,
    ValorRecarga,
    UsuarioID,
    LocacionID,
    OperadorID,
    MaquinaID,
    TerminalID,
    JerarquiaID
FROM Transaccion
ORDER BY FechaTransaccion DESC;
