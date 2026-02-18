USE BugsDev;
GO

SELECT TOP (200)
    MercadoPagoOperacionMixtaId,
    OperadorId,
    ExternalReference,
    FechaAuthorizedUtc,
    MontoAcumulado,
    ApprovedCount,
    PaymentId1,
    PaymentId2,
    Cerrada,
    FechaCierreUtc,
    FechaUltimaActualizacionUtc
FROM dbo.MercadoPagoOperacionMixta
ORDER BY MercadoPagoOperacionMixtaId DESC;

GO
