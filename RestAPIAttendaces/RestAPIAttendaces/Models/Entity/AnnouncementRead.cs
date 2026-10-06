using System.ComponentModel.DataAnnotations.Schema;

[Table("announcement_reads")]
public class AnnouncementRead
{
    [Column("announcement_id")]
    public int AnnouncementId { get; set; }

    [Column("user_id")]
    public int UserId { get; set; }

    [Column("read_at")]
    public DateTime ReadAt { get; set; } = DateTime.Now;
}
