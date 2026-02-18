USE BugsDev;
GO

DECLARE @Comprobante NVARCHAR(50) = '2001';
DECLARE @ExternalReference NVARCHAR(200) = N'BGSQR_SIMPLE_01';

SELECT 
    COUNT(*) AS Cantidad,
    MIN(Fecha) AS MinFecha,
    MAX(Fecha) AS MaxFecha
FROM dbo.MercadoPagoTable
WHERE Entidad = 'MP'
  AND (Comprobante = @Comprobante OR Descripcion = @ExternalReference);

SELECT TOP (50)
    MercadoPagoId, Fecha, Monto, MaquinaId, OperadorId,
    MercadoPagoEstadoFinancieroId, MercadoPagoEstadoTransmisionId,
    Comprobante, Descripcion, UrlDevolucion
FROM dbo.MercadoPagoTable
WHERE Entidad = 'MP'
  AND (Comprobante = @Comprobante OR Descripcion = @ExternalReference)
ORDER BY MercadoPagoId DESC;

GO
