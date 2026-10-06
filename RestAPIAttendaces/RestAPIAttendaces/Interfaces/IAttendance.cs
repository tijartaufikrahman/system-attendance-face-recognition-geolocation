namespace RestAPIAttendaces.Interfaces
{
    public interface IAttendance
    {
        Task<List<Attendance>> GetAll();
        Task<Attendance?> GetById(int id);
        Task<List<Attendance>> GetByUserId(int userId);
        Task<Attendance> Create(Attendance attendance);
        Task<bool> Update(int id, Attendance attendance);
        Task<bool> Delete(int id);
    }
}
