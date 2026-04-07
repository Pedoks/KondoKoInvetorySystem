namespace KondoKoInventorySystem_Backend.DTOs;

public class CheckOutDto
{
    public string Barcode { get; set; } = string.Empty;
}

public class CheckInDto
{
    public string Barcode { get; set; } = string.Empty;
}

public class KeyTransactionResponseDto
{
    public string    Id           { get; set; } = string.Empty;
    public string    KeyId        { get; set; } = string.Empty;
    public string    Barcode      { get; set; } = string.Empty;
    public string    Unit         { get; set; } = string.Empty;
    public string    UserId       { get; set; } = string.Empty;
    public string    UserName     { get; set; } = string.Empty;
    public DateTime  CheckOutDate { get; set; }
    public DateTime? CheckInDate  { get; set; }
    public string    Status       { get; set; } = string.Empty;
}

// Lightweight response for scan lookup
public class KeyScanResultDto
{
    public string KeyId     { get; set; } = string.Empty;
    public string Barcode   { get; set; } = string.Empty;
    public string Unit      { get; set; } = string.Empty;
    public string KeyType   { get; set; } = string.Empty;
    public string Status    { get; set; } = string.Empty; // Available | CheckedOut
    public string? CheckedOutBy { get; set; }
}