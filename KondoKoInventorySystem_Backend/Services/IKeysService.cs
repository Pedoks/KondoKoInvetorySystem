using KondoKoInventorySystem_Backend.DTOs;

namespace KondoKoInventorySystem_Backend.Services;

public interface IKeysService
{
    Task<List<KeyResponseDto>> GetAllAsync();
    Task<KeyResponseDto?>      GetByIdAsync(string id);
    Task<KeyResponseDto>       CreateAsync(KeyDto dto);
    Task<KeyResponseDto?>      UpdateAsync(string id, KeyDto dto);
    Task<bool>                 DeleteAsync(string id);
}