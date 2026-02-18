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

using System.Data.SqlClient;
using System.Data;
using MercadoPago.Client.Payment;
using MercadoPago.Error;

[assembly: log4net.Config.XmlConfigurator(Watch = true)]
namespace StockNotifier
{
    class Program
    {
        public static BugsContext db;
        private static readonly log4net.ILog Log =
            log4net.LogManager.GetLogger(System.Reflection.MethodBase.GetCurrentMethod().DeclaringType);

        public static async Task Main(string[] args)
        {
            try
            {
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
                            var operacionMixta = BuscarOperacionMixtaPorPaymentId(db, idPayment);
                            var paymentIdsADevolver = new List<long>();

                            if (operacionMixta != null)
                            {
                                if (operacionMixta.PaymentId1.HasValue)
                                {
                                    paymentIdsADevolver.Add(operacionMixta.PaymentId1.Value);
                                }

                                if (operacionMixta.PaymentId2.HasValue && operacionMixta.PaymentId2.Value != operacionMixta.PaymentId1)
                                {
                                    paymentIdsADevolver.Add(operacionMixta.PaymentId2.Value);
                                }

                                Log.Info($"Pago mixto detectado para Comprobante={mercadoPago.Comprobante}. PaymentIds a devolver: {string.Join(",", paymentIdsADevolver)}");
                            }
                            else
                            {
                                paymentIdsADevolver.Add(idPayment);
                            }

                            foreach (var paymentIdActual in paymentIdsADevolver.Distinct())
                            {
                                Log.Info($"Intentando obtener información de payment para PaymentId={paymentIdActual}...");
                                payment = await paymentClient.GetAsync(paymentIdActual);

                                if (payment != null)
                                {
                                    Log.Info("Comprobante encontrado");

                                    if (payment.Status != PaymentStatus.Refunded)
                                    {
                                        //Procesar reembolso
                                        bool isReembolsadoCorrectamente = await ProcesarReembolsoAsync(paymentClient, paymentIdActual);

                                        if (isReembolsadoCorrectamente)
                                        {
                                            Log.Info($"Refund OK para PaymentId={paymentIdActual}");
                                            Log.Info("Actualizando registro en MercadoPagoTable");
                                            //mercadoPago.Descripcion = "Envio ok.";
                                            mercadoPago.MercadoPagoEstadoTransmisionId = (int)MercadoPagoEstadoTransmision.States.ERROR_CONEXION;
                                            mercadoPago.MercadoPagoEstadoFinancieroId = (int)MercadoPagoEstadoFinanciero.States.DEVUELTO;
                                        }
                                        else
                                        {
                                            string errorMessage = "No se logró realizar la devolución tras 3 intentos. Status Payment: " + payment.Status;
                                            Log.Info($"Refund fallido para PaymentId={paymentIdActual}");
                                            Log.Info(errorMessage);
                                            payment = await paymentClient.GetAsync(paymentIdActual);
                                            mercadoPago.MercadoPagoEstadoTransmisionId = (int)MercadoPagoEstadoTransmision.States.ERROR_CONEXION;
                                            mercadoPago.MercadoPagoEstadoFinancieroId = (int)MercadoPagoEstadoFinanciero.States.AVISO_FALLIDO;
                                            mercadoPago.Descripcion = errorMessage;
                                        }

                                        db.Entry(mercadoPago).State = EntityState.Modified;
                                        db.SaveChanges();
                                    }
                                    else
                                    {
                                        Log.Info($"El pago ya ha sido reembolsado anteriormente, no se realizará otra devolución. PaymentId={paymentIdActual}");
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
                                    Log.Info($"No se encontro el pago para PaymentId={paymentIdActual}");
                                }
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

                Log.Info("Control Devoluciones Mixtas Parciales");

                int umbralMixtoMinutos = ObtenerUmbralMixtoParcialMinutos();
                DateTime limiteMixto = DateTime.UtcNow.AddMinutes(-umbralMixtoMinutos);

                var operacionesMixtasParciales = db.MercadoPagoOperacionMixta
                    .Where(x => !x.Cerrada
                        && x.PaymentId1 != null
                        && x.ApprovedCount >= 1
                        && x.FechaUltimaActualizacionUtc <= limiteMixto)
                    .ToList();

                foreach (var operacionMixta in operacionesMixtasParciales)
                {
                    Log.Info($"Operacion mixta parcial detectada. OperadorId={operacionMixta.OperadorId} ExternalReference={operacionMixta.ExternalReference} ApprovedCount={operacionMixta.ApprovedCount} PaymentId1={operacionMixta.PaymentId1} PaymentId2={operacionMixta.PaymentId2} FechaUltimaActualizacionUtc={operacionMixta.FechaUltimaActualizacionUtc}");

                    var paymentIds = new List<long>();
                    if (operacionMixta.PaymentId1.HasValue)
                    {
                        paymentIds.Add(operacionMixta.PaymentId1.Value);
                    }

                    if (operacionMixta.PaymentId2.HasValue && operacionMixta.PaymentId2.Value != operacionMixta.PaymentId1)
                    {
                        paymentIds.Add(operacionMixta.PaymentId2.Value);
                    }

                    var paymentIdsPendientes = paymentIds
                        .Distinct()
                        .Where(id => !db.MercadoPagoTable.Any(mp => mp.Comprobante == id.ToString()))
                        .ToList();

                    if (!paymentIdsPendientes.Any())
                    {
                        Log.Info($"Operacion mixta parcial sin payments pendientes de devolución. OperadorId={operacionMixta.OperadorId} ExternalReference={operacionMixta.ExternalReference}");
                    }
                    else
                    {
                        Operador operadorMixto = db.Operadores.FirstOrDefault(x => x.OperadorID == operacionMixta.OperadorId);

                        if (operadorMixto == null)
                        {
                            Log.Info($"No se encontro operador para operacion mixta parcial. OperadorId={operacionMixta.OperadorId}");
                        }
                        else if (string.IsNullOrWhiteSpace(operadorMixto.AccessToken))
                        {
                            Log.Info($"Operador sin AccessToken para operacion mixta parcial. OperadorId={operacionMixta.OperadorId}");
                        }
                        else
                        {
                            MercadoPagoConfig.AccessToken = null;
                            MercadoPagoConfig.AccessToken = operadorMixto.AccessToken;

                            PaymentClient paymentClient = new PaymentClient();

                            foreach (var paymentId in paymentIdsPendientes)
                            {
                                try
                                {
                                    Log.Info($"Intentando obtener información de payment para PaymentId={paymentId} (mixto parcial)...");
                                    Payment payment = await paymentClient.GetAsync(paymentId);

                                    if (payment != null)
                                    {
                                        Log.Info("Comprobante encontrado");

                                        if (payment.Status != PaymentStatus.Refunded)
                                        {
                                            bool isReembolsadoCorrectamente = await ProcesarReembolsoAsync(paymentClient, paymentId);

                                            if (isReembolsadoCorrectamente)
                                            {
                                                Log.Info($"Refund OK para PaymentId={paymentId} (mixto parcial)");
                                            }
                                            else
                                            {
                                                Log.Info($"Refund fallido para PaymentId={paymentId} (mixto parcial)");
                                            }
                                        }
                                        else
                                        {
                                            Log.Info($"El pago ya ha sido reembolsado anteriormente. PaymentId={paymentId} (mixto parcial)");
                                        }
                                    }
                                    else
                                    {
                                        Log.Info($"No se encontro el pago para PaymentId={paymentId} (mixto parcial)");
                                    }
                                }
                                catch (MercadoPagoApiException ex)
                                {
                                    Log.Error("Se produjo un error con la API de Mercado Pago.");
                                    Log.Error($"Error: {ex.Message}");
                                    Log.Error($"Status Code: {ex.StatusCode}");
                                    Log.Error($"Error de API: {ex.ApiError}");
                                    Log.Error($"Respuesta de API: {ex.ApiResponse}");
                                }
                            }
                        }
                    }

                    operacionMixta.Cerrada = true;
                    operacionMixta.FechaCierreUtc = DateTime.UtcNow;
                    operacionMixta.FechaUltimaActualizacionUtc = DateTime.UtcNow;
                    db.Entry(operacionMixta).State = EntityState.Modified;
                    db.SaveChanges();
                    Log.Info($"Operacion mixta parcial cerrada. OperadorId={operacionMixta.OperadorId} ExternalReference={operacionMixta.ExternalReference}");
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

        private static MercadoPagoOperacionMixta BuscarOperacionMixtaPorPaymentId(BugsContext context, long paymentId)
        {
            return context.MercadoPagoOperacionMixta
                .FirstOrDefault(x => x.PaymentId1 == paymentId || x.PaymentId2 == paymentId);
        }

        private static int ObtenerUmbralMixtoParcialMinutos()
        {
            int umbralMinutos = 15;
            string valorConfig = ConfigurationManager.AppSettings["MixedPartialRefundMinutes"];

            if (!string.IsNullOrWhiteSpace(valorConfig) && int.TryParse(valorConfig, out int umbralConfig))
            {
                umbralMinutos = umbralConfig;
            }

            return umbralMinutos;
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

    }
}
