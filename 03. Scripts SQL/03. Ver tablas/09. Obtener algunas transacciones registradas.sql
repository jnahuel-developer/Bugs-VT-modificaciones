-- Ver algunas transacciones existentes
SELECT TOP 10 TransaccionID, LocacionID, UsuarioID, MaquinaID, TerminalID
FROM Transaccion
ORDER BY NEWID();
