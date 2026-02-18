using BugsMVC.DAL;
using BugsMVC.Security;
using System;
using System.Globalization;
using System.Linq;
using System.Net;
using System.Web;
using System.Web.Mvc;

namespace BugsMVC.Controllers
{
    public class PagosExternosController : Controller
    {
        private const int PageSize = 50;
        private readonly BugsContext db = new BugsContext();

        [HttpGet]
        [ApiKeyAuthorize]
        public ActionResult Index(string desde, string hasta, int pagina = 1)
        {
            Response.Cache.SetCacheability(HttpCacheability.NoCache);
            Response.Cache.SetNoStore();

            if (string.IsNullOrWhiteSpace(desde) || string.IsNullOrWhiteSpace(hasta))
            {
                return new HttpStatusCodeResult(HttpStatusCode.BadRequest, "Parametros 'desde' y 'hasta' requeridos.");
            }

            if (pagina < 1)
            {
                return new HttpStatusCodeResult(HttpStatusCode.BadRequest, "El parametro 'pagina' debe ser mayor o igual a 1.");
            }

            if (!DateTimeOffset.TryParse(desde, CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind, out DateTimeOffset desdeDto))
            {
                return new HttpStatusCodeResult(HttpStatusCode.BadRequest, "Formato invalido para 'desde'.");
            }

            if (!DateTimeOffset.TryParse(hasta, CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind, out DateTimeOffset hastaDto))
            {
                return new HttpStatusCodeResult(HttpStatusCode.BadRequest, "Formato invalido para 'hasta'.");
            }

            DateTime desdeUtc = DateTime.SpecifyKind(desdeDto.UtcDateTime, DateTimeKind.Utc);
            DateTime hastaUtc = DateTime.SpecifyKind(hastaDto.UtcDateTime, DateTimeKind.Utc);

            if (desdeUtc > hastaUtc)
            {
                return new HttpStatusCodeResult(HttpStatusCode.BadRequest, "'desde' no puede ser mayor que 'hasta'.");
            }

            Guid operadorId = (Guid)HttpContext.Items[ApiKeyAuthorizeAttribute.OperadorIdItemKey];

            var filteredQuery = db.MercadoPagoTable
                .AsNoTracking()
                .Where(x => x.Fecha >= desdeUtc && x.Fecha <= hastaUtc)
                .Where(x => x.OperadorId == operadorId ||
                            (x.OperadorId == null && x.Maquina != null && x.Maquina.OperadorID == operadorId))
                .Where(x => x.MercadoPagoEstadoFinancieroId == (int)Models.MercadoPagoEstadoFinanciero.States.ACREDITADO
                            && x.MercadoPagoEstadoTransmisionId == (int)Models.MercadoPagoEstadoTransmision.States.TERMINADO_OK);

            int totalRegistros = filteredQuery.Count();
            int totalPaginas = (int)Math.Ceiling(totalRegistros / (double)PageSize);
            int skip = (pagina - 1) * PageSize;

            var datosRaw = filteredQuery
                .OrderBy(x => x.Fecha)
                .ThenBy(x => x.MercadoPagoId)
                .Skip(skip)
                .Take(PageSize)
                .Select(x => new
                {
                    x.Comprobante,
                    x.MercadoPagoId,
                    x.Monto,
                    x.Fecha,
                    MaquinaNombreAlias = x.Maquina != null ? x.Maquina.NombreAlias : null,
                    MaquinaNumeroSerie = x.Maquina != null ? x.Maquina.NumeroSerie : null,
                    MaquinaId = x.Maquina != null ? (Guid?)x.Maquina.MaquinaID : null,
                    IdCaja = x.Maquina.NotasService,
                    LocacionNombre = x.Maquina != null && x.Maquina.Locacion != null ? x.Maquina.Locacion.Nombre : null,
                    EstadoTransmisionDescripcion = x.MercadoPagoEstadoTransmision != null
                        ? x.MercadoPagoEstadoTransmision.Descripcion
                        : null,
                    x.MercadoPagoEstadoTransmisionId,
                    EstadoFinancieroDescripcion = x.MercadoPagoEstadoFinanciero != null
                        ? x.MercadoPagoEstadoFinanciero.Descripcion
                        : null,
                    x.MercadoPagoEstadoFinancieroId
                })
                .ToList();

            var datos = datosRaw.Select(x => new
            {
                comprobante = string.IsNullOrWhiteSpace(x.Comprobante)
                    ? x.MercadoPagoId.ToString(CultureInfo.InvariantCulture)
                    : x.Comprobante,
                monto = x.Monto,
                fecha = DateTime.SpecifyKind(x.Fecha, DateTimeKind.Utc).ToString("o", CultureInfo.InvariantCulture),
                maquina = !string.IsNullOrWhiteSpace(x.MaquinaNombreAlias)
                    ? x.MaquinaNombreAlias
                    : !string.IsNullOrWhiteSpace(x.MaquinaNumeroSerie)
                        ? x.MaquinaNumeroSerie
                        : x.MaquinaId?.ToString(),
                id_caja = x.IdCaja,
                locacion = x.LocacionNombre,
                estadoTransmision = x.EstadoTransmisionDescripcion ?? x.MercadoPagoEstadoTransmisionId.ToString(),
                estadoFinanciero = x.EstadoFinancieroDescripcion ?? x.MercadoPagoEstadoFinancieroId.ToString()
            }).ToList();

            return Json(new
            {
                total_registros = totalRegistros,
                pagina_actual = pagina,
                total_paginas = totalPaginas,
                datos
            }, JsonRequestBehavior.AllowGet);
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                db.Dispose();
            }

            base.Dispose(disposing);
        }
    }
}
