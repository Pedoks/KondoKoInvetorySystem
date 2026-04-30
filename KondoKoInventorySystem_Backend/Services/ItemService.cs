using KondoKoInventorySystem_Backend.Data;
using KondoKoInventorySystem_Backend.DTOs;
using KondoKoInventorySystem_Backend.Models;
using MongoDB.Driver;

namespace KondoKoInventorySystem_Backend.Services;

public class ItemService : IItemService
{
    private readonly MongoDbContext _context;

    public ItemService(MongoDbContext context)
    {
        _context = context;
    }

    public async Task<List<ItemResponseDto>> GetAllAsync()
    {
        var items = await _context.Items.Find(_ => true).ToListAsync();
        return items.Select(MapToResponse).ToList();
    }

    public async Task<ItemResponseDto?> GetByIdAsync(string id)
    {
        var item = await _context.Items.Find(i => i.Id == id).FirstOrDefaultAsync();
        return item == null ? null : MapToResponse(item);
    }

    public async Task<ItemResponseDto> CreateAsync(ItemDto dto)
    {
        // Barcode uniqueness check for NonConsumable
        if (!string.IsNullOrWhiteSpace(dto.Barcode))
        {
            var existing = await _context.Items
                .Find(i => i.Barcode == dto.Barcode)
                .FirstOrDefaultAsync();

            if (existing != null)
                throw new InvalidOperationException(
                    $"Barcode '{dto.Barcode}' already exists.");
        }

        var item = new Item
        {
            Barcode     = dto.Barcode,
            ItemName    = dto.ItemName,
            ItemType    = dto.ItemType,
            Quantity    = dto.Quantity,
            MinStock    = dto.MinStock,
            MaxStock    = dto.MaxStock,
            Description = dto.Description,
            ImageUrl    = dto.ImageUrl,
            Date        = dto.Date
        };

        await _context.Items.InsertOneAsync(item);
        return MapToResponse(item);
    }

    public async Task<ItemResponseDto?> UpdateAsync(string id, ItemDto dto)
    {
        var update = Builders<Item>.Update
            .Set(i => i.Barcode,     dto.Barcode)
            .Set(i => i.ItemName,    dto.ItemName)
            .Set(i => i.ItemType,    dto.ItemType)
            .Set(i => i.Quantity,    dto.Quantity)
            .Set(i => i.MinStock,    dto.MinStock)
            .Set(i => i.MaxStock,    dto.MaxStock)
            .Set(i => i.Description, dto.Description)
            .Set(i => i.ImageUrl,    dto.ImageUrl)
            .Set(i => i.Date,        dto.Date);

        var result = await _context.Items.UpdateOneAsync(i => i.Id == id, update);
        if (result.MatchedCount == 0) return null;

        return await GetByIdAsync(id);
    }

    public async Task<bool> DeleteAsync(string id)
    {
        var result = await _context.Items.DeleteOneAsync(i => i.Id == id);
        return result.DeletedCount > 0;
    }

    public async Task<string> GetStockStatusAsync(string id)
    {
        var item = await _context.Items.Find(i => i.Id == id).FirstOrDefaultAsync();
        if (item == null) return "Unknown";
        return ComputeStockStatus(item);
    }

    // ── Helpers ───────────────────────────────────────────
    private static string ComputeStockStatus(Item item)
    {
        if (item.ItemType == "NonConsumable") return "High"; // Always in stock if exists

        if (item.Quantity == 0)
            return "OutOfStock";
        if (item.Quantity <= item.MinStock)
            return "Low";
        if (item.Quantity <= item.MaxStock * 0.5)
            return "Medium";
        return "High";
    }

    private static ItemResponseDto MapToResponse(Item item) => new()
    {
        Id          = item.Id ?? "",
        Barcode     = item.Barcode,
        ItemName    = item.ItemName,
        ItemType    = item.ItemType,
        Quantity    = item.Quantity,
        MinStock    = item.MinStock,
        MaxStock    = item.MaxStock,
        Description = item.Description,
        ImageUrl    = item.ImageUrl,
        Date        = item.Date,
        StockStatus = ComputeStockStatus(item)
    };
}