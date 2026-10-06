using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

[Table("overtimes")]
public class Overtime
{
    [Key]
    [Column("id")]
    public int Id { get; set; }

    [Column("user_id")]
    public int UserId { get; set; }

    [Column("date")]
    public DateTime Date { get; set; }

    [Required]
    [Column("request_type")]
    [StringLength(50)]
    public string RequestType { get; set; } = OvertimeStatuses.ADMIN_ASSIGNMENT;

    [Column("requested_by")]
    public int? RequestedBy { get; set; }

    [Required]
    [Column("schedule_id")]
    public int ScheduleId { get; set; }

    [Required]
    [Column("status")]
    [StringLength(50)]
    public string Status { get; set; } = OvertimeStatuses.PENDING_EMPLOYEE;

    [Column("note")]
    public string? Note { get; set; }

    [Column("rejection_reason")]
    public string? RejectionReason { get; set; }

    [Column("responded_by")]
    public int? RespondedBy { get; set; }

    [Column("responded_at")]
    public DateTime? RespondedAt { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.Now;

    [Column("created_by")]
    public int? CreatedBy { get; set; }

    [Column("updated_at")]
    public DateTime? UpdatedAt { get; set; }

    [Column("updated_by")]
    public int? UpdatedBy { get; set; }

    /* Navigation Property */
    [ForeignKey(nameof(UserId))]
    public virtual User? User { get; set; }

    [ForeignKey(nameof(ScheduleId))]
    public virtual Schedule? Schedule { get; set; }
}

public static class OvertimeStatuses
{
    public const string PENDING_EMPLOYEE = "PENDING_EMPLOYEE";
    public const string PENDING_SUPERVISOR = "PENDING_SUPERVISOR";
    public const string APPROVED = "APPROVED";
    public const string REJECTED = "REJECTED";
    public const string CANCELLED = "CANCELLED";
    public const string ADMIN_ASSIGNMENT = "ADMIN_ASSIGNMENT";
    public const string EMPLOYEE_REQUEST = "EMPLOYEE_REQUEST";
}
