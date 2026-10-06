using Microsoft.EntityFrameworkCore;
using RestAPIAttendaces.Interfaces;

public class ScheduleRepository : ISchedule
{
    private readonly AppDbContext _context;

    public ScheduleRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<List<Schedule>> GetAll()
    {
        return await _context.Schedule.ToListAsync();
    }

    public async Task<Schedule?> GetById(int id)
    {
        return await _context.Schedule.FindAsync(id);
    }

    public async Task<Schedule> Create(Schedule schedule)
    {
        schedule.CreatedAt = DateTime.Now;
        _context.Schedule.Add(schedule);
        await _context.SaveChangesAsync();
        return schedule;
    }

    public async Task<bool> Update(int id, Schedule schedule)
    {
        var existing = await _context.Schedule.FindAsync(id);
        if (existing == null) return false;

        existing.Name = schedule.Name;
        existing.CompanyId = schedule.CompanyId;
        existing.ClockIn = schedule.ClockIn;
        existing.ClockOut = schedule.ClockOut;
        existing.UpdatedAt = DateTime.Now;

        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<(bool success, string? error)> Delete(int id)
    {
        var existing = await _context.Schedule.FindAsync(id);
        if (existing == null) return (false, "Jam kerja tidak ditemukan");

        // Check if any users reference this schedule
        var hasUsers = await _context.User.AnyAsync(u => u.ScheduleId == id);
        if (hasUsers)
            return (false, "Tidak bisa menghapus: masih ada karyawan yang menggunakan jam kerja ini");

        // Check if any positions reference this schedule as default
        var hasPositions = await _context.Position.AnyAsync(p => p.DefaultScheduleId == id);
        if (hasPositions)
            return (false, "Tidak bisa menghapus: masih ada jabatan yang menggunakan jam kerja ini sebagai jadwal default");

        _context.Schedule.Remove(existing);
        await _context.SaveChangesAsync();
        return (true, null);
    }
}
