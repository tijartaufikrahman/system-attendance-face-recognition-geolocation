using Microsoft.EntityFrameworkCore;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options)
        : base(options)
    {
    }

    // === Hanya tabel yang ADA di database ===
    public DbSet<PlatformUser> PlatformUser { get; set; }
    public DbSet<Company> Company { get; set; }
    public DbSet<CompanySetting> CompanySetting { get; set; }
    public DbSet<CompanyLocation> CompanyLocation { get; set; }
    public DbSet<Role> Role { get; set; }
    public DbSet<Schedule> Schedule { get; set; }
    public DbSet<Position> Position { get; set; }
    public DbSet<User> User { get; set; }
    public DbSet<Announcement> Announcement { get; set; }
    public DbSet<AnnouncementRead> AnnouncementRead { get; set; }
    public DbSet<Overtime> Overtime { get; set; }
    public DbSet<Attendance> Attendance { get; set; }
    public DbSet<AttendanceAttachment> AttendanceAttachment { get; set; }
    public DbSet<FaceEmbedding> FaceEmbedding { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // CompanySetting -> Company (1-1)
        modelBuilder.Entity<CompanySetting>()
            .HasOne(cs => cs.Company)
            .WithOne(c => c.CompanySetting)
            .HasForeignKey<CompanySetting>(cs => cs.CompanyId);

        // CompanyLocation -> Company
        modelBuilder.Entity<CompanyLocation>()
            .HasOne(cl => cl.Company)
            .WithMany(c => c.CompanyLocations)
            .HasForeignKey(cl => cl.CompanyId);

        // Role -> Company
        modelBuilder.Entity<Role>()
            .HasOne(r => r.Company)
            .WithMany(c => c.Roles)
            .HasForeignKey(r => r.CompanyId);

        // Schedule -> Company
        modelBuilder.Entity<Schedule>()
            .HasOne(s => s.Company)
            .WithMany(c => c.Schedules)
            .HasForeignKey(s => s.CompanyId);

        // Position -> Company
        modelBuilder.Entity<Position>()
            .HasOne(p => p.Company)
            .WithMany(c => c.Positions)
            .HasForeignKey(p => p.CompanyId);

        // Position -> Schedule (default_schedule_id)
        modelBuilder.Entity<Position>()
            .HasOne(p => p.DefaultSchedule)
            .WithMany(s => s.Positions)
            .HasForeignKey(p => p.DefaultScheduleId);

        // User -> Company (required)
        modelBuilder.Entity<User>()
            .HasOne(u => u.Company)
            .WithMany(c => c.Users)
            .HasForeignKey(u => u.CompanyId)
            .OnDelete(DeleteBehavior.Restrict);

        // User -> CompanyLocation
        modelBuilder.Entity<User>()
            .HasOne(u => u.Location)
            .WithMany(cl => cl.Users)
            .HasForeignKey(u => u.LocationId);

        // User -> Role
        modelBuilder.Entity<User>()
            .HasOne(u => u.Role)
            .WithMany(r => r.Users)
            .HasForeignKey(u => u.RoleId);

        // User -> Position
        modelBuilder.Entity<User>()
            .HasOne(u => u.Position)
            .WithMany(p => p.Users)
            .HasForeignKey(u => u.PositionId);

        // User -> Schedule
        modelBuilder.Entity<User>()
            .HasOne(u => u.Schedule)
            .WithMany(s => s.Users)
            .HasForeignKey(u => u.ScheduleId);

        // Announcement -> Company
        modelBuilder.Entity<Announcement>()
            .HasOne(a => a.Company)
            .WithMany(c => c.Announcements)
            .HasForeignKey(a => a.CompanyId);

        modelBuilder.Entity<AnnouncementRead>()
            .HasKey(r => new { r.AnnouncementId, r.UserId });

        // Overtime -> User
        modelBuilder.Entity<Overtime>()
            .HasOne(o => o.User)
            .WithMany(u => u.Overtimes)
            .HasForeignKey(o => o.UserId);

        // Overtime -> Schedule
        modelBuilder.Entity<Overtime>()
            .HasOne(o => o.Schedule)
            .WithMany()
            .HasForeignKey(o => o.ScheduleId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<Overtime>()
            .HasOne<User>()
            .WithMany()
            .HasForeignKey(o => o.RequestedBy)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<Overtime>()
            .HasOne<User>()
            .WithMany()
            .HasForeignKey(o => o.RespondedBy)
            .OnDelete(DeleteBehavior.Restrict);

        // Attendance -> User
        modelBuilder.Entity<Attendance>()
            .HasOne(a => a.User)
            .WithMany(u => u.Attendances)
            .HasForeignKey(a => a.UserId);

        // Attendance -> CompanyLocation
        modelBuilder.Entity<Attendance>()
            .HasOne(a => a.Location)
            .WithMany(cl => cl.Attendances)
            .HasForeignKey(a => a.LocationId);

        // Attendance -> Overtime (absensi khusus sesi lembur)
        modelBuilder.Entity<Attendance>()
            .HasOne(a => a.Overtime)
            .WithMany()
            .HasForeignKey(a => a.OvertimeId)
            .OnDelete(DeleteBehavior.SetNull);

        // AttendanceAttachment -> Attendance
        modelBuilder.Entity<AttendanceAttachment>()
            .HasOne(aa => aa.Attendance)
            .WithMany(a => a.Attachments)
            .HasForeignKey(aa => aa.AttendanceId);

        // FaceEmbedding -> User
        modelBuilder.Entity<FaceEmbedding>()
            .HasOne(fe => fe.User)
            .WithMany(u => u.FaceEmbeddings)
            .HasForeignKey(fe => fe.UserId);

        // Unique constraint on users.email
        modelBuilder.Entity<User>()
            .HasIndex(u => u.Email)
            .IsUnique();

    }
}
