using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

[Table("users")]
public class User
{
    [Key]
    [Column("id")]
    public int Id { get; set; }

    [Column("company_id")]
    public int CompanyId { get; set; }

    [Column("location_id")]
    public int? LocationId { get; set; }

    [Column("role_id")]
    public int RoleId { get; set; }

    [Column("position_id")]
    public int? PositionId { get; set; }

    [Column("schedule_id")]
    public int? ScheduleId { get; set; }

    [Required]
    [Column("name")]
    [StringLength(255)]
    public string Name { get; set; } = string.Empty;

    [Required]
    [Column("email")]
    [StringLength(255)]
    public string Email { get; set; } = string.Empty;

    [Column("password")]
    [StringLength(255)]
    public string? Password { get; set; }

    [Column("is_active")]
    public bool IsActive { get; set; } = true;

    [Column("token_at")]
    public string? TokenAt { get; set; }

    [Column("token_expired_at")]
    public DateTime? TokenExpiredAt { get; set; }

    [Column("last_login_at")]
    public DateTime? LastLoginAt { get; set; }

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

    [ForeignKey(nameof(LocationId))]
    public virtual CompanyLocation? Location { get; set; }

    [ForeignKey(nameof(RoleId))]
    public virtual Role? Role { get; set; }

    [ForeignKey(nameof(PositionId))]
    public virtual Position? Position { get; set; }

    [ForeignKey(nameof(ScheduleId))]
    public virtual Schedule? Schedule { get; set; }

    public virtual ICollection<Overtime> Overtimes { get; set; } = new List<Overtime>();
    public virtual ICollection<Attendance> Attendances { get; set; } = new List<Attendance>();
    public virtual ICollection<FaceEmbedding> FaceEmbeddings { get; set; } = new List<FaceEmbedding>();
}
