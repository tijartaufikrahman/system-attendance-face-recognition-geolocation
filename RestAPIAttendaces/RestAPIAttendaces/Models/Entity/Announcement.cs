using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

[Table("announcements")]
public class Announcement
{
    [Key]
    [Column("id")]
    public int Id { get; set; }

    [Column("company_id")]
    public int CompanyId { get; set; }

    [Required]
    [Column("title")]
    [StringLength(255)]
    public string? Title { get; set; }

    [Required]
    [Column("content")]
    public string? Content { get; set; }

    // all = semua orang, users = user spesifik, position = per jabatan
    [Column("target_type")]
    [StringLength(20)]
    public string? TargetType { get; set; } = "all";

    // Simpan IDs koma-pisah: "1,2,3" (user IDs atau position IDs)
    [Column("target_ids")]
    public string? TargetIds { get; set; }

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
}
