# Pagos Externos - Autorización/Autenticación

## Mecanismo recomendado (API Key por Operador)

**Header obligatorio**

```
X-Api-Key: <SecretToken del Operador>
```

**Notas de seguridad**

- No enviar el token en querystring.
- El token se valida contra `Operador.SecretToken` y se compara en tiempo constante.
- El `OperadorId` resuelto queda disponible en `HttpContext.Items["OperadorId"]` para filtrar datos por operador.

## Ejemplo de uso (curl)

```
curl -X GET "https://tu-dominio/api/pagosexternos?desde=2025-01-01T00:00:00Z&hasta=2025-01-31T23:59:59Z&pagina=1" \
  -H "X-Api-Key: <secret-token-del-operador>" \
```

## Endpoint GET (Pagos Externos)

- URL: `/api/pagosexternos`
- Parámetros:
  - `desde` (obligatorio, ISO 8601)
  - `hasta` (obligatorio, ISO 8601)
  - `pagina` (opcional, por defecto 1, mínimo 1)

**Notas**

- El campo `id_caja` se toma de `Maquina.NotasService` asociado al pago (`MercadoPagoTable.MaquinaId`).

## Ejemplo de endpoint MVC protegido

```csharp
using BugsMVC.Security;
using System;
using System.Web.Mvc;

public class PagosExternosController : Controller
{
    [HttpGet]
    [ApiKeyAuthorize]
    public ActionResult Index(string desde, string hasta, int pagina = 1)
    {
        var operadorId = (Guid)HttpContext.Items[ApiKeyAuthorizeAttribute.OperadorIdItemKey];
        // Usar operadorId para filtrar datos.
        return Json(new { result = "OK" });
    }
}
```

## Códigos de respuesta esperados

- `401 Unauthorized` si falta el header o el token es inválido.
- `403 Forbidden` si el token es válido pero intenta operar sobre otro operador.
- `400 Bad Request` si los parámetros del endpoint son inválidos.
