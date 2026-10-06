using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

[Table("companies")]
public class Company
{
    [Key]
    [Column("id")]
    public int Id { get; set; }

    [Required]
    [Column("name")]
    [StringLength(255)]
    public string Name { get; set; } = string.Empty;

    [Column("address")]
    public string? Address { get; set; }

    [Column("phone")]
    [StringLength(50)]
    public string? Phone { get; set; }

    [Column("logo_path")]
    [StringLength(500)]
    public string? LogoPath { get; set; }

    [Column("is_active")]
    public bool IsActive { get; set; } = true;

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.Now;

    [Column("created_by")]
    public int? CreatedBy { get; set; }

    [Column("updated_at")]
    public DateTime? UpdatedAt { get; set; }

    [Column("updated_by")]
    public int? UpdatedBy { get; set; }

    /* Navigation Properties */
    public virtual CompanySetting? CompanySetting { get; set; }
    public virtual ICollection<CompanyLocation> CompanyLocations { get; set; } = new List<CompanyLocation>();
    public virtual ICollection<Role> Roles { get; set; } = new List<Role>();
    public virtual ICollection<Schedule> Schedules { get; set; } = new List<Schedule>();
    public virtual ICollection<Position> Positions { get; set; } = new List<Position>();
    public virtual ICollection<User> Users { get; set; } = new List<User>();
    public virtual ICollection<Announcement> Announcements { get; set; } = new List<Announcement>();
}
