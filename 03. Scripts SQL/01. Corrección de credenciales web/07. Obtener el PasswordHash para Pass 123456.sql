USE BugsDev;
GO

SELECT Email, PasswordHash
FROM AspNetUsers
WHERE Email = 'consumidor.a@test.com';
