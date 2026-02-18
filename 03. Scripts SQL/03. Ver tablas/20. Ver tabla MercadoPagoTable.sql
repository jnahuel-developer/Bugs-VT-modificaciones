USE BugsDev;
GO

SELECT TOP 200
    MercadoPagoId,
    Fecha,
    Monto,
    MaquinaId,
    OperadorId,
    MercadoPagoEstadoFinancieroId,
    MercadoPagoEstadoTransmisionId,
    Reintentos
FROM MercadoPagoTable
ORDER BY Fecha DESC;
