using BugsMVC.DAL;
using BugsMVC.Helpers;
using BugsMVC.Models;
using MercadoPago.Config;
using MercadoPago.Resource.Payment;
using Microsoft.AspNet.Identity.Owin;
using System;
using System.Configuration;
using System.Data.Entity;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Web;
using System.Web.Mvc;
using static BugsMVC.Controllers.PagosClienteController;
using MercadoPago.Client.Payment;
using MercadoPago.Error;
using Newtonsoft.Json;

namespace BugsMVC.Controllers
{
    /// <summary>
    /// Controlador para la recepción y procesamiento de notificaciones de pagos de MercadoPago.
    /// </summary>
    public class PagosMPController : BaseController
    {
        private static readonly log4net.ILog Log =
            log4net.LogManager.GetLogger(System.Reflection.MethodBase.GetCurrentMethod().DeclaringType);
        private string ip
        {
            get
            {
                var str = ConfigurationManager.AppSettings["IP"];
                return !string.IsNullOrEmpty(str) ? str : "127.0.0.1";
            }
        }

        private string puerto
        {
            get
            {
                var str = ConfigurationManager.AppSettings["Puerto"];
                return !string.IsNullOrEmpty(str) ? str : "13000";
            }
        }

        private int tiempoEspera
        {
            get
            {
                var str = ConfigurationManager.AppSettings["TiempoIntentoSegundos"];
                if (!string.IsNullOrEmpty(str) && int.TryParse(str, out int val) && val > 0)
                    return val * 1000;
                return 10000; // 10 segundos por defecto
            }
        }

        private int limiteIntentos
        {
            get
            {
                var str = ConfigurationManager.AppSettings["LimiteReintentos"];
                if (!string.IsNullOrEmpty(str) && int.TryParse(str, out int val) && val > 0)
                    return val;
                return 3; // 3 intentos por defecto
            }
        }

        private bool isTiempoLineal
        {
            get
            {
                var str = ConfigurationManager.AppSettings["IsTiempoLineal"];
                if (!string.IsNullOrEmpty(str) && bool.TryParse(str, out bool val))
                    return val;
                return false; // false por defecto
            }
        }
        private static readonly SemaphoreSlim PagoSemaphore = new SemaphoreSlim(1, 1);

        private readonly string MAQUINA_NULA = "99999";
        private readonly int OPERADOR_NULO = 99999;
        private static readonly TimeSpan VentanaPagoMixto = TimeSpan.FromSeconds(15);

        private ApplicationUserManager _userManager;
        public ApplicationUserManager UserManager
        {
            get
            {
                return _userManager ?? HttpContext.GetOwinContext().GetUserManager<ApplicationUserManager>();
            }
            private set
            {
                _userManager = value;
            }
        }

        /// <summary>
        /// Endpoint HTTP POST que recibe notificaciones de MercadoPago y dispara el procesamiento del pago en un hilo separado.
        /// </summary>
        /// <param name="operador">ID del operador asociado al pago.</param>
        /// <param name="topic">Tipo de notificación recibida (debe ser "payment").</param>
        /// <param name="id">ID del comprobante de pago de MercadoPago.</param>
        /// <returns>Respuesta JSON indicando el resultado.</returns>
        [HttpPost]
        [AllowAnonymous]
        public async Task<ActionResult> Index(long? operador, string topic, long id)
        {
            _userManager = Request.GetOwinContext().GetUserManager<ApplicationUserManager>();

            //Esto no se ejecuta de forma asíncrona, ya que necesitamos retornar el OK a MP para que no continúe enviando notificaciones.
            Task.Run(() => RegistrarPago(topic, id, operador));

            return Json(new { result = "OK" }, JsonRequestBehavior.AllowGet);

        }

        /// <summary>
        /// Procesa una notificación de pago de MercadoPago: valida el operador, obtiene el pago, verifica duplicados y registra el pago.
        /// </summary>
        /// <param name="topic">Tipo de notificación (debe ser "payment").</param>
        /// <param name="idComprobante">ID del comprobante de MercadoPago.</param>
        /// <param name="numeroOperador">Número del operador asociado.</param>
        public async Task RegistrarPago(string topic, long idComprobante, long? numeroOperador)
        {
            try
            {                
                using (var bugsDbContext = new BugsContext())
                {

                    #region Control Operador
                    //Salida, el numero de operador es nulo
                    if (numeroOperador == null)
                    {
                        Operador opNulo = await bugsDbContext.Operadores.FirstOrDefaultAsync(o => o.Numero == OPERADOR_NULO);
                        string mensajeDescripcion = "El id de operador es nulo.";

                        Log.Info($"[{idComprobante}] - No existe el operador número: {numeroOperador}");
                        //En este caso se debe guardar el operador nulo, ya que no existe uno. Lo mismo para la máquina, no podemos obtener el dato si no tenemos el operador.
                        await GuardarNoProcesable(bugsDbContext, idComprobante, mensajeDescripcion, opNulo);
                        return;
                    }

                    Operador operador = await bugsDbContext.Operadores.FirstOrDefaultAsync(o => o.Numero == numeroOperador);

                    //Salida, el operador es nulo
                    if (operador == null)
                    {
                        Operador opNulo = await bugsDbContext.Operadores.FirstOrDefaultAsync(o => o.Numero == OPERADOR_NULO);
                        string mensajeDescripcion = $"El operador {numeroOperador} no existe en la DB.";

                        Log.Info($"[{idComprobante}] - {mensajeDescripcion}");
                        await GuardarNoProcesable(bugsDbContext, idComprobante, mensajeDescripcion, opNulo);
                        return;
                    }

                    string accessToken = operador.AccessToken;

                    //Salida, el operador no tiene accessToken (Reemplaza logica anterior de clientId y secretToken)
                    if (accessToken == null)
                    {
                        string mensajeDescripcion = $"El access token del operador número: {numeroOperador} no está registrado.";

                        Log.Info($"[{idComprobante}] - {mensajeDescripcion}");
                        await GuardarNoProcesable(bugsDbContext, idComprobante, mensajeDescripcion, operador);

                        return;
                    }

                    #endregion

                    MercadoPagoConfig.AccessToken = null;
                    MercadoPagoConfig.AccessToken = accessToken;

                    if (MercadoPagoConfig.AccessToken != null)
                    {
                        if (PagosMixtosConfigHelper.PagosMixtosHabilitados)
                        {
                            await ProcesarPendientesMixtosExpirados(bugsDbContext, operador);
                        }

                        string version = ConfigurationManager.AppSettings["AppVersion"];

                        Log.Info($"Llega notificacion de pago al sistema: topic= {topic}, id= {idComprobante}, operador={numeroOperador}, version={version}");

                        if (topic != "payment")
                            return;

                        if (await bugsDbContext.MercadoPagoTable.FirstOrDefaultAsync((e) => e.Comprobante == idComprobante.ToString() && e.Entidad == "MP") != null)
                        {
                            Log.Info($"[{idComprobante}] - La notificación ya fue recibida y procesada anteriormente");
                            return;
                        }

                        decimal monto = 0;
                        Guid maquinaId = Guid.Empty;

                        Payment payment = new Payment();
                        string paymentStatus = string.Empty;
                        decimal? paymentTransactionAmount = null;
                        string paymentExternalReference = null;
                        string paymentCurrencyId = null;
                        string paymentMethodId = null;
                        try
                        {
                            //El semaphore limita a 1 el número de hilos que pueden acceder a este método al mismo tiempo. Es un FIFO.
                            //Esto DEBERIA evitar que se encimen lso pagos y que rompan contra la api de MP, que es un caso que está ocurriendo.
                            //Lo que se tiene que tener en cuenta es que si la fila es muy larga, va a alargarse el proceso...
                            Log.Info($"[{idComprobante}] - Esperando turno en la fila para obtener payment...");
                            await PagoSemaphore.WaitAsync();
                            try
                            {
                                Log.Info($"[{idComprobante}] - Intentando obtener información de payment...");

                                if (AmbienteConfigHelper.AmbienteSimuladoresHabilitado)
                                {
                                    Log.Info($"[{idComprobante}] - Se consultará el payment en mp_simulator.");
                                    MpSimPaymentDto paymentSimulador = await ConsultarPaymentEnSimulador(idComprobante);
                                    paymentStatus = paymentSimulador.status;
                                    paymentTransactionAmount = paymentSimulador.transaction_amount;
                                    paymentExternalReference = paymentSimulador.external_reference;
                                    paymentCurrencyId = paymentSimulador.currency_id;
                                    paymentMethodId = paymentSimulador.payment_method_id;
                                }
                                else
                                {
                                    //Intentamos obtener la información del payment utilizando el cliente nuevo
                                    PaymentClient paymentClient = new PaymentClient();
                                    payment = paymentClient.Get(idComprobante);
                                    paymentStatus = payment.Status?.ToString();
                                    paymentTransactionAmount = payment.TransactionAmount;
                                    paymentExternalReference = payment.ExternalReference;
                                    paymentCurrencyId = payment.CurrencyId;
                                    paymentMethodId = payment.PaymentMethodId;
                                }
                            }
                            finally
                            {
                                PagoSemaphore.Release();
                                Log.Info($"[{idComprobante}] - finalizada fila de payment.");
                            }
                        }
                        catch (MercadoPagoApiException ex)
                        {
                            // Maneja los errores de la API de MercadoPago
                            Log.Error($"[{idComprobante}] - Se produjo un error con la API de Mercado Pago.");
                            Log.Error($"Error: {ex.Message}");
                            Log.Error($"Status Code: {ex.StatusCode}");
                            Log.Error($"Error de API: {ex.ApiError}");
                            Log.Error($"Respuesta de API: {ex.ApiResponse}");

                            string mensajeDescripcion = $"Pago no encontrado - {idComprobante}";

                            await GuardarNoProcesable(bugsDbContext, idComprobante, mensajeDescripcion, operador);

                            return;
                        }
                        catch (Exception e)
                        {
                            //Salida, se agrega este caso para cuando se produce un error al buscar el payment, como en casos donde no se autorizan las credenciales de mercado pago.
                            string mensajeDescripcion = $"Se produjo un error al buscar el payment: {idComprobante}";
                            Log.Error($"[{idComprobante}] - {mensajeDescripcion}  - {e}");

                            await GuardarNoProcesable(bugsDbContext, idComprobante, mensajeDescripcion, operador);
                            return;
                        }

                        Log.Info($"[{idComprobante}] - El pago fue encontrado y se encuentra procesando los datos");

                        if (EsEstadoPago(paymentStatus, PaymentStatus.Authorized.ToString()))
                        {
                            Log.Error($"[{idComprobante}] - Mercado Pago status: {paymentStatus}");

                            monto = paymentTransactionAmount ?? 0;

                            /*Log.Info("External Reference:" + paymentExternalReference + "
                             Sergio Abril 2024 */
                            Log.Info($"[{idComprobante}] - External Reference: " + paymentExternalReference + ",Monto:" + monto);
                            Log.Info($"[{idComprobante}] - CurrencyId: " + paymentCurrencyId);
                            //Log.Info("Date Aproved: " + payment.DateApproved);
                            Log.Info($"[{idComprobante}] - Payment Method: " + paymentMethodId);
                            //Log.Info("Colector ID: " + payment.CollectorId);
                            //Log.Info("Issuer ID: " + payment.IssuerId);

                            if (string.IsNullOrWhiteSpace(paymentExternalReference))
                            {
                                string mensajeDescripcion = "External Reference es nulo o vacío en pago autorizado.";
                                Log.Error($"[{idComprobante}] - {mensajeDescripcion}");
                                await GuardarNoProcesable(bugsDbContext, idComprobante, mensajeDescripcion, operador, monto);
                                return;
                            }

                            if (!PagosMixtosConfigHelper.PagosMixtosHabilitados)
                            {
                                Log.Info($"[{idComprobante}] - Se recibió un pago con estado Authorized y el modo de pagos mixtos se encuentra en OFF. El evento será descartado sin persistencia.");
                                return;
                            }

                            await RegistrarPagoMixtoAutorizado(bugsDbContext, operador, paymentExternalReference);
                            return;
                        }



                        if (EsEstadoPago(paymentStatus, PaymentStatus.Approved.ToString()))
                        {
                            monto = paymentTransactionAmount ?? 0;

                            /*Log.Info("External Reference:" + paymentExternalReference + "
                             Sergio Abril 2024 */
                            Log.Info($"[{idComprobante}] - External Reference: " + paymentExternalReference + ",Monto:" + monto);
                            Log.Info($"[{idComprobante}] - CurrencyId: " + paymentCurrencyId);
                            //Log.Info("Date Aproved: " + payment.DateApproved);
                            Log.Info($"[{idComprobante}] - Payment Method: " + paymentMethodId);
                            //Log.Info("Colector ID: " + payment.CollectorId);
                            //Log.Info("Issuer ID: " + payment.IssuerId);

                            //External Reference de Payment
                            if (paymentExternalReference != null)
                            {
                                Log.Info($"[{idComprobante}] - External Reference Actualizado: {paymentExternalReference} para el operador: {operador.Nombre}");

                                if (PagosMixtosConfigHelper.PagosMixtosHabilitados)
                                {
                                    if (await PagoMixtoYaProcesado(bugsDbContext, operador, idComprobante))
                                    {
                                        Log.Info($"[{idComprobante}] - Payment ya procesado para operación mixta, descartando duplicado.");
                                        return;
                                    }

                                    var operacionMixta = await ObtenerOperacionMixtaPendiente(bugsDbContext, operador, paymentExternalReference);
                                    if (operacionMixta != null)
                                    {
                                        if (OperacionMixtaExpirada(operacionMixta))
                                        {
                                            await CerrarPagoMixtoInconsistente(bugsDbContext, operacionMixta, operador);
                                            return;
                                        }

                                        if (operacionMixta.PaymentId1 == idComprobante || operacionMixta.PaymentId2 == idComprobante)
                                        {
                                            Log.Info($"[{idComprobante}] - Payment repetido en operación mixta pendiente, descartando.");
                                            return;
                                        }

                                        operacionMixta.MontoAcumulado += monto;
                                        operacionMixta.ApprovedCount += 1;
                                        operacionMixta.FechaUltimaActualizacionUtc = DateTime.UtcNow;

                                        if (operacionMixta.PaymentId1 == null)
                                        {
                                            operacionMixta.PaymentId1 = idComprobante;
                                        }
                                        else if (operacionMixta.PaymentId2 == null)
                                        {
                                            operacionMixta.PaymentId2 = idComprobante;
                                        }

                                        if (!OperacionMixtaTieneDosPatasRegistradas(operacionMixta))
                                        {
                                            bugsDbContext.Entry(operacionMixta).State = EntityState.Modified;
                                            await bugsDbContext.SaveChangesAsync();
                                            return;
                                        }

                                        if (!OperacionMixtaValidaParaEnvioMaquina(operacionMixta))
                                        {
                                            await CerrarPagoMixtoRechazadoOCancelado(bugsDbContext, operacionMixta, operador);
                                            return;
                                        }

                                        Maquina maquinaMixta = await ObtenerMaquinaPorExternalReference(bugsDbContext, paymentExternalReference, operador, idComprobante, monto);
                                        if (maquinaMixta == null)
                                        {
                                            return;
                                        }

                                        var paymentEntity = new MercadoPagoTable
                                        {
                                            Fecha = DateTime.Now,
                                            Monto = operacionMixta.MontoAcumulado,
                                            MercadoPagoEstadoFinancieroId = (int)MercadoPagoEstadoFinanciero.States.ACREDITADO,
                                            MercadoPagoEstadoTransmisionId = (int)MercadoPagoEstadoTransmision.States.EN_PROCESO,
                                            Maquina = maquinaMixta,
                                            FechaModificacionEstadoTransmision = null,
                                            Comprobante = idComprobante.ToString(),
                                            Entidad = "MP",
                                            Operador = operador,
                                        };

                                        try
                                        {
                                            bugsDbContext.MercadoPagoTable.Add(paymentEntity);
                                            operacionMixta.Cerrada = true;
                                            operacionMixta.FechaCierreUtc = DateTime.UtcNow;
                                            operacionMixta.FechaUltimaActualizacionUtc = DateTime.UtcNow;
                                            await bugsDbContext.SaveChangesAsync();
                                            await EnviarPagoAMaquina(bugsDbContext, paymentEntity);
                                        }
                                        catch (System.Data.Entity.Infrastructure.DbUpdateException ex)
                                        {
                                            var existente = await bugsDbContext.MercadoPagoTable
                                                .FirstOrDefaultAsync(e => e.Comprobante == paymentEntity.Comprobante && e.Entidad == paymentEntity.Entidad);

                                            if (existente != null)
                                            {
                                                Log.Info($"[{idComprobante}] - Intento de inserción duplicada para Comprobante: {paymentEntity.Comprobante}. Ya existe con ID: {existente.MercadoPagoId}");
                                            }
                                            else
                                            {
                                                Log.Warn($"[{idComprobante}] - Intento de inserción duplicada para Comprobante: {paymentEntity.Comprobante}, pero no se encontró el registro existente.");
                                            }
                                        }

                                        return;
                                    }
                                }

                                Maquina maquina = await ObtenerMaquinaPorExternalReference(bugsDbContext, paymentExternalReference, operador, idComprobante, monto);
                                if (maquina == null)
                                {
                                    return;
                                }

                                var paymentEntityNormal = new MercadoPagoTable
                                {
                                    Fecha = DateTime.Now,
                                    Monto = monto,
                                    MercadoPagoEstadoFinancieroId = (int)MercadoPagoEstadoFinanciero.States.ACREDITADO,
                                    MercadoPagoEstadoTransmisionId = (int)MercadoPagoEstadoTransmision.States.EN_PROCESO,
                                    Maquina = maquina,
                                    FechaModificacionEstadoTransmision = null,
                                    Comprobante = idComprobante.ToString(),
                                    Entidad = "MP",
                                    Operador = operador,
                                };

                                try
                                {
                                    bugsDbContext.MercadoPagoTable.Add(paymentEntityNormal);
                                    await bugsDbContext.SaveChangesAsync();
                                    await EnviarPagoAMaquina(bugsDbContext, paymentEntityNormal);
                                }
                                catch (System.Data.Entity.Infrastructure.DbUpdateException ex)
                                {
                                    var existente = await bugsDbContext.MercadoPagoTable
                                        .FirstOrDefaultAsync(e => e.Comprobante == paymentEntityNormal.Comprobante && e.Entidad == paymentEntityNormal.Entidad);

                                    if (existente != null)
                                    {
                                        Log.Info($"[{idComprobante}] - Intento de inserción duplicada para Comprobante: {paymentEntityNormal.Comprobante}. Ya existe con ID: {existente.MercadoPagoId}");
                                    }
                                    else
                                    {
                                        Log.Warn($"[{idComprobante}] - Intento de inserción duplicada para Comprobante: {paymentEntityNormal.Comprobante}, pero no se encontró el registro existente.");
                                    }
                                }

                                return;
                            }
                            else
                            {
                                string mensajeDescripcion = "External Reference es nulo.";
                                Log.Info($"[{idComprobante}] - {mensajeDescripcion}");
                                await GuardarNoProcesable(bugsDbContext, idComprobante, mensajeDescripcion, operador, monto);
                            }
                            return;
                        }
                        else if (EsEstadoPago(paymentStatus, "rejected") || EsEstadoPago(paymentStatus, "cancelled"))
                        {
                            Log.Info($"[{idComprobante}] - Mercado Pago status: {paymentStatus}");

                            if (string.IsNullOrWhiteSpace(paymentExternalReference) || !PagosMixtosConfigHelper.PagosMixtosHabilitados)
                            {
                                return;
                            }

                            var operacionMixta = await ObtenerOperacionMixtaPendiente(bugsDbContext, operador, paymentExternalReference);
                            if (operacionMixta == null)
                            {
                                return;
                            }

                            if (OperacionMixtaExpirada(operacionMixta))
                            {
                                await CerrarPagoMixtoInconsistente(bugsDbContext, operacionMixta, operador);
                                return;
                            }

                            if (operacionMixta.ApprovedCount == 0 &&
                                ((operacionMixta.PaymentId1 == 0 && !operacionMixta.PaymentId2.HasValue) ||
                                 (operacionMixta.PaymentId2 == 0 && !operacionMixta.PaymentId1.HasValue)))
                            {
                                Log.Info($"[{idComprobante}] - Operación mixta ya tiene una pata rechazada/cancelada registrada en 0 y sin aprobados. Se ignora el evento para evitar cierre prematuro. ExternalReference={paymentExternalReference}, MercadoPagoOperacionMixtaId={operacionMixta.MercadoPagoOperacionMixtaId}.");
                                return;
                            }

                            string paymentIdCampoActualizado = null;
                            if (!operacionMixta.PaymentId1.HasValue)
                            {
                                operacionMixta.PaymentId1 = 0;
                                paymentIdCampoActualizado = nameof(operacionMixta.PaymentId1);
                            }
                            else if (!operacionMixta.PaymentId2.HasValue)
                            {
                                operacionMixta.PaymentId2 = 0;
                                paymentIdCampoActualizado = nameof(operacionMixta.PaymentId2);
                            }

                            operacionMixta.FechaUltimaActualizacionUtc = DateTime.UtcNow;

                            if (paymentIdCampoActualizado != null)
                            {
                                Log.Info($"[{idComprobante}] - Registrando pata rechazada/cancelada en 0. ExternalReference={paymentExternalReference}, MercadoPagoOperacionMixtaId={operacionMixta.MercadoPagoOperacionMixtaId}, CampoActualizado={paymentIdCampoActualizado}.");
                            }

                            if (!OperacionMixtaTieneDosPatasRegistradas(operacionMixta))
                            {
                                bugsDbContext.Entry(operacionMixta).State = EntityState.Modified;
                                await bugsDbContext.SaveChangesAsync();
                                return;
                            }

                            await CerrarPagoMixtoRechazadoOCancelado(bugsDbContext, operacionMixta, operador);
                            return;
                        }
                        else
                        {
                            Log.Error($"[{idComprobante}] - Mercado Pago status: {paymentStatus}");
                            return;
                        }
                    }
                    else
                    {
                        string mensajeDescripcion = $"El token de acceso de Mercado Pago es nulo o no está configurado correctamente para el operador {operador.OperadorID}.";
                        Log.Error($"[{idComprobante}] - {mensajeDescripcion}");
                        await GuardarNoProcesable(bugsDbContext, idComprobante, mensajeDescripcion, operador);
                        return;
                    }
                }
            }
            catch (Exception ex)
            {
                string mensajeDescripcion = $"Error inesperado en RegistrarPago para idComprobante={idComprobante}, operador={numeroOperador}";
                Log.Error($"[{idComprobante}] - {mensajeDescripcion}", ex);
            }
            finally
            {
                Log.Info($"[{idComprobante}] - Finalizó el proceso de RegistrarPago.");
            }
        }


        /// <summary>
        /// Envía la información del pago a la máquina correspondiente a través de un socket TCP.
        /// Actualiza el estado del pago en caso de error o reintentos fallidos.
        /// </summary>
        /// <param name="bugsDbContext">Contexto de base de datos a utilizar.</param>
        /// <param name="mercadoPago">Entidad de pago de MercadoPago a enviar.</param> 
        private async Task EnviarPagoAMaquina(BugsContext bugsDbContext, MercadoPagoTable mercadoPago)
        {
            int intentos = 0;
            int tiempoSleep = 0;
            bool volverAintentar = true;
            string mensaje =
                '$' + mercadoPago.MercadoPagoId.ToString()
                + ',' + mercadoPago.MaquinaId.ToString() + ','
                + ((long)Math.Round(mercadoPago.Monto * 100, 0, MidpointRounding.AwayFromZero)).ToString() + '!';

            string destinoIp = AmbienteConfigHelper.AmbienteSimuladoresHabilitado ? "127.0.0.1" : ip;
            int destinoPuerto = AmbienteConfigHelper.AmbienteSimuladoresHabilitado ? 13000 : Convert.ToInt32(puerto);

            Log.Info($"[{mercadoPago.Comprobante}] - Enviando pago a máquina...");

            if (AmbienteConfigHelper.AmbienteSimuladoresHabilitado)
            {
                Log.Info($"Se utilizará el destino de simulador para el envío a máquina ({destinoIp}:{destinoPuerto}).");
            }
            else
            {
                Log.Info($"Se utilizará el destino configurado para el envío a máquina ({destinoIp}:{destinoPuerto}).");
            }

            while (intentos < limiteIntentos && volverAintentar)
            {
                try
                {
                    Log.Info($"[{mercadoPago.Comprobante}] - Intento {intentos + 1} de {limiteIntentos} para enviar pago a máquina {mercadoPago.MaquinaId}");

                    int timeoutMs = 30000; // 30 segundos de timeout por intento

                    TcpClient tcpclnt = new TcpClient();

                    var connectTask = tcpclnt.ConnectAsync(destinoIp, destinoPuerto);
                    if (!connectTask.Wait(timeoutMs))
                    {
                        tcpclnt.Close();
                        throw new TimeoutException($"[{mercadoPago.Comprobante}] - Timeout al intentar conectar con la máquina en {destinoIp}:{destinoPuerto} (timeout={timeoutMs}ms)");
                    }

                    Stream stm = tcpclnt.GetStream();

                    ASCIIEncoding asen = new ASCIIEncoding();
                    byte[] ba = asen.GetBytes(mensaje);

                    stm.Write(ba, 0, ba.Length);

                    byte[] bb = new byte[100];
                    int k = stm.Read(bb, 0, 100);

                    tcpclnt.Close();

                    volverAintentar = false;

                    Log.Info($"[{mercadoPago.Comprobante}] - Enviado correctamente a máquina: {mercadoPago.MaquinaId}");
                }
                catch (Exception e)
                {
                    intentos++;

                    if (intentos >= limiteIntentos)
                    {
                        Log.Error($"[{mercadoPago.Comprobante}] - Límite de reintentos alcanzado!");

                        volverAintentar = false;

                        MercadoPagoTable entity = await bugsDbContext.MercadoPagoTable.Where(
                            x => x.MercadoPagoId == mercadoPago.MercadoPagoId).FirstOrDefaultAsync();

                        if (entity != null)
                        {
                            entity.MercadoPagoEstadoFinancieroId = (int)MercadoPagoEstadoFinanciero.States.ACREDITADO;
                            entity.MercadoPagoEstadoTransmisionId = (int)MercadoPagoEstadoTransmision.States.TERMINADO_MAL;
                            entity.Descripcion = "Error al conectar socket";
                            entity.FechaModificacionEstadoTransmision = DateTime.Now;
                            Log.Error(
                                $"[{mercadoPago.Comprobante}] - No se pudo realizar la conexión al socket luego de {limiteIntentos} reintentos.\n" +
                                $"Destino: {destinoIp}:{destinoPuerto}\n" +
                                $"Mensaje: {e.Message}\n"
                            );
                            entity.Reintentos = intentos;

                            bugsDbContext.Entry(entity).State = EntityState.Modified;
                            await bugsDbContext.SaveChangesAsync();
                        }
                        else
                        {
                            Log.Info($"[{mercadoPago.Comprobante}] - No se encontro el pago a devolver: {mercadoPago.MercadoPagoId} luego de {limiteIntentos} intentos.");
                        }
                    }
                    else
                    {
                        volverAintentar = true;

                        Log.Info($"[{mercadoPago.Comprobante}] - No se pudo enviar el pago, reintentando - Intento {intentos}/{limiteIntentos}");

                        if (isTiempoLineal)
                        {
                            tiempoSleep = tiempoEspera;
                        }
                        else
                        {
                            tiempoSleep = intentos * tiempoEspera;
                        }

                        //Thread.Sleep(tiempoSleep);
                        await Task.Delay(tiempoSleep);
                    }
                }
            }
            Log.Info($"[{mercadoPago.Comprobante}] - Finalizó envío a máquina.");
        }

        private async Task ProcesarPendientesMixtosExpirados(BugsContext bugsDbContext, Operador operador)
        {
            DateTime limite = DateTime.UtcNow.Subtract(VentanaPagoMixto);

            var pendientesExpirados = await bugsDbContext.MercadoPagoOperacionMixta
                .Where(x => x.OperadorId == operador.OperadorID && !x.Cerrada && x.FechaAuthorizedUtc <= limite)
                .ToListAsync();

            foreach (var pendiente in pendientesExpirados)
            {
                await CerrarPagoMixtoInconsistente(bugsDbContext, pendiente, operador);
            }
        }

        private async Task RegistrarPagoMixtoAutorizado(BugsContext bugsDbContext, Operador operador, string externalReference)
        {
            var pendiente = await ObtenerOperacionMixtaPendiente(bugsDbContext, operador, externalReference);
            DateTime ahora = DateTime.UtcNow;

            if (pendiente != null)
            {
                pendiente.FechaUltimaActualizacionUtc = ahora;
                bugsDbContext.Entry(pendiente).State = EntityState.Modified;
                await bugsDbContext.SaveChangesAsync();
                return;
            }

            var operacion = new MercadoPagoOperacionMixta
            {
                OperadorId = operador.OperadorID,
                ExternalReference = externalReference,
                FechaAuthorizedUtc = ahora,
                MontoAcumulado = 0,
                ApprovedCount = 0,
                PaymentId1 = null,
                PaymentId2 = null,
                Cerrada = false,
                FechaCierreUtc = null,
                FechaUltimaActualizacionUtc = ahora
            };

            bugsDbContext.MercadoPagoOperacionMixta.Add(operacion);
            await bugsDbContext.SaveChangesAsync();
        }

        private async Task<MercadoPagoOperacionMixta> ObtenerOperacionMixtaPendiente(BugsContext bugsDbContext, Operador operador, string externalReference)
        {
            return await bugsDbContext.MercadoPagoOperacionMixta
                .FirstOrDefaultAsync(x => x.OperadorId == operador.OperadorID && x.ExternalReference == externalReference && !x.Cerrada);
        }

        private bool OperacionMixtaExpirada(MercadoPagoOperacionMixta operacion)
        {
            return DateTime.UtcNow.Subtract(operacion.FechaAuthorizedUtc) > VentanaPagoMixto;
        }

        private async Task<bool> PagoMixtoYaProcesado(BugsContext bugsDbContext, Operador operador, long idComprobante)
        {
            return await bugsDbContext.MercadoPagoOperacionMixta.AnyAsync(x =>
                x.OperadorId == operador.OperadorID &&
                (x.PaymentId1 == idComprobante || x.PaymentId2 == idComprobante));
        }

        private bool OperacionMixtaTieneDosPatasRegistradas(MercadoPagoOperacionMixta operacion)
        {
            return operacion.PaymentId1.HasValue && operacion.PaymentId2.HasValue;
        }

        private bool OperacionMixtaValidaParaEnvioMaquina(MercadoPagoOperacionMixta operacion)
        {
            return operacion.MontoAcumulado > 0 &&
                operacion.PaymentId1.HasValue && operacion.PaymentId1.Value != 0 &&
                operacion.PaymentId2.HasValue && operacion.PaymentId2.Value != 0;
        }

        private async Task<Maquina> ResolverMaquinaMixtaPorExternalReference(BugsContext bugsDbContext, MercadoPagoOperacionMixta operacion, Operador operador)
        {
            if (operador == null || string.IsNullOrWhiteSpace(operacion.ExternalReference))
            {
                return null;
            }

            return await bugsDbContext.Maquinas.FirstOrDefaultAsync(x =>
                x.NotasService != null &&
                x.NotasService == operacion.ExternalReference &&
                x.OperadorID == operador.OperadorID);
        }

        private long? ObtenerPaymentIdComprobanteValido(MercadoPagoOperacionMixta operacion)
        {
            if (operacion.PaymentId1.HasValue && operacion.PaymentId1.Value > 0)
            {
                return operacion.PaymentId1.Value;
            }

            if (operacion.PaymentId2.HasValue && operacion.PaymentId2.Value > 0)
            {
                return operacion.PaymentId2.Value;
            }

            return null;
        }

        private async Task CerrarPagoMixtoRechazadoOCancelado(BugsContext bugsDbContext, MercadoPagoOperacionMixta operacion, Operador operador)
        {
            long? paymentIdComprobante = ObtenerPaymentIdComprobanteValido(operacion);

            if (operacion.MontoAcumulado <= 0 || paymentIdComprobante == null)
            {
                Log.Info(
                    "Cierre de pago mixto rechazado/cancelado sin impacto financiero: no se registra NO_PROCESABLE en MercadoPagoTable. " +
                    $"MercadoPagoOperacionMixtaId={operacion.MercadoPagoOperacionMixtaId}, ExternalReference={operacion.ExternalReference}, OperadorId={operacion.OperadorId}, " +
                    $"MontoAcumulado={operacion.MontoAcumulado}, PaymentId1={operacion.PaymentId1}, PaymentId2={operacion.PaymentId2}");
            }
            else
            {
                Maquina maquinaResuelta = await ResolverMaquinaMixtaPorExternalReference(bugsDbContext, operacion, operador);
                bool usaFallbackMaquinaNula = maquinaResuelta == null;

                Log.Info(
                    $"[0] - Cierre de pago mixto rechazado/cancelado. Se insertará NO_PROCESABLE. MercadoPagoOperacionMixtaId={operacion.MercadoPagoOperacionMixtaId}, " +
                    $"ExternalReference={operacion.ExternalReference}, PaymentId1={operacion.PaymentId1}, PaymentId2={operacion.PaymentId2}, PaymentIdComprobante={paymentIdComprobante}, " +
                    $"MontoAcumulado={operacion.MontoAcumulado}, MaquinaIdResuelta={(maquinaResuelta != null ? maquinaResuelta.MaquinaID.ToString() : "null")}, UsaFallbackMaquinaNula={usaFallbackMaquinaNula}");

                if (usaFallbackMaquinaNula)
                {
                    Log.Warn($"[0] - No se pudo resolver máquina para ExternalReference={operacion.ExternalReference} y OperadorId={operacion.OperadorId}. Se utilizará fallback de máquina nula.");
                }

                await GuardarNoProcesable(
                    bugsDbContext,
                    0,
                    "Pago mixto rechazado o cancelado",
                    operador,
                    operacion.MontoAcumulado,
                    null,
                    paymentIdComprobante.ToString(),
                    maquinaResuelta);
            }

            operacion.Cerrada = true;
            operacion.FechaCierreUtc = DateTime.UtcNow;
            operacion.FechaUltimaActualizacionUtc = DateTime.UtcNow;
            bugsDbContext.Entry(operacion).State = EntityState.Modified;
            await bugsDbContext.SaveChangesAsync();
        }

        private async Task CerrarPagoMixtoInconsistente(BugsContext bugsDbContext, MercadoPagoOperacionMixta operacion, Operador operador)
        {
            bool cierreSilencioso = operacion.MontoAcumulado == 0 ||
                (operacion.PaymentId1 == null && operacion.PaymentId2 == null);

            if (cierreSilencioso)
            {
                Log.Info(
                    "Cierre por timeout de pago mixto sin impacto financiero: no se registra NO_PROCESABLE en MercadoPagoTable. " +
                    $"MercadoPagoOperacionMixtaId={operacion.MercadoPagoOperacionMixtaId}, ExternalReference={operacion.ExternalReference}, OperadorId={operacion.OperadorId}, " +
                    $"MontoAcumulado={operacion.MontoAcumulado}, ApprovedCount={operacion.ApprovedCount}, PaymentId1={operacion.PaymentId1}, PaymentId2={operacion.PaymentId2}");
            }
            else
            {
                long? paymentIdComprobante = ObtenerPaymentIdComprobanteValido(operacion);

                if (paymentIdComprobante == null)
                {
                    Log.Warn(
                        $"[0] - Timeout de pago mixto inconsistente sin paymentId para comprobante. MercadoPagoOperacionMixtaId={operacion.MercadoPagoOperacionMixtaId}, " +
                        $"ExternalReference={operacion.ExternalReference}, OperadorId={operacion.OperadorId}");
                }

                Maquina maquinaResuelta = await ResolverMaquinaMixtaPorExternalReference(bugsDbContext, operacion, operador);

                bool usaFallbackMaquinaNula = maquinaResuelta == null;

                Log.Info(
                    $"[0] - Registrando NO_PROCESABLE por timeout de pago mixto inconsistente. MercadoPagoOperacionMixtaId={operacion.MercadoPagoOperacionMixtaId}, " +
                    $"ExternalReference={operacion.ExternalReference}, MontoAcumulado={operacion.MontoAcumulado}, ApprovedCount={operacion.ApprovedCount}, " +
                    $"PaymentId1={operacion.PaymentId1}, PaymentId2={operacion.PaymentId2}, PaymentIdComprobante={paymentIdComprobante}, " +
                    $"MaquinaIdResuelta={(maquinaResuelta != null ? maquinaResuelta.MaquinaID.ToString() : "null")}, UsaFallbackMaquinaNula={usaFallbackMaquinaNula}");

                if (usaFallbackMaquinaNula)
                {
                    Log.Warn($"[0] - No se pudo resolver máquina para ExternalReference={operacion.ExternalReference} y OperadorId={operacion.OperadorId}. Se utilizará fallback de máquina nula.");
                }

                await GuardarNoProcesable(
                    bugsDbContext,
                    0,
                    "Pago mixto inconsistente",
                    operador,
                    operacion.MontoAcumulado,
                    null,
                    paymentIdComprobante?.ToString(),
                    maquinaResuelta);
            }

            operacion.Cerrada = true;
            operacion.FechaCierreUtc = DateTime.UtcNow;
            operacion.FechaUltimaActualizacionUtc = DateTime.UtcNow;
            bugsDbContext.Entry(operacion).State = EntityState.Modified;
            await bugsDbContext.SaveChangesAsync();
        }

        private async Task<Maquina> ObtenerMaquinaPorExternalReference(BugsContext bugsDbContext, string externalReference, Operador operador, long idComprobante, decimal monto)
        {
            if (string.IsNullOrWhiteSpace(externalReference))
            {
                Log.Info($"[{idComprobante}] - External Reference es nulo.");
                return null;
            }

            bool existeMaquina = await bugsDbContext.Maquinas.AnyAsync(x => x.NotasService == externalReference);

            if (!existeMaquina)
            {
                string mensajeDescripcion = $"No existe la máquina con Ext.Ref. = {externalReference} en la base de datos.";

                Log.Error($"[{idComprobante}] - {mensajeDescripcion}");
                await GuardarNoProcesable(bugsDbContext, idComprobante, mensajeDescripcion, operador, monto);
                return null;
            }

            var maquina = await bugsDbContext.Maquinas
                .Where(x => x.NotasService != null && x.NotasService == externalReference && x.OperadorID == operador.OperadorID)
                .FirstOrDefaultAsync();

            if (maquina == null)
            {
                string mensajeDescripcion = $"No se encontro la maquina: {externalReference} para el operador: {operador.Nombre} del pago en curso";
                Log.Error($"[{idComprobante}] - {mensajeDescripcion}");

                await GuardarNoProcesable(bugsDbContext, idComprobante, mensajeDescripcion, operador, monto);
                return null;
            }

            return maquina;
        }

        /// <summary>
        /// Registra en la base de datos los casos donde el pago no puede ser procesado (por ejemplo, operador o máquina no encontrados).
        /// </summary>
        /// <param name="bugsDbContext">Contexto de base de datos a utilizar.</param>
        /// <param name="idComprobante">ID del comprobante de MercadoPago.</param>
        /// <param name="descripcion">Descripción del motivo por el cual no se pudo procesar el pago.</param>
        /// <param name="operador">Operador asociado al pago (puede ser nulo).</param>
        /// <param name="monto">Monto del pago (opcional).</param>
        /// <returns>True si el registro fue guardado correctamente, false en caso de error.</returns>
        private async Task<Boolean> GuardarNoProcesable(BugsContext bugsDbContext, long idComprobante, string descripcion, Operador operador, decimal monto = 0, string detalleUrlDevolucion = null, string comprobanteOverride = null, Maquina maquinaOverride = null)
        {
            Log.Info($"[{idComprobante}] - Registrando caso no procesable. Operador: {(operador != null ? operador.OperadorID.ToString() : "null")} - Monto: {monto}");

            Boolean result = true;

            Maquina maquina = maquinaOverride;
            if (maquina == null && operador != null)
            {
                maquina = await bugsDbContext.Maquinas.FirstOrDefaultAsync(x => x.NotasService == MAQUINA_NULA && x.Operador.OperadorID == operador.OperadorID);
            }
            else if (operador == null)
            {
                Log.Error($"[{idComprobante}] - No se proporcionó un operador correcto para registrar el caso no procesable.");
            }


            //TODO es probable que el caso donde no registra nada en la DB es porque los datos del operador no coincidan con los datos en la db, se podría hacer un workaround solo asignando el id?
            try
            {
                var entity = new MercadoPagoTable
                {
                    Fecha = DateTime.Now,
                    Monto = monto,
                    Maquina = maquina,
                    MercadoPagoEstadoFinancieroId = (int)MercadoPagoEstadoFinanciero.States.NO_PROCESABLE,
                    MercadoPagoEstadoTransmisionId = (int)MercadoPagoEstadoTransmision.States.NO_PROCESABLE,
                    Comprobante = string.IsNullOrWhiteSpace(comprobanteOverride) ? idComprobante.ToString() : comprobanteOverride,
                    Descripcion = descripcion,
                    FechaModificacionEstadoTransmision = DateTime.Now,
                    Entidad = "MP",
                    UrlDevolucion = detalleUrlDevolucion,
                    Operador = operador
                };

                bugsDbContext.MercadoPagoTable.Add(entity);
                await bugsDbContext.SaveChangesAsync();
                Log.Info($"[{idComprobante}] - Registro NO PROCESABLE guardado correctamente en la base de datos.");
            }
            catch (Exception ex)
            {
                Log.Error($"[{idComprobante}] - Error al guardar caso no procesable en la base de datos", ex);
                result = false;
            }

            return result;
        }

        private async Task<MpSimPaymentDto> ConsultarPaymentEnSimulador(long idComprobante)
        {
            string url = $"http://127.0.0.1:5005/v1/payments/{idComprobante}";

            using (var httpClient = new HttpClient())
            {
                HttpResponseMessage response = await httpClient.GetAsync(url);

                if (response.StatusCode == HttpStatusCode.NotFound)
                {
                    throw new Exception($"No se encontró el payment {idComprobante} en mp_simulator.");
                }

                response.EnsureSuccessStatusCode();

                string json = await response.Content.ReadAsStringAsync();
                MpSimPaymentDto payment = JsonConvert.DeserializeObject<MpSimPaymentDto>(json);

                if (payment == null)
                {
                    throw new Exception($"No se pudo deserializar la respuesta del payment {idComprobante} en mp_simulator.");
                }

                return payment;
            }
        }

        private bool EsEstadoPago(string estadoActual, string estadoEsperado)
        {
            return string.Equals(estadoActual, estadoEsperado, StringComparison.OrdinalIgnoreCase);
        }

        private class MpSimPaymentDto
        {
            public long id { get; set; }
            public string status { get; set; }
            public decimal? transaction_amount { get; set; }
            public string external_reference { get; set; }
            public string currency_id { get; set; }
            public string payment_method_id { get; set; }
        }

        #region Funciones no utilizadas
        //private PaymentoResponse ObtenerResponsePayment(Payment payment)
        //{
        //    try
        //    {
        //        JObject jsonobject = payment.GetJsonSource();
        //        JsonReader ob = jsonobject.CreateReader();
        //        JsonSerializer serializer = new JsonSerializer();
        //        PaymentoResponse responsepayment = serializer.Deserialize<PaymentoResponse>(ob);
        //        return responsepayment;
        //    }
        //    catch (Exception ex)
        //    {
        //        Log.Error("Hubo un error en PagosMPController->ObtenerResponsePayment", ex);
        //        return null;
        //    }
        //}

        //private async void EnviarPagoAMaquinaIdNulo(BugsContext db, int idPago, decimal importe, string urlDevolucion, string tokenCliente, string refCliente)
        //{
        //    int intentos = 0;
        //    int limiteIntentos = int.Parse(ConfigurationManager.AppSettings["LimiteReintentos"]);
        //    bool volverAintentar = true;
        //    string mensaje = $"${idPago}, maquinaId = null, {Math.Truncate(importe * 100)}!";

        //    Log.Info($"Enviando pago con ID NULO a máquina...");

        //    while (intentos < 3 && volverAintentar)
        //    {
        //        int tiempoSleep = intentos * 1000;

        //        Log.Info($"Intento numero: {intentos + 1} - Volver a intentar: {volverAintentar}");

        //        try
        //        {
        //            intentos++;

        //            TcpClient tcpclnt = new TcpClient();

        //            tcpclnt.Connect(ip, Convert.ToInt32(puerto));

        //            Stream stm = tcpclnt.GetStream();

        //            ASCIIEncoding asen = new ASCIIEncoding();
        //            byte[] ba = asen.GetBytes(mensaje);

        //            stm.Write(ba, 0, ba.Length);

        //            byte[] bb = new byte[100];
        //            int k = stm.Read(bb, 0, 100);

        //            tcpclnt.Close();

        //            tcpclnt = null;

        //            volverAintentar = false;
        //        }
        //        catch (Exception e)
        //        {
        //            volverAintentar = true;

        //            if (intentos >= 3)
        //            {
        //                //Devolver 
        //                MercadoPagoTable entity = db.MercadoPagoTable.Where(x => x.MercadoPagoId == idPago).First();

        //                if (entity != null)
        //                {

        //                    HttpResponseMessage response = await EnviarRechazoAsync(entity);

        //                    if (response.StatusCode == HttpStatusCode.OK)
        //                    {

        //                        entity.MercadoPagoEstadoFinancieroId = (int)MercadoPagoEstadoFinanciero.States.DEVUELTO;
        //                        entity.MercadoPagoEstadoTransmisionId = (int)MercadoPagoEstadoTransmision.States.ERROR_CONEXION;
        //                        entity.Descripcion = "Error al conectar socket";
        //                        entity.FechaModificacionEstadoTransmision = DateTime.Now;
        //                        Log.Error("No se pudo realizar la conexión y se devolvio el dinero", e);
        //                        db.Entry(entity).State = EntityState.Modified;
        //                        db.SaveChanges();
        //                    }
        //                    else
        //                    {
        //                        entity.MercadoPagoEstadoFinancieroId = (int)MercadoPagoEstadoFinanciero.States.AVISO_FALLIDO;
        //                        entity.MercadoPagoEstadoTransmisionId = (int)MercadoPagoEstadoTransmision.States.ERROR_CONEXION;
        //                        entity.Descripcion = "Error al conectar socket";
        //                        entity.FechaModificacionEstadoTransmision = DateTime.Now;
        //                        Log.Error("No se pudo realizar la conexión y no se pudo notificar al operador (" + response.ReasonPhrase + ")", e);
        //                        db.Entry(entity).State = EntityState.Modified;
        //                        db.SaveChanges();
        //                    }

        //                }
        //                else
        //                {
        //                    Log.Info("No se encontro el pago a devolver: " + idPago);
        //                }

        //            }

        //            Thread.Sleep(tiempoSleep);
        //        }
        //    }
        //}

        //private Boolean GuardarNoEncontrados(BugsContext db, Operador op, String descripcion)
        //{
        //    Boolean result = true;

        //    var maqId = MAQUINA_NULA;
        //    Maquina operador = db.Maquinas.Where((x) => x.NotasService == maqId && x.OperadorID == op.OperadorID).FirstOrDefault();

        //    //No se realiza la devolución porque no existe el idPayment
        //    if (operador != null)
        //    {
        //        MercadoPagoTable entity = new MercadoPagoTable
        //        {
        //            Fecha = DateTime.Now,
        //            Monto = 0,
        //            Maquina = operador,
        //            MercadoPagoEstadoFinancieroId = (int)MercadoPagoEstadoFinanciero.States.AVISO_FALLIDO,
        //            MercadoPagoEstadoTransmisionId = (int)MercadoPagoEstadoTransmision.States.ERROR_CONEXION,
        //            Descripcion = descripcion,
        //            Comprobante = "99999999",
        //            FechaModificacionEstadoTransmision = DateTime.Now,
        //            Entidad = "MP"
        //        };

        //        db.MercadoPagoTable.Add(entity);
        //        db.SaveChanges();
        //    }


        //    return result;

        //}

        //private Boolean GuardarenDevolucion(MercadoPagoTable mercadoPago, string Descripcion)
        //{

        //    Boolean result = true;

        //    MercadoPagoTable entity = db.MercadoPagoTable.Where(x => x.Comprobante == mercadoPago.Comprobante).First();

        //    MercadoPago.SDK.CleanConfiguration();
        //    MercadoPago.SDK.ClientId = entity.Maquina.Operador.ClientId;
        //    MercadoPago.SDK.ClientSecret = entity.Maquina.Operador.SecretToken;

        //    long id = 0;
        //    long.TryParse(entity.Comprobante, out id);
        //    Payment payment = Payment.FindById(id);
        //    if (payment.Errors == null)
        //    {
        //        //*IMPORTANTE COMENTAR payment.Refund(); PARA QUE NO REALICE DEVOLUCIONES EN UN DEBUG DE PRUEBA
        //        payment.Refund();
        //        if (payment.Status == PaymentStatus.approved)
        //        {

        //            entity.MercadoPagoEstadoFinancieroId = (int)MercadoPagoEstadoFinanciero.States.DEVUELTO;
        //            entity.MercadoPagoEstadoTransmisionId = (int)MercadoPagoEstadoTransmision.States.ERROR_CONEXION;
        //            entity.Descripcion = Descripcion + "Se realizó la devolución.";// "Error al conectar socket";
        //            entity.FechaModificacionEstadoTransmision = DateTime.Now;
        //            Log.Error("No se pudo realizar la conexión y se devolvio el dinero");//, e);
        //            db.Entry(entity).State = EntityState.Modified;
        //            db.SaveChanges();
        //        }
        //        else
        //        {
        //            Log.Info("Ya se devolvio el comprobante: " + mercadoPago.Comprobante);
        //            entity.MercadoPagoEstadoFinancieroId = (int)MercadoPagoEstadoFinanciero.States.AVISO_FALLIDO;
        //            entity.MercadoPagoEstadoTransmisionId = (int)MercadoPagoEstadoTransmision.States.ERROR_CONEXION;
        //            entity.Descripcion = Descripcion + " y al conectar servidor de MP";// "Error al conectar socket y al conectar servidor de MP";
        //            entity.FechaModificacionEstadoTransmision = DateTime.Now;
        //            Log.Error("No se pudo realizar la conexión y no se pudo devolver el dinero");//, e)
        //            db.Entry(entity).State = EntityState.Modified;
        //            db.SaveChanges();
        //        }
        //    }
        //    else
        //    {
        //        Log.Info("No se encontro el comprobante: " + mercadoPago.Comprobante);
        //    }


        //    return result;
        //}


        ////Registra un pago con Id de maquina nulo dentro de la tabla mercadoPagoTable, asignando los estados de "No Procesable"
        //private void RegistrarPagoIdNulo(BugsContext db, decimal importe, string urlDevolucion, string tokenCliente, string refCliente, Guid? operadorId)

        //{
        //    Log.Info("Llega notificacion de pago al sistema: maquina= nulo" + ", importe=" + importe);

        //    var paymentEntity = new MercadoPagoTable
        //    {
        //        OperadorId = operadorId,
        //        Comprobante = refCliente,
        //        Monto = importe,
        //        Fecha = DateTime.Now,
        //        MercadoPagoEstadoTransmisionId = (int)MercadoPagoEstadoTransmision.States.NO_PROCESABLE,
        //        MercadoPagoEstadoFinancieroId = (int)MercadoPagoEstadoFinanciero.States.NO_PROCESABLE,
        //        FechaModificacionEstadoTransmision = null,
        //        MaquinaId = new Guid((string)"null"),
        //        Entidad = "MP",
        //        UrlDevolucion = urlDevolucion,
        //        Descripcion = "Caja Invalida",

        //    };

        //    db.MercadoPagoTable.Add(paymentEntity);
        //    db.SaveChanges();
        //    //se comenta xq no lo estamos utilizando
        //    //EnviarPagoAMaquinaIdNulo(paymentEntity.MercadoPagoId, paymentEntity.Monto, urlDevolucion, tokenCliente, refCliente);

        //}

        #endregion

    }
}
