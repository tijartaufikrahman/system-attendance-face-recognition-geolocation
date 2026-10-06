namespace RestAPIAttendaces.Interfaces
{
    public interface IPosition
    {
        Task<List<Position>> GetAll();
        Task<Position?> GetById(int id);
        Task<Position> Create(Position position);
        Task<bool> Update(int id, Position position);
        Task<(bool success, string? error)> Delete(int id);
    }
}
