using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

[Table("attendance_attachments")]
public class AttendanceAttachment
{
    [Key]
    [Column("id")]
    public int Id { get; set; }

    [Column("attendance_id")]
    public int AttendanceId { get; set; }

    [Required]
    [Column("file_path")]
    [StringLength(500)]
    public string FilePath { get; set; } = string.Empty;

    [Column("file_type")]
    [StringLength(100)]
    public string? FileType { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.Now;

    [Column("created_by")]
    public int? CreatedBy { get; set; }

    [Column("updated_at")]
    public DateTime? UpdatedAt { get; set; }

    [Column("updated_by")]
    public int? UpdatedBy { get; set; }

    /* Navigation Property */
    [ForeignKey(nameof(AttendanceId))]
    public virtual Attendance? Attendance { get; set; }
}
