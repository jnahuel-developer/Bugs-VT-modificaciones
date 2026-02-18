USE BugsDev;
GO

DECLARE @ExternalReference NVARCHAR(200) = N'BGSQR_05500';

-- Operación mixta debería quedar cerrada y con ApprovedCount=2, MontoAcumulado=430.00
SELECT TOP (10)
    MercadoPagoOperacionMixtaId, OperadorId, ExternalReference, FechaAuthorizedUtc,
    MontoAcumulado, ApprovedCount, PaymentId1, PaymentId2, Cerrada, FechaCierreUtc,
    FechaUltimaActualizacionUtc
FROM dbo.MercadoPagoOperacionMixta
WHERE ExternalReference = @ExternalReference
ORDER BY MercadoPagoOperacionMixtaId DESC;

-- Debe existir 1 registro final consolidado (Descripcion = external_reference)
SELECT TOP (20)
    MercadoPagoId, Fecha, Monto, MaquinaId, OperadorId,
    MercadoPagoEstadoFinancieroId, MercadoPagoEstadoTransmisionId,
    Comprobante, Descripcion, UrlDevolucion
FROM dbo.MercadoPagoTable
WHERE Entidad = 'MP'
  AND (Descripcion = @ExternalReference OR Comprobante = @ExternalReference)
ORDER BY MercadoPagoId DESC;

GO
