using KondoKoInventorySystem_Backend.DTOs;

namespace KondoKoInventorySystem_Backend.Services;

public interface IKeyTransactionService
{
    Task<KeyScanResultDto>              ScanBarcodeAsync(string barcode);
    Task<KeyTransactionResponseDto>     CheckOutAsync(string barcode, string userId, string userName);
    Task<KeyTransactionResponseDto>     CheckInAsync(string barcode, string userId);
    Task<List<KeyTransactionResponseDto>> GetMyActiveAsync(string userId);
    Task<List<KeyTransactionResponseDto>> GetMyHistoryAsync(string userId);
    Task<List<KeyTransactionResponseDto>> GetGlobalHistoryAsync();
}