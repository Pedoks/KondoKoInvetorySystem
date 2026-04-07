using KondoKoInventorySystem_Backend.DTOs;

namespace KondoKoInventorySystem_Backend.Services;

public interface IAuthService
{
    Task<AuthResponseDto?> RegisterAsync(RegisterDto dto);
    Task<AuthResponseDto?> LoginAsync(LoginDto dto);
}