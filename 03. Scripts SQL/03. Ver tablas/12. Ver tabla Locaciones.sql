USE BugsDev;
GO

SELECT 
    LocacionID,
    Nombre,
    Numero,
    CUIT,
    OperadorID
FROM Locacion
ORDER BY Nombre;
