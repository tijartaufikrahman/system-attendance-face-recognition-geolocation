using Microsoft.EntityFrameworkCore;
using RestAPIAttendaces.Interfaces;

public class OvertimeRepository : IOvertime
{
    private readonly AppDbContext _context;

    public OvertimeRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<List<Overtime>> GetAll(int? companyId = null)
    {
        var query = _context.Overtime
            .Include(o => o.User)
            .Include(o => o.Schedule)
            .AsQueryable();
        if (companyId.HasValue)
            query = query.Where(o => o.User != null && o.User.CompanyId == companyId.Value);
        return await query.OrderByDescending(o => o.CreatedAt).ToListAsync();
    }

    public async Task<Overtime?> GetById(int id)
    {
        return await _context.Overtime
            .Include(o => o.User)
            .Include(o => o.Schedule)
            .FirstOrDefaultAsync(o => o.Id == id);
    }

    public async Task<List<Overtime>> GetByUserId(int userId, int? companyId = null)
    {
        var query = _context.Overtime
            .Include(o => o.User)
            .Include(o => o.Schedule)
            .Where(o => o.UserId == userId);
        if (companyId.HasValue)
            query = query.Where(o => o.User != null && o.User.CompanyId == companyId.Value);
        return await query
            .OrderByDescending(o => o.Date)
            .ToListAsync();
    }

    public async Task<Overtime> Create(Overtime overtime)
    {
        overtime.CreatedAt = DateTime.Now;
        _context.Overtime.Add(overtime);
        await _context.SaveChangesAsync();
        return overtime;
    }

    public async Task<bool> Update(int id, Overtime overtime)
    {
        var existing = await _context.Overtime.FindAsync(id);
        if (existing == null) return false;

        existing.UserId = overtime.UserId;
        existing.Date = overtime.Date;
        existing.RequestType = overtime.RequestType;
        existing.RequestedBy = overtime.RequestedBy;
        existing.ScheduleId = overtime.ScheduleId;
        existing.Status = overtime.Status;
        existing.Note = overtime.Note;
        existing.RejectionReason = overtime.RejectionReason;
        existing.RespondedBy = overtime.RespondedBy;
        existing.RespondedAt = overtime.RespondedAt;
        existing.UpdatedAt = DateTime.Now;

        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<bool> Delete(int id)
    {
        var existing = await _context.Overtime.FindAsync(id);
        if (existing == null) return false;

        // Hanya bisa hapus jika status masih menunggu salah satu pihak
        if (!string.Equals(existing.Status, OvertimeStatuses.PENDING_EMPLOYEE, StringComparison.OrdinalIgnoreCase)
            && !string.Equals(existing.Status, OvertimeStatuses.PENDING_SUPERVISOR, StringComparison.OrdinalIgnoreCase))
            return false;

        _context.Overtime.Remove(existing);
        await _context.SaveChangesAsync();
        return true;
    }
}
