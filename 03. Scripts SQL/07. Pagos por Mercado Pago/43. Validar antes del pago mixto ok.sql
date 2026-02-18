USE BugsDev;
GO

DECLARE @ExternalReference NVARCHAR(200) = N'BGSQR_05500';

-- Estado actual de pendientes/mixtas
SELECT TOP (50)
    MercadoPagoOperacionMixtaId, OperadorId, ExternalReference, FechaAuthorizedUtc,
    MontoAcumulado, ApprovedCount, PaymentId1, PaymentId2, Cerrada, FechaCierreUtc
FROM dbo.MercadoPagoOperacionMixta
WHERE ExternalReference = @ExternalReference
ORDER BY MercadoPagoOperacionMixtaId DESC;

-- Registros finales en MercadoPagoTable asociados al external_reference
SELECT TOP (50)
    MercadoPagoId, Fecha, Monto, MaquinaId, OperadorId,
    MercadoPagoEstadoFinancieroId, MercadoPagoEstadoTransmisionId,
    Comprobante, Descripcion, UrlDevolucion
FROM dbo.MercadoPagoTable
WHERE Entidad = 'MP'
  AND (Descripcion = @ExternalReference OR Comprobante = @ExternalReference)
ORDER BY MercadoPagoId DESC;

GO
