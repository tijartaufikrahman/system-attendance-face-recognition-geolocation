using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

[Table("attendances")]
public class Attendance
{
    [Key]
    [Column("id")]
    public int Id { get; set; }

    [Column("user_id")]
    public int UserId { get; set; }

    [Column("location_id")]
    public int? LocationId { get; set; }

    [Column("date")]
    public DateTime Date { get; set; }

    [Required]
    [Column("attendance_type")]
    [StringLength(20)]
    public string AttendanceType { get; set; } = "REGULAR";

    [Column("clock_in")]
    public DateTime? ClockIn { get; set; }

    [Column("clock_out")]
    public DateTime? ClockOut { get; set; }

    [Required]
    [Column("status")]
    [StringLength(50)]
    public string Status { get; set; } = string.Empty;

    [Column("note")]
    public string? Note { get; set; }

    [Column("latitude", TypeName = "decimal(10, 7)")]
    public decimal? Latitude { get; set; }

    [Column("longitude", TypeName = "decimal(10, 7)")]
    public decimal? Longitude { get; set; }

    [Column("accuracy_meters")]
    public double? AccuracyMeters { get; set; }

    [Column("distance_meters")]
    public double? DistanceMeters { get; set; }

    [Column("face_similarity")]
    public double? FaceSimilarity { get; set; }

    [Column("face_verified")]
    public bool FaceVerified { get; set; }

    [Column("liveness_verified")]
    public bool LivenessVerified { get; set; }

    [Column("company_tolerance")]
    public double? CompanyTolerance { get; set; }

    // Menautkan absensi ini ke tugas lembur tertentu (jika absen untuk sesi lembur, bukan jam kerja reguler)
    [Column("overtime_id")]
    public int? OvertimeId { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.Now;

    [Column("created_by")]
    public int? CreatedBy { get; set; }

    [Column("updated_at")]
    public DateTime? UpdatedAt { get; set; }

    [Column("updated_by")]
    public int? UpdatedBy { get; set; }

    /* Navigation Properties */
    [ForeignKey(nameof(UserId))]
    public virtual User? User { get; set; }

    [ForeignKey(nameof(LocationId))]
    public virtual CompanyLocation? Location { get; set; }

    [ForeignKey(nameof(OvertimeId))]
    public virtual Overtime? Overtime { get; set; }

    public virtual ICollection<AttendanceAttachment> Attachments { get; set; } = new List<AttendanceAttachment>();
}
