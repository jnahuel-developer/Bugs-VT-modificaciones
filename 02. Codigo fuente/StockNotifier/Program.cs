using System;
using System.Collections.Generic;
using System.Linq;
using BugsMVC.DAL;
using System.Net.Mail;
using BugsMVC.Models;
using System.Configuration;

using MercadoPago.Config;
using MercadoPago.Resource.Payment;

using System.Collections;
using System.Data.Entity;
using System.IO;
using BugsMVC.Controllers;
using System.Net.Http;
using System.Threading.Tasks;
using System.Runtime.Serialization;
using System.Runtime.Serialization.Json;
using System.Text;

using System.Data.SqlClient;
using System.Data;
using MercadoPago.Client.Payment;
using MercadoPago.Error;

[assembly: log4net.Config.XmlConfigurator(Watch = true)]
namespace StockNotifier
{
    class Program
    {
        private const string MpSimulatorBaseUrl = "http://127.0.0.1:5005";
        private static readonly TimeSpan MpSimulatorHttpTimeout = TimeSpan.FromSeconds(60);

        public static BugsContext db;
        private static readonly log4net.ILog Log =
            log4net.LogManager.GetLogger(System.Reflection.MethodBase.GetCurrentMethod().DeclaringType);

        public static async Task Main(string[] args)
        {
            try
            {
                AmbienteConfigHelper.Inicializar();
                bool pagosMixtosHabilitados = PagosMixtosConfigHelper.PagosMixtosHabilitados;
                bool ambienteDesarrolloHabilitado = AmbienteConfigHelper.AmbienteDesarrolloHabilitado;
                bool ambienteSimuladoresHabilitado = AmbienteConfigHelper.AmbienteSimuladoresHabilitado;

                Log.Info($"Configuración: Pagos mixtos habilitados = {pagosMixtosHabilitados}.");
                Log.Info($"Configuración: Ambiente de desarrollo habilitado = {ambienteDesarrolloHabilitado}.");
                Log.Info($"Configuración: Ambiente de simuladores habilitado = {ambienteSimuladoresHabilitado}.");

                db = new BugsContext();

                var stocks = db.Stocks.ToList();
                var maquinas = db.Maquinas.ToList();
                var mercadoPagos = db.MercadoPagoTable;
                int tiempoMP = 5;

                var mailsStockMuyBajo = new List<Stock>();
                var mailsStockBajo = new List<Stock>();
                var mailsMaquinaSinConexion = new List<Maquina>();
                var mailsMaquinaInhibidas = new List<Maquina>();

                Log.Info(new string('-', 80));
                Log.Info("Control de stock");

                foreach (var stock in stocks)
                {
                    if (stock.ArticuloAsignacion.ControlStock && stock.ArticuloAsignacion.AlarmaActiva.HasValue && stock.ArticuloAsignacion.AlarmaActiva.Value && (stock.FechaAviso == null || stock.FechaAviso.Value.Date < DateTime.Now.Date))
                    {
                        if (stock.Cantidad < stock.ArticuloAsignacion.AlarmaBajo && stock.Cantidad < stock.ArticuloAsignacion.AlarmaMuyBajo)
                        {
                            mailsStockMuyBajo.Add(stock);
                        }
                        else if (stock.Cantidad < stock.ArticuloAsignacion.AlarmaBajo)
                        {
                            mailsStockBajo.Add(stock);
                        }
                    }
                }

                Log.Info("Control Maquinas Conectadas");
                var test = maquinas.Where(x => x.Estado == "Asignada");

                foreach (var maquina in maquinas.Where(x => x.Estado == "Asignada"))
                {
                    if (maquina.FechaUltimaConexion.HasValue && (DateTime.Now - maquina.FechaUltimaConexion.Value).TotalMinutes >= maquina.Operador.TiempoAvisoConexion)
                    {
                        if (maquina.AlarmaActiva.HasValue && maquina.AlarmaActiva == true
                        && (maquina.FechaAviso == null || maquina.FechaAviso.Value.Date < DateTime.Now.Date
                        || (maquina.FechaAviso.Value.Date >= DateTime.Now.Date && maquina.EstadoConexion != "Sin Conexión")))
                        {
                            mailsMaquinaSinConexion.Add(maquina);
                        }

                        if (maquina.EstadoConexion != "Sin Conexión")
                        {
                            maquina.FechaEstado = DateTime.Now;
                            maquina.EstadoConexion = "Sin Conexión";
                        }

                    }
                    else
                    {
                        if (maquina.FechaUltimoOk.HasValue && (DateTime.Now - maquina.FechaUltimoOk.Value).TotalMinutes >= maquina.Operador.TiempoAvisoInhibicion)
                        {
                            if (maquina.AlarmaActiva.HasValue && maquina.AlarmaActiva == true
                            && (maquina.FechaAviso == null || (((DateTime.Now - maquina.FechaUltimaConexion.Value).TotalMinutes < maquina.Operador.TiempoAvisoConexion
                            && maquina.EstadoConexion != "Inactiva") || maquina.FechaAviso.Value.Date < DateTime.Now.Date && maquina.EstadoConexion != "Inactiva")))
                            {
                                mailsMaquinaInhibidas.Add(maquina);
                            }

                            if (maquina.EstadoConexion != "Inactiva")
                            {
                                maquina.FechaEstado = DateTime.Now;
                                maquina.EstadoConexion = "Inactiva";
                            }
                        }
                        else
                        {
                            if (maquina.FechaUltimaConexion.HasValue && maquina.FechaUltimoOk.HasValue
                            && (DateTime.Now - maquina.FechaUltimoOk.Value).TotalMinutes < maquina.Operador.TiempoAvisoInhibicion
                            && (DateTime.Now - maquina.FechaUltimaConexion.Value).TotalMinutes < maquina.Operador.TiempoAvisoConexion
                            )
                            {
                                if (maquina.EstadoConexion != "Activa")
                                {
                                    maquina.FechaEstado = DateTime.Now;
                                    maquina.EstadoConexion = "Activa";
                                }

                                maquina.FechaAviso = null;
                            }
                        }
                    }

                    db.SaveChanges();

                }

                Log.Info("Control Devoluciones");

                var mercadoPagosFiltrados = mercadoPagos
                    .Where(x => x.MercadoPagoEstadoFinancieroId == (int)MercadoPagoEstadoFinanciero.States.ACREDITADO)
                    .Where(x => x.MercadoPagoEstadoTransmisionId != (int)MercadoPagoEstadoTransmision.States.TERMINADO_OK)
                    .AsEnumerable()
                    .Where(x =>
                            (
                                x.MercadoPagoEstadoTransmisionId != (int)MercadoPagoEstadoTransmision.States.EN_PROCESO
                                ||
                                (DateTime.Now - x.Fecha).TotalMinutes > tiempoMP
                            )
                    ).ToList();

                foreach (var mercadoPago in mercadoPagosFiltrados)
                {
                    Log.Info("Maquina:" + mercadoPago.MaquinaId);

                    //Devolver dinero
                    Maquina maquina = db.Maquinas.Where(x => x.MaquinaID == mercadoPago.MaquinaId).FirstOrDefault();
                    Operador operador = db.Operadores.Where(x => x.OperadorID == maquina.OperadorID).FirstOrDefault();

                    if (mercadoPago.Comprobante != "" && mercadoPago.Entidad == "MP" && operador.AccessToken != null)
                    {
                        if (PagosMixtosConfigHelper.PagosMixtosHabilitados)
                        {
                            await ProcesarCandidatoDevolucionPagosMixtosAsync(db, mercadoPago, operador, maquina);
                            continue;
                        }

                        await ProcesarDevolucionMercadoPagoAsync(db, mercadoPago, operador, maquina);
                    }
                    else
                    {
                        //Aca deberia registrar un estado correspondiente cuando el operador no tiene cargado accessToken.
                        Log.Info("Se envia mensaje de rechazo la entidad pagadora");
                        HttpResponseMessage response = await PagosClienteController.EnviarRechazoAsync(mercadoPago);
                        if (response.StatusCode == System.Net.HttpStatusCode.OK)
                        {
                            mercadoPago.MercadoPagoEstadoTransmisionId = (int)MercadoPagoEstadoTransmision.States.ERROR_CONEXION;
                            mercadoPago.MercadoPagoEstadoFinancieroId = (int)MercadoPagoEstadoFinanciero.States.DEVUELTO;
                        }
                        else
                        {
                            Log.Info("No se pudo enviar mensaje a la entidad pagadora");
                            mercadoPago.MercadoPagoEstadoTransmisionId = (int)MercadoPagoEstadoTransmision.States.ERROR_CONEXION;
                            mercadoPago.MercadoPagoEstadoFinancieroId = (int)MercadoPagoEstadoFinanciero.States.AVISO_FALLIDO;
                        }

                        db.Entry(mercadoPago).State = EntityState.Modified;
                        db.SaveChanges();

                    }

                }

                ProcesarListaStock("SistemaVT - Alarma Stock Muy Bajo", mailsStockMuyBajo);
                ProcesarListaStock("SistemaVT - Alarma Stock Bajo", mailsStockBajo);

                ProcesarListaMaquina("SistemaVT - Alarma Máquina Sin Conexión", mailsMaquinaSinConexion);
                ProcesarListaMaquina("SistemaVT - Alarma Máquina Inactiva", mailsMaquinaInhibidas);

            }

            catch (Exception ex)
            {

                Log.Error(ex.Message);

            }
        }

        /// <summary>
        /// Procesa la lista de stocks con bajo o muy bajo nivel y envía notificaciones por correo a los usuarios configurados.
        /// </summary>
        /// <param name="subject">Asunto del correo.</param>
        /// <param name="Lowstocks">Lista de stocks a informar.</param>
        private static void ProcesarListaStock(string subject, List<Stock> Lowstocks)
        {
            List<AlarmaConfiguracionDetalle> alarmasConfiguracionDetalles = db.AlarmaConfiguracionDetalle.Where(x => x.AlarmaConfiguracion.TipoDeAlarmaID == TipoDeAlarma.IdControlStock).ToList();

            foreach (var item in alarmasConfiguracionDetalles)
            {
                List<Stock> stockAInformar = Lowstocks.Where(x => ((item.AlarmaConfiguracion.LocacionID.HasValue && item.AlarmaConfiguracion.LocacionID == x.ArticuloAsignacion.LocacionID)
                                || item.AlarmaConfiguracion.OperadorID == x.ArticuloAsignacion.Locacion.OperadorID)).ToList();

                var mailsDestinatarios = db.Users.Where(x => item.UsuarioID == x.UsuarioID).Select(x => x.Email).FirstOrDefault();

                string body = string.Empty;

                foreach (var stock in stockAInformar)
                {
                    body += string.Format("El artículo \"{0}\" (Máquina \"{1}\", Nro Serie \"{2}\"- Locación \"{3}\") se encuentra {4} de stock. <br />",
                    stock.ArticuloAsignacion.Articulo.Nombre,
                    stock.ArticuloAsignacion.Maquina.NombreAlias != null ? stock.ArticuloAsignacion.Maquina.MarcaModelo.MarcaModeloNombre + " - "
                        + stock.ArticuloAsignacion.Maquina.NumeroSerie + '(' + stock.ArticuloAsignacion.Maquina.NombreAlias + ')'
                        : stock.ArticuloAsignacion.Maquina.MarcaModelo.MarcaModeloNombre + '-' + stock.ArticuloAsignacion.Maquina.NumeroSerie,
                    stock.ArticuloAsignacion.Maquina.NumeroSerie,
                    stock.ArticuloAsignacion.Maquina.LocacionID.HasValue ? stock.ArticuloAsignacion.Maquina.Locacion.Nombre : "No Disponible",
                    subject.Contains("Muy") ? "muy bajo" : "bajo");

                    stock.FechaAviso = DateTime.Now;
                }

                try
                {
                    if (stockAInformar.Count() > 0)
                    {
                        SendMail(subject, body, mailsDestinatarios);
                        db.SaveChanges();
                    }
                }
                catch (Exception e)
                {
                    Console.Write(e);
                }
            }
        }

        /// <summary>
        /// Procesa la lista de máquinas sin conexión o inactivas y envía notificaciones por correo a los usuarios configurados.
        /// </summary>
        /// <param name="subject">Asunto del correo.</param>
        /// <param name="maquinas">Lista de máquinas a informar.</param>
        private static void ProcesarListaMaquina(string subject, List<Maquina> maquinas)
        {
            List<AlarmaConfiguracionDetalle> alarmasConfiguracionDetalles = db.AlarmaConfiguracionDetalle.Where(x => x.AlarmaConfiguracion.TipoDeAlarmaID == TipoDeAlarma.IdControlEstadoMaquina).ToList();

            foreach (var item in alarmasConfiguracionDetalles)
            {
                List<Maquina> maquinasAInformar = maquinas.Where(x => ((item.AlarmaConfiguracion.LocacionID.HasValue && item.AlarmaConfiguracion.LocacionID == x.LocacionID) ||
                               item.AlarmaConfiguracion.OperadorID == x.OperadorID)).ToList();

                var mailsDestinatarios = db.Users.Where(x => item.UsuarioID == x.UsuarioID).Select(x => x.Email).First();

                string body = string.Empty;

                foreach (var maquina in maquinasAInformar)
                {
                    body += string.Format("La Máquina  ({0} - Locación {1} ) se encuentra {2}. <br /> ",
                        maquina.NombreAlias != null ? maquina.MarcaModelo.MarcaModeloNombre + " - " + maquina.NumeroSerie + '(' + maquina.NombreAlias + ')'
                        : maquina.MarcaModelo.MarcaModeloNombre + '-' + maquina.NumeroSerie
                        , maquina.Locacion.Nombre
                        , maquina.EstadoConexion);

                    maquina.FechaAviso = DateTime.Now;
                }

                try
                {
                    if (maquinasAInformar.Count() > 0)
                    {
                        SendMail(subject, body, mailsDestinatarios);
                        db.SaveChanges();
                    }
                }
                catch (Exception e)
                {
                    Log.Error("Error al enviar mail - " + e.Message);

                }
            }
        }

        /// <summary>
        /// Envía un correo electrónico con el asunto y cuerpo especificados al destinatario indicado.
        /// </summary>
        /// <param name="subject">Asunto del correo.</param>
        /// <param name="body">Cuerpo del correo (HTML).</param>
        /// <param name="mailsDestinatario">Dirección de correo del destinatario.</param>
        static public void SendMail(string subject, string body, string mailsDestinatario)
        {
            Log.Info("Realizando envío de mail...");

            try
            {
                MailMessage mail = new MailMessage("noresponder@bugssa.com.ar", mailsDestinatario);
                SmtpClient client = new SmtpClient();

                mail.Subject = subject;
                mail.Body = body;
                mail.IsBodyHtml = true;

                client.Send(mail);
                Log.Info($"Correo enviado a {mailsDestinatario} correctamente.");
            }
            catch (Exception ex)
            {
                Log.Error($"Error al enviar mail a: {mailsDestinatario} - {ex.Message}", ex);
            }

        }


        private static async Task ProcesarDevolucionMercadoPagoAsync(BugsContext db, MercadoPagoTable mercadoPago, Operador operador, Maquina maquina)
        {
            if (AmbienteConfigHelper.AmbienteSimuladoresHabilitado)
            {
                Log.Info("Devolviendo al Operador: " + operador.OperadorID);

                long idPayment = 0;
                long.TryParse(mercadoPago.Comprobante, out idPayment);
                Log.Info("Buscando comprobante " + mercadoPago.Comprobante + " en MP");
                Log.Info($"Ambiente simuladores habilitado: solicitando refund en mp_simulator para comprobante {idPayment}.");

                try
                {
                    using (HttpClient httpClient = CreateMpSimulatorHttpClient())
                    {
                        var estadoInicial = await SimGetPaymentStatusAsync(httpClient, idPayment);
                        if (!estadoInicial.found)
                        {
                            Log.Info($"mp_simulator: payment {idPayment} no existe al consultar estado; se intentará refund igualmente.");
                        }

                        if (string.Equals(estadoInicial.status, "refunded", StringComparison.OrdinalIgnoreCase))
                        {
                            Log.Info("El pago ya ha sido reembolsado anteriormente, no se realizará otra devolución.");
                            Log.Info("Corrigiendo registro en MercadoPagoTable...");
                            mercadoPago.MercadoPagoEstadoTransmisionId = (int)MercadoPagoEstadoTransmision.States.ERROR_CONEXION;
                            mercadoPago.MercadoPagoEstadoFinancieroId = (int)MercadoPagoEstadoFinanciero.States.DEVUELTO;

                            db.Entry(mercadoPago).State = EntityState.Modified;
                            db.SaveChanges();
                            return;
                        }

                        bool isReembolsadoCorrectamente = await ProcesarReembolsoSimuladorAsync(httpClient, idPayment);

                        if (isReembolsadoCorrectamente)
                        {
                            Log.Info("Actualizando registro en MercadoPagoTable");
                            mercadoPago.MercadoPagoEstadoTransmisionId = (int)MercadoPagoEstadoTransmision.States.ERROR_CONEXION;
                            mercadoPago.MercadoPagoEstadoFinancieroId = (int)MercadoPagoEstadoFinanciero.States.DEVUELTO;
                        }
                        else
                        {
                            var estadoFinal = await SimGetPaymentStatusAsync(httpClient, idPayment);
                            string estadoPago = string.IsNullOrWhiteSpace(estadoFinal.status) ? "desconocido" : estadoFinal.status;
                            string errorMessage = "No se logró realizar la devolución tras 3 intentos. Status Payment: " + estadoPago;
                            Log.Info(errorMessage);
                            mercadoPago.MercadoPagoEstadoTransmisionId = (int)MercadoPagoEstadoTransmision.States.ERROR_CONEXION;
                            mercadoPago.MercadoPagoEstadoFinancieroId = (int)MercadoPagoEstadoFinanciero.States.AVISO_FALLIDO;
                            mercadoPago.Descripcion = errorMessage;
                        }

                        db.Entry(mercadoPago).State = EntityState.Modified;
                        db.SaveChanges();
                    }
                }
                catch (Exception ex)
                {
                    Log.Error("Se produjo un error al procesar la devolución contra mp_simulator.");
                    Log.Error($"Error: {ex.Message}");
                }

                return;
            }

            Log.Info("Devolviendo al Operador: " + operador.OperadorID);

            MercadoPagoConfig.AccessToken = null;
            MercadoPagoConfig.AccessToken = operador.AccessToken;

            long idPayment = 0;
            long.TryParse(mercadoPago.Comprobante, out idPayment);
            Log.Info("Buscando comprobante " + mercadoPago.Comprobante + " en MP");

            Payment payment = null;

            //Intentamos obtener la información del payment utilizando el cliente nuevo
            PaymentClient paymentClient = new PaymentClient();

            try
            {
                Log.Info($"Intentando obtener información de payment...");
                payment = await paymentClient.GetAsync(idPayment);

                if (payment != null)
                {
                    Log.Info("Comprobante encontrado");

                    if (payment.Status != PaymentStatus.Refunded)
                    {
                        //Procesar reembolso
                        bool isReembolsadoCorrectamente = await ProcesarReembolsoAsync(paymentClient, idPayment);

                        if (isReembolsadoCorrectamente)
                        {
                            Log.Info("Actualizando registro en MercadoPagoTable");
                            //mercadoPago.Descripcion = "Envio ok.";
                            mercadoPago.MercadoPagoEstadoTransmisionId = (int)MercadoPagoEstadoTransmision.States.ERROR_CONEXION;
                            mercadoPago.MercadoPagoEstadoFinancieroId = (int)MercadoPagoEstadoFinanciero.States.DEVUELTO;
                        }
                        else
                        {
                            string errorMessage = "No se logró realizar la devolución tras 3 intentos. Status Payment: " + payment.Status;
                            Log.Info(errorMessage);
                            payment = await paymentClient.GetAsync(idPayment);
                            mercadoPago.MercadoPagoEstadoTransmisionId = (int)MercadoPagoEstadoTransmision.States.ERROR_CONEXION;
                            mercadoPago.MercadoPagoEstadoFinancieroId = (int)MercadoPagoEstadoFinanciero.States.AVISO_FALLIDO;
                            mercadoPago.Descripcion = errorMessage;
                        }

                        db.Entry(mercadoPago).State = EntityState.Modified;
                        db.SaveChanges();
                    }
                    else
                    {
                        Log.Info("El pago ya ha sido reembolsado anteriormente, no se realizará otra devolución.");
                        Log.Info("Corrigiendo registro en MercadoPagoTable...");
                        //mercadoPago.Descripcion = "Envio ok.";
                        mercadoPago.MercadoPagoEstadoTransmisionId = (int)MercadoPagoEstadoTransmision.States.ERROR_CONEXION;
                        mercadoPago.MercadoPagoEstadoFinancieroId = (int)MercadoPagoEstadoFinanciero.States.DEVUELTO;

                        db.Entry(mercadoPago).State = EntityState.Modified;
                        db.SaveChanges();
                    }

                }
                else
                {
                    //No se encontró el pago,  no deberia suceder.
                    Log.Info("No se encontro el pago");
                }
            }
            catch (MercadoPagoApiException ex)
            {
                // Maneja los errores de la API de MercadoPago
                Log.Error("Se produjo un error con la API de Mercado Pago.");
                Log.Error($"Error: {ex.Message}");
                Log.Error($"Status Code: {ex.StatusCode}");
                Log.Error($"Error de API: {ex.ApiError}");
                Log.Error($"Respuesta de API: {ex.ApiResponse}");
            }
        }

        /// <summary>
        /// Intenta procesar un reembolso en MercadoPago. Realiza hasta 3 reintentos si el reembolso no se confirma.
        /// </summary>
        /// <param name="paymentClient">Cliente de MercadoPago para operar sobre pagos.</param>
        /// <param name="idPayment">ID del pago a reembolsar.</param>
        /// <param name="reintentos">Cantidad de reintentos realizados (por defecto 0).</param>
        /// <returns>True si el reembolso fue exitoso, false si se agotaron los reintentos.</returns>
        static private async Task<bool> ProcesarReembolsoAsync(PaymentClient paymentClient, long idPayment, int reintentos = 0)
        {

            if (reintentos == 0)
            {
                try
                {
                    Log.Info("Procesando reembolso para el pago con ID: " + idPayment);
                    PaymentRefund refund = await paymentClient.RefundAsync(idPayment);
                    Log.Info($"Estado del reembolso: {refund.Status}");
                }
                catch (MercadoPagoApiException ex)
                {
                    // Maneja los errores de la API de MercadoPago
                    Log.Error("Se produjo un error con la API de Mercado Pago.");
                    Log.Error($"Error: {ex.Message}");
                    Log.Error($"Status Code: {ex.StatusCode}");
                    Log.Error($"Error de API: {ex.ApiError}");
                    Log.Error($"Respuesta de API: {ex.ApiResponse}");
                }
            }
            if (reintentos <= 3)
            {
                if (reintentos > 0)
                {
                    await Task.Delay(60000); // Espera 1 minuto antes de volver a verificar el estado del pago
                    Log.Info($"Reintentando reembolso para el pago con ID: {idPayment}, reintento número: {reintentos}");
                }

                Payment payment = new Payment();

                try
                {
                    payment = await paymentClient.GetAsync(idPayment);                    
                }
                catch (MercadoPagoApiException ex)
                {
                    // Maneja los errores de la API de MercadoPago
                    Log.Error("Se produjo un error con la API de Mercado Pago.");
                    Log.Error($"Error: {ex.Message}");
                    Log.Error($"Status Code: {ex.StatusCode}");
                    Log.Error($"Error de API: {ex.ApiError}");
                    Log.Error($"Respuesta de API: {ex.ApiResponse}");

                    return false;
                }

                Log.Info("Revisando status del pago...");
                Log.Info("Payment Status: " + payment.Status);

                if (payment.Status == PaymentStatus.Refunded)
                {
                    Log.Info("El pago ha sido reembolsado correctamente.");
                    return true;
                }
                else
                {
                    Log.Info("Esperando 1 minuto para obtener estado del pago...");
                    reintentos++;
                    return await ProcesarReembolsoAsync(paymentClient, idPayment, reintentos);
                }
            }
            else
            {
                Log.Info("Número máximo de reintentos alcanzados, Mercado Pago no ha terminado de registrar la devolución...");
                return false;
            }
        }

        private static async Task ProcesarCandidatoDevolucionPagosMixtosAsync(BugsContext db, MercadoPagoTable mercadoPago, Operador operador, Maquina maquina)
        {
            Log.Info($"Pagos mixtos habilitados: iniciando análisis de devolución para comprobante {mercadoPago.Comprobante}.");

            long paymentIdActual = 0;
            if (!long.TryParse(mercadoPago.Comprobante, out paymentIdActual))
            {
                Log.Info($"No se pudo interpretar el comprobante '{mercadoPago.Comprobante}' como identificador numérico; no se ejecuta devolución en flujo mixto.");
                return;
            }

            var operacionMixta = db.MercadoPagoOperacionMixta.FirstOrDefault(x =>
                x.OperadorId == operador.OperadorID &&
                (x.PaymentId1 == paymentIdActual || x.PaymentId2 == paymentIdActual));

            if (operacionMixta == null)
            {
                Log.Info($"Pago no asociado a operación mixta: se procesa devolución estándar para comprobante {paymentIdActual}.");
                await ProcesarDevolucionMercadoPagoAsync(db, mercadoPago, operador, maquina);
                return;
            }

            long? otroPaymentId = null;

            if (operacionMixta.PaymentId1 == paymentIdActual)
            {
                otroPaymentId = operacionMixta.PaymentId2;
            }
            else if (operacionMixta.PaymentId2 == paymentIdActual)
            {
                otroPaymentId = operacionMixta.PaymentId1;
            }

            if (otroPaymentId.HasValue && otroPaymentId.Value > 0)
            {
                Log.Info($"Pago asociado a operación mixta (MercadoPagoOperacionMixtaId={operacionMixta.MercadoPagoOperacionMixtaId}): se devolverán comprobantes {paymentIdActual} y {otroPaymentId.Value}.");
                await ProcesarDevolucionMercadoPagoAsync(db, mercadoPago, operador, maquina);
                await EjecutarRefundMercadoPagoAsync(operador, otroPaymentId.Value);
            }
            else
            {
                Log.Info($"Pago asociado a operación mixta (MercadoPagoOperacionMixtaId={operacionMixta.MercadoPagoOperacionMixtaId}): no se detectó segundo comprobante válido; se devuelve solo {paymentIdActual}.");
                await ProcesarDevolucionMercadoPagoAsync(db, mercadoPago, operador, maquina);
            }
        }

        private static async Task<bool> EjecutarRefundMercadoPagoAsync(Operador operador, long idPayment)
        {
            if (AmbienteConfigHelper.AmbienteSimuladoresHabilitado)
            {
                using (HttpClient httpClient = CreateMpSimulatorHttpClient())
                {
                    return await ProcesarReembolsoSimuladorAsync(httpClient, idPayment);
                }
            }

            MercadoPagoConfig.AccessToken = null;
            MercadoPagoConfig.AccessToken = operador.AccessToken;

            PaymentClient paymentClient = new PaymentClient();
            return await ProcesarReembolsoAsync(paymentClient, idPayment);
        }

        private static HttpClient CreateMpSimulatorHttpClient()
        {
            HttpClient client = new HttpClient();
            client.BaseAddress = new Uri(MpSimulatorBaseUrl);
            client.Timeout = MpSimulatorHttpTimeout;
            return client;
        }

        private static async Task<(bool found, string status)> SimGetPaymentStatusAsync(HttpClient http, long idPayment)
        {
            try
            {
                HttpResponseMessage response = await http.GetAsync($"/v1/payments/{idPayment}");

                if (response.StatusCode == System.Net.HttpStatusCode.NotFound)
                {
                    return (false, null);
                }

                if (!response.IsSuccessStatusCode)
                {
                    Log.Info($"mp_simulator: respuesta inesperada al consultar payment {idPayment}. StatusCode={(int)response.StatusCode}.");
                    return (false, null);
                }

                MpSimulatorPaymentResponse dto = await DeserializeMpSimulatorResponseAsync(response);
                return (true, dto?.Status);
            }
            catch (Exception ex)
            {
                Log.Error($"mp_simulator: error al consultar payment {idPayment}: {ex.Message}");
                return (false, null);
            }
        }

        private static async Task<bool> SimPostRefundAsync(HttpClient http, long idPayment)
        {
            try
            {
                using (var content = new StringContent("{}", Encoding.UTF8, "application/json"))
                {
                    HttpResponseMessage response = await http.PostAsync($"/v1/payments/{idPayment}/refunds", content);
                    if (response.IsSuccessStatusCode)
                    {
                        return true;
                    }

                    Log.Info($"mp_simulator: respuesta inesperada al solicitar refund para {idPayment}. StatusCode={(int)response.StatusCode}.");
                    return false;
                }
            }
            catch (TaskCanceledException ex)
            {
                Log.Info($"mp_simulator: no se obtuvo respuesta al solicitar refund para {idPayment}: {ex.Message}. Se continuará con confirmación por consulta.");
                return false;
            }
            catch (Exception ex)
            {
                Log.Info($"mp_simulator: no se obtuvo respuesta al solicitar refund para {idPayment}: {ex.Message}. Se continuará con confirmación por consulta.");
                return false;
            }
        }

        private static async Task<bool> ProcesarReembolsoSimuladorAsync(HttpClient http, long idPayment, int reintentos = 0)
        {
            if (reintentos == 0)
            {
                Log.Info($"Ambiente simuladores habilitado: solicitando refund en mp_simulator para comprobante {idPayment}.");
                await SimPostRefundAsync(http, idPayment);
            }

            if (reintentos > 0)
            {
                await Task.Delay(60000);
                Log.Info($"Reintentando reembolso para el pago con ID: {idPayment}, reintento número: {reintentos}");
            }

            var estado = await SimGetPaymentStatusAsync(http, idPayment);
            string statusActual = estado.status;

            Log.Info("Revisando status del pago...");
            Log.Info("Payment Status: " + statusActual);

            if (string.Equals(statusActual, "refunded", StringComparison.OrdinalIgnoreCase))
            {
                Log.Info($"mp_simulator: refund confirmado para comprobante {idPayment}.");
                return true;
            }

            if (reintentos >= 3)
            {
                Log.Info($"mp_simulator: no se confirmó refund para comprobante {idPayment} tras {reintentos + 1} intentos.");
                return false;
            }

            Log.Info("Esperando 1 minuto para obtener estado del pago...");
            return await ProcesarReembolsoSimuladorAsync(http, idPayment, reintentos + 1);
        }

        private static async Task<MpSimulatorPaymentResponse> DeserializeMpSimulatorResponseAsync(HttpResponseMessage response)
        {
            using (Stream stream = await response.Content.ReadAsStreamAsync())
            {
                var serializer = new DataContractJsonSerializer(typeof(MpSimulatorPaymentResponse));
                return serializer.ReadObject(stream) as MpSimulatorPaymentResponse;
            }
        }

        [DataContract]
        private class MpSimulatorPaymentResponse
        {
            [DataMember(Name = "id")]
            public long Id { get; set; }

            [DataMember(Name = "status")]
            public string Status { get; set; }
        }

    }
}
