using KondoKoInventorySystem_Backend.DTOs;

namespace KondoKoInventorySystem_Backend.Services;

public interface IItemTransactionService
{
    Task<ItemTransactionResponseDto>       StockInAsync(string barcode, string userId, string userName, int quantity, string photoProofUrl);
    Task<ItemTransactionResponseDto>       StockOutAsync(string barcode, string userId, string userName, int quantity, string photoProofUrl);
    Task<ItemScanResultDto>                ScanBarcodeAsync(string barcode); // NonConsumable only
    Task<ItemTransactionResponseDto>       IssueItemAsync(string barcode, string userId, string userName);
    Task<ItemTransactionResponseDto>       ReturnItemAsync(string barcode, string userId);
    Task<List<ItemTransactionResponseDto>> GetMyIssuedAsync(string userId);
    Task<List<ItemTransactionResponseDto>> GetMyHistoryAsync(string userId);
    Task<List<ItemTransactionResponseDto>> GetGlobalHistoryAsync();
}