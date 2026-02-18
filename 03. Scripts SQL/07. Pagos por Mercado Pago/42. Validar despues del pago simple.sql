USE BugsDev;
GO

SELECT TOP (20)
    MercadoPagoId, Fecha, Monto, MaquinaId, OperadorId,
    MercadoPagoEstadoFinancieroId, MercadoPagoEstadoTransmisionId,
    Comprobante, Descripcion, UrlDevolucion
FROM dbo.MercadoPagoTable
WHERE Entidad = 'MP'
ORDER BY MercadoPagoId DESC;

-- (Opcional) Validar que NO haya generado operación mixta
SELECT COUNT(*) AS OperacionesMixtasParaEsteExternal
FROM dbo.MercadoPagoOperacionMixta

GO
