USE BugsDev;
GO

DECLARE @Comprobante NVARCHAR(50) = '2001';
DECLARE @ExternalReference NVARCHAR(200) = N'BGSQR_SIMPLE_01';

SELECT TOP (20)
    MercadoPagoId, Fecha, Monto, MaquinaId, OperadorId,
    MercadoPagoEstadoFinancieroId, MercadoPagoEstadoTransmisionId,
    Comprobante, Descripcion, UrlDevolucion
FROM dbo.MercadoPagoTable
WHERE Entidad = 'MP'
  AND (Comprobante = @Comprobante OR Descripcion = @ExternalReference)
ORDER BY MercadoPagoId DESC;

-- (Opcional) Validar que NO haya generado operación mixta
SELECT COUNT(*) AS OperacionesMixtasParaEsteExternal
FROM dbo.MercadoPagoOperacionMixta
WHERE ExternalReference = @ExternalReference;

GO
