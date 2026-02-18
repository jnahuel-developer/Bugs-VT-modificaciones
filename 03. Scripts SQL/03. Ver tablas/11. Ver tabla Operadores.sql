USE BugsDev;
GO

SELECT 
    OperadorID,
    Numero,
    Nombre,
    TiempoAvisoInhibicion,
    TiempoAvisoConexion,
    SecretToken,
    AccessToken
FROM Operador
ORDER BY Numero;
