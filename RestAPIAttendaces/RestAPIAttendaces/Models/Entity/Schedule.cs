using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

[Table("schedules")]
public class Schedule
{
    [Key]
    [Column("id")]
    public int Id { get; set; }

    [Column("company_id")]
    public int CompanyId { get; set; }

    [Required]
    [Column("name")]
    [StringLength(100)]
    public string Name { get; set; } = string.Empty;

    [Column("clock_in")]
    public TimeSpan ClockIn { get; set; }

    [Column("clock_out")]
    public TimeSpan ClockOut { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.Now;

    [Column("created_by")]
    public int? CreatedBy { get; set; }

    [Column("updated_at")]
    public DateTime? UpdatedAt { get; set; }

    [Column("updated_by")]
    public int? UpdatedBy { get; set; }

    /* Navigation Properties */
    [ForeignKey(nameof(CompanyId))]
    public virtual Company? Company { get; set; }

    public virtual ICollection<Position> Positions { get; set; } = new List<Position>();
    public virtual ICollection<User> Users { get; set; } = new List<User>();
}
