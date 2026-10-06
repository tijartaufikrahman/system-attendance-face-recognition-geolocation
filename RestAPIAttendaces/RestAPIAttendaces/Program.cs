using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using RestAPIAttendaces.Interfaces;
using RestAPIAttendaces.Services;

var builder = WebApplication.CreateBuilder(args);

// 1. Konfigurasi Database
var conn = builder.Configuration.GetConnectionString("DefaultConnection");
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(conn, sql =>
    {
        sql.EnableRetryOnFailure(
            maxRetryCount: 5,
            maxRetryDelay: TimeSpan.FromSeconds(10),
            errorNumbersToAdd: null);
        sql.CommandTimeout(30);
    }));

// 2. Register Interface -> Repository (DI)
builder.Services.AddScoped<IAuth, AuthRepository>();
builder.Services.AddScoped<ICompany, CompanyRepository>();
builder.Services.AddScoped<IRole, RoleRepository>();
builder.Services.AddScoped<IUser, UserRepository>();
builder.Services.AddScoped<IAttendance, AttendanceRepository>();
builder.Services.AddScoped<ISchedule, ScheduleRepository>();
builder.Services.AddScoped<IPosition, PositionRepository>();
builder.Services.AddScoped<ICompanyLocation, CompanyLocationRepository>();
builder.Services.AddScoped<IAnnouncement, AnnouncementRepository>();
builder.Services.AddScoped<IOvertime, OvertimeRepository>();
builder.Services.AddScoped<IPlatformUser, PlatformUserRepository>();
builder.Services.AddScoped<IEmailService, EmailService>();

// 3. Setup JWT Authentication
var jwtKey = builder.Configuration["Jwt:Key"] ?? "IniKunciRahasiaAttendanceAPI2026YangSangatPanjangSekali123";
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options => {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = builder.Configuration["Jwt:Issuer"],
            ValidAudience = builder.Configuration["Jwt:Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey))
        };
    });

// 4. Setup Controller & JSON
builder.Services.AddControllers()
    .AddJsonOptions(options => {
        options.JsonSerializerOptions.ReferenceHandler = ReferenceHandler.IgnoreCycles;
        options.JsonSerializerOptions.Converters.Add(new TimeSpanJsonConverter());
    });

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.AddSecurityDefinition("Bearer", new Microsoft.OpenApi.Models.OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = Microsoft.OpenApi.Models.SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = Microsoft.OpenApi.Models.ParameterLocation.Header,
        Description = "Masukkan token JWT dengan format: Bearer {token}"
    });

    options.AddSecurityRequirement(new Microsoft.OpenApi.Models.OpenApiSecurityRequirement
    {
        {
            new Microsoft.OpenApi.Models.OpenApiSecurityScheme
            {
                Reference = new Microsoft.OpenApi.Models.OpenApiReference
                {
                    Type = Microsoft.OpenApi.Models.ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            new string[] {}
        }
    });
});
builder.Services.AddHttpClient();

// 5. CORS Policy
builder.Services.AddCors(options => {
    options.AddPolicy("AllowAll", policy => {
        policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod();
    });
});

var app = builder.Build();

// 6. Auto-Seed: Pastikan Superadmin selalu ada dengan password admin123
using (var scope = app.Services.CreateScope())
{
    try
    {
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        db.Database.OpenConnection();
        Console.WriteLine("[DB] Database connected successfully.");
        db.Database.CloseConnection();

        // Auto-migrate: kolom audit dan referensi jadwal lembur jika belum ada
        try
        {
            db.Database.ExecuteSqlRaw("ALTER TABLE overtimes ADD note NVARCHAR(MAX) NULL");
            Console.WriteLine("[MIGRATE] Kolom 'note' ditambahkan ke tabel overtimes.");
        }
        catch { /* Kolom sudah ada, skip */ }
        foreach (var column in new[]
        {
            "request_type VARCHAR(50) NOT NULL DEFAULT 'ADMIN_ASSIGNMENT'",
            "requested_by INT NULL",
            "schedule_id INT NULL",
            "rejection_reason NVARCHAR(MAX) NULL",
            "responded_by INT NULL",
            "responded_at DATETIME2 NULL"
        })
        {
            try
            {
                db.Database.ExecuteSqlRaw("ALTER TABLE overtimes ADD " + column);
                Console.WriteLine($"[MIGRATE] Kolom overtime ditambahkan: {column}");
            }
            catch { /* Kolom sudah ada, skip */ }
        }
        foreach (var statement in new[]
        {
            "IF COL_LENGTH('dbo.overtimes', 'schedule_id') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.overtimes) ALTER TABLE dbo.overtimes ALTER COLUMN schedule_id INT NOT NULL",
            "IF COL_LENGTH('dbo.overtimes', 'schedule_id') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_overtimes_schedules') ALTER TABLE dbo.overtimes ADD CONSTRAINT FK_overtimes_schedules FOREIGN KEY (schedule_id) REFERENCES dbo.schedules(id)"
        })
        {
            try
            {
                db.Database.ExecuteSqlRaw(statement);
                Console.WriteLine($"[MIGRATE] Constraint overtime diterapkan: {statement}");
            }
            catch { /* Skema sudah sesuai atau data lama belum dibersihkan, skip */ }
        }
        foreach (var statement in new[]
        {
            "IF COL_LENGTH('dbo.overtimes', 'start_time') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.overtimes) ALTER TABLE dbo.overtimes DROP COLUMN start_time",
            "IF COL_LENGTH('dbo.overtimes', 'end_time') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.overtimes) ALTER TABLE dbo.overtimes DROP COLUMN end_time",
            "IF COL_LENGTH('dbo.overtimes', 'date_end') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.overtimes) ALTER TABLE dbo.overtimes DROP COLUMN date_end"
        })
        {
            try
            {
                db.Database.ExecuteSqlRaw(statement);
                Console.WriteLine($"[MIGRATE] Kolom legacy overtime dihapus: {statement}");
            }
            catch { /* Kolom tidak ada atau sudah sesuai, skip */ }
        }
        try
        {
            db.Database.ExecuteSqlRaw("ALTER TABLE announcements ADD target_type NVARCHAR(20) NULL DEFAULT 'all'");
            Console.WriteLine("[MIGRATE] Kolom 'target_type' ditambahkan ke tabel announcements.");
        }
        catch { /* Kolom sudah ada, skip */ }
        try
        {
            db.Database.ExecuteSqlRaw("ALTER TABLE announcements ADD target_ids NVARCHAR(MAX) NULL");
            Console.WriteLine("[MIGRATE] Kolom 'target_ids' ditambahkan ke tabel announcements.");
        }
        catch { /* Kolom sudah ada, skip */ }
        foreach (var column in new[]
        {
            "attendance_type VARCHAR(20) NULL",
            "latitude DECIMAL(10,7) NULL",
            "longitude DECIMAL(10,7) NULL",
            "accuracy_meters FLOAT NULL",
            "distance_meters FLOAT NULL",
            "face_similarity FLOAT NULL",
            "face_verified BIT NOT NULL DEFAULT 0",
            "liveness_verified BIT NOT NULL DEFAULT 0",
            "company_tolerance FLOAT NULL",
            "overtime_id INT NULL"
        })
        {
            try
            {
                db.Database.ExecuteSqlRaw($"ALTER TABLE attendances ADD {column}");
                Console.WriteLine($"[MIGRATE] Kolom attendance ditambahkan: {column}");
            }
            catch { /* Kolom sudah ada, skip */ }
        }
        foreach (var statement in new[]
        {
            "IF COL_LENGTH('dbo.attendances', 'attendance_type') IS NOT NULL AND COL_LENGTH('dbo.attendances', 'is_overtime') IS NOT NULL UPDATE dbo.attendances SET attendance_type = CASE WHEN is_overtime = 1 THEN 'OVERTIME' ELSE 'REGULAR' END WHERE attendance_type IS NULL",
            "IF COL_LENGTH('dbo.attendances', 'attendance_type') IS NOT NULL UPDATE dbo.attendances SET attendance_type = 'REGULAR' WHERE attendance_type IS NULL",
            "IF COL_LENGTH('dbo.attendances', 'attendance_type') IS NOT NULL ALTER TABLE dbo.attendances ALTER COLUMN attendance_type VARCHAR(20) NOT NULL",
            "IF COL_LENGTH('dbo.attendances', 'is_overtime') IS NOT NULL ALTER TABLE dbo.attendances DROP COLUMN is_overtime"
        })
        {
            try
            {
                db.Database.ExecuteSqlRaw(statement);
                Console.WriteLine($"[MIGRATE] Skema attendance diperbarui: {statement}");
            }
            catch { /* Data/schema sudah sesuai atau migration perlu dijalankan ulang setelah dependensi selesai */ }
        }
        try
        {
            db.Database.ExecuteSqlRaw("""
                IF OBJECT_ID('dbo.announcement_reads', 'U') IS NULL
                BEGIN
                    CREATE TABLE dbo.announcement_reads (
                        announcement_id INT NOT NULL,
                        user_id INT NOT NULL,
                        read_at DATETIME2 NOT NULL DEFAULT GETDATE(),
                        CONSTRAINT PK_announcement_reads PRIMARY KEY (announcement_id, user_id),
                        CONSTRAINT FK_announcement_reads_announcements FOREIGN KEY (announcement_id) REFERENCES dbo.announcements(id) ON DELETE CASCADE,
                        CONSTRAINT FK_announcement_reads_users FOREIGN KEY (user_id) REFERENCES dbo.users(id) ON DELETE CASCADE
                    )
                END
                """);
        }
        catch { /* Table is already available or will be created on the next startup. */ }

    // Seed hanya jika kosong
    if (!db.PlatformUser.Any())
    {
        db.PlatformUser.Add(new PlatformUser
        {
            Name = "Super Admin System",
            Email = "superadmin@system.com",
            Password = BCrypt.Net.BCrypt.HashPassword("admin123"),
            IsActive = true,
            CreatedAt = DateTime.Now
        });
        db.SaveChanges();
        Console.WriteLine("[SEED] Superadmin platform_user created.");
    }
    else
    {
        Console.WriteLine($"[DB] Database ready. PlatformUsers: {db.PlatformUser.Count()}, Companies: {db.Company.Count()}, Users: {db.User.Count()}");
    }
    }
    catch (Exception ex)
    {
        Console.WriteLine($"[DB ERROR] {ex.Message}");
        Console.WriteLine("[DB] Pastikan database server berjalan dan connection string benar.");
    }
}

// 7. Middleware Pipeline
app.UseSwagger();
app.UseSwaggerUI();
app.UseCors("AllowAll");
app.UseStaticFiles();

app.UseAuthentication(); // CEK TOKEN
app.UseAuthorization();  // CEK HAK AKSES

app.MapControllers();
app.Run();

public class TimeSpanJsonConverter : JsonConverter<TimeSpan>
{
    public override TimeSpan Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        var value = reader.GetString();
        if (!string.IsNullOrEmpty(value))
        {
            if (TimeSpan.TryParse(value, out var timeSpan))
                return timeSpan;

            // Handle formats like "8:00", "08:00", "8:00:00"
            if (DateTime.TryParse(value, out var dt))
                return dt.TimeOfDay;
        }
        return TimeSpan.Zero;
    }

    public override void Write(Utf8JsonWriter writer, TimeSpan value, JsonSerializerOptions options)
    {
        writer.WriteStringValue(value.ToString(@"hh\:mm\:ss"));
    }
}
