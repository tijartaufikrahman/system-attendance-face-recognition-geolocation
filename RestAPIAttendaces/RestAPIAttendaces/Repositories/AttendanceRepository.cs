using Microsoft.EntityFrameworkCore;
using RestAPIAttendaces.Interfaces;

public class AttendanceRepository : IAttendance
{
    private readonly AppDbContext _context;

    public AttendanceRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<List<Attendance>> GetAll()
    {
        return await _context.Attendance.ToListAsync();
    }

    public async Task<Attendance?> GetById(int id)
    {
        return await _context.Attendance.FindAsync(id);
    }

    public async Task<List<Attendance>> GetByUserId(int userId)
    {
        return await _context.Attendance.Where(a => a.UserId == userId).ToListAsync();
    }

    public async Task<Attendance> Create(Attendance attendance)
    {
        attendance.CreatedAt = DateTime.Now;
        _context.Attendance.Add(attendance);
        await _context.SaveChangesAsync();
        return attendance;
    }

    public async Task<bool> Update(int id, Attendance attendance)
    {
        var existing = await _context.Attendance.FindAsync(id);
        if (existing == null) return false;

        existing.UserId = attendance.UserId;
        existing.LocationId = attendance.LocationId;
        existing.Date = attendance.Date;
        existing.AttendanceType = attendance.AttendanceType;
        existing.ClockIn = attendance.ClockIn;
        existing.ClockOut = attendance.ClockOut;
        existing.Status = attendance.Status;
        existing.Note = attendance.Note;
        existing.Latitude = attendance.Latitude;
        existing.Longitude = attendance.Longitude;
        existing.AccuracyMeters = attendance.AccuracyMeters;
        existing.DistanceMeters = attendance.DistanceMeters;
        existing.FaceSimilarity = attendance.FaceSimilarity;
        existing.FaceVerified = attendance.FaceVerified;
        existing.LivenessVerified = attendance.LivenessVerified;
        existing.CompanyTolerance = attendance.CompanyTolerance;
        existing.OvertimeId = attendance.OvertimeId;
        existing.UpdatedAt = DateTime.Now;

        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<bool> Delete(int id)
    {
        var existing = await _context.Attendance.FindAsync(id);
        if (existing == null) return false;

        _context.Attendance.Remove(existing);
        await _context.SaveChangesAsync();
        return true;
    }
}
