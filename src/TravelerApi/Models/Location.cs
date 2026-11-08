using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Text.Json.Serialization;

namespace TravelerApi.Models;

[Table("locations")]
public class Location
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [Column("travel_plan_id")]
    public Guid TravelPlanId { get; set; }

    [Required]
    [MaxLength(200)]
    [Column("name")]
    public string Name { get; set; } = string.Empty;

    [Column("address")]
    public string? Address { get; set; }

    [Column("latitude", TypeName = "decimal(10,6)")]
    public decimal? Latitude { get; set; }

    [Column("longitude", TypeName = "decimal(11,6)")]
    public decimal? Longitude { get; set; }

    [Column("visit_order")]
    public int VisitOrder { get; set; }

    [Column("arrival_date")]
    public DateTimeOffset? ArrivalDate { get; set; }

    [Column("departure_date")]
    public DateTimeOffset? DepartureDate { get; set; }

    [Column("budget", TypeName = "decimal(10,2)")]
    public decimal? Budget { get; set; }

    [Column("notes")]
    public string? Notes { get; set; }

    [ConcurrencyCheck]
    [Column("version")]
    public int Version { get; set; } = 1;

    [Column("created_at")]
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;

    [JsonIgnore]
    [ForeignKey(nameof(TravelPlanId))]
    public TravelPlan? TravelPlan { get; set; }
}
