using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

[Table("company_settings")]
public class CompanySetting
{
    [Key]
    [Column("id")]
    public int Id { get; set; }

    [Column("company_id")]
    public int CompanyId { get; set; }

    [Column("radius_meters")]
    public int RadiusMeters { get; set; } = 50;

    [Column("face_tolerance")]
    public double FaceTolerance { get; set; } = 0.45;

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.Now;

    [Column("created_by")]
    public int? CreatedBy { get; set; }

    [Column("updated_at")]
    public DateTime? UpdatedAt { get; set; }

    [Column("updated_by")]
    public int? UpdatedBy { get; set; }

    /* Navigation Property */
    [ForeignKey(nameof(CompanyId))]
    public virtual Company? Company { get; set; }
}
