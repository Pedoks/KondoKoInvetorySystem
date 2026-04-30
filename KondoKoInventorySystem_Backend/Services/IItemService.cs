using KondoKoInventorySystem_Backend.DTOs;

namespace KondoKoInventorySystem_Backend.Services;

public interface IItemService
{
    Task<List<ItemResponseDto>> GetAllAsync();
    Task<ItemResponseDto?>      GetByIdAsync(string id);
    Task<ItemResponseDto>       CreateAsync(ItemDto dto);
    Task<ItemResponseDto?>      UpdateAsync(string id, ItemDto dto);
    Task<bool>                  DeleteAsync(string id);
    Task<string>                GetStockStatusAsync(string id); // High / Medium / Low / OutOfStock
}