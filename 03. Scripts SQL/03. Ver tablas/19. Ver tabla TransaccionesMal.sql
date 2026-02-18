USE BugsDev;
GO

SELECT TOP 200
    IdTransaccionMal,
    FechaDescarga,
    Motivo,
    LocacionID,
    OperadorID,
    MaquinaID,
    TerminalID
FROM TransaccionesMal
ORDER BY FechaDescarga DESC;
