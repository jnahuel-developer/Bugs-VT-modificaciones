USE BugsDev;
GO

SELECT 
    Id   AS RoleId,
    Name,
    [Weight]
FROM AspNetRoles
ORDER BY [Weight] DESC, Name;

SELECT 
    ur.UserId,
    u.Email,
    ur.RoleId,
    r.Name AS RoleName
FROM AspNetUserRoles ur
LEFT JOIN AspNetUsers u ON u.Id = ur.UserId
LEFT JOIN AspNetRoles r ON r.Id = ur.RoleId
ORDER BY u.Email, r.Name;
