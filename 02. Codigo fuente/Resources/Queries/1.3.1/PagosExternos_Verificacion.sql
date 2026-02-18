-- Pagos Externos - Verificación rápida
-- Ajustar nombres de tablas si difieren en el esquema (EF pluraliza por defecto).

-- Parámetros de ejemplo
DECLARE @OperadorId UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000';
DECLARE @Desde DATETIME = '2025-01-01T00:00:00';
DECLARE @Hasta DATETIME = '2025-01-31T23:59:59';

-- Conteo por rango y operador (con fallback a operador por máquina)
SELECT COUNT(*) AS total_registros
FROM dbo.MercadoPagoTable mp
LEFT JOIN dbo.Maquina m ON m.MaquinaID = mp.MaquinaId
WHERE mp.Fecha >= @Desde
  AND mp.Fecha <= @Hasta
  AND (
        mp.OperadorId = @OperadorId
        OR (mp.OperadorId IS NULL AND m.OperadorID = @OperadorId)
      );

-- Primeros 50 registros por fecha/id con joins
SELECT TOP (50)
    COALESCE(NULLIF(mp.Comprobante, ''), CAST(mp.MercadoPagoId AS VARCHAR(20))) AS comprobante,
    mp.Monto AS monto,
    mp.Fecha AS fecha,
    COALESCE(NULLIF(m.NombreAlias, ''), NULLIF(m.NumeroSerie, ''), CAST(m.MaquinaID AS VARCHAR(36))) AS maquina,
    m.NotasService AS id_caja,
    l.Nombre AS locacion,
    mp.MercadoPagoEstadoTransmisionId AS estadoTransmisionId,
    mp.MercadoPagoEstadoFinancieroId AS estadoFinancieroId
FROM dbo.MercadoPagoTable mp
LEFT JOIN dbo.Maquina m ON m.MaquinaID = mp.MaquinaId
LEFT JOIN dbo.Locacion l ON l.LocacionID = m.LocacionID
WHERE mp.Fecha >= @Desde
  AND mp.Fecha <= @Hasta
  AND (
        mp.OperadorId = @OperadorId
        OR (mp.OperadorId IS NULL AND m.OperadorID = @OperadorId)
      )
ORDER BY mp.Fecha, mp.MercadoPagoId;
