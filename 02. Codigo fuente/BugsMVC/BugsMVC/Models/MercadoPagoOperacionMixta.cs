using System;
using System.ComponentModel.DataAnnotations;

namespace BugsMVC.Models
{
    public class MercadoPagoOperacionMixta
    {
        [Key]
        public int MercadoPagoOperacionMixtaId { get; set; }

        [Required]
        public Guid OperadorId { get; set; }

        [Required]
        [StringLength(200)]
        public string ExternalReference { get; set; }

        [Required]
        public DateTime FechaAuthorized { get; set; }

        public decimal MontoAcumulado { get; set; }

        public int ApprovedCount { get; set; }

        public long? PaymentId1 { get; set; }

        public long? PaymentId2 { get; set; }

        public bool Cerrada { get; set; }

        public DateTime? FechaCierre { get; set; }

        [Required]
        public DateTime FechaUltimaActualizacion { get; set; }
    }
}
