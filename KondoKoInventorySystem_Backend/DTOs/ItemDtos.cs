namespace KondoKoInventorySystem_Backend.DTOs;

public class ItemDto
{
    public string Barcode      { get; set; } = string.Empty;
    public string ItemName     { get; set; } = string.Empty;
    public string ItemType     { get; set; } = string.Empty; // "Consumable" or "NonConsumable"
    public int    Quantity     { get; set; } = 0;
    public int    MinStock     { get; set; } = 0;
    public int    MaxStock     { get; set; } = 0;
    public string Description  { get; set; } = string.Empty;
    public string ImageUrl     { get; set; } = string.Empty;
    public DateTime Date       { get; set; } = DateTime.UtcNow;
}

public class ItemResponseDto
{
    public string   Id          { get; set; } = string.Empty;
    public string   Barcode     { get; set; } = string.Empty;
    public string   ItemName    { get; set; } = string.Empty;
    public string   ItemType    { get; set; } = string.Empty;
    public int      Quantity    { get; set; } = 0;
    public int      MinStock    { get; set; } = 0;
    public int      MaxStock    { get; set; } = 0;
    public string   Description { get; set; } = string.Empty;
    public string   ImageUrl    { get; set; } = string.Empty;
    public DateTime Date        { get; set; }
    public string   StockStatus { get; set; } = string.Empty; // High / Medium / Low / OutOfStock
}

public class ItemTransactionResponseDto
{
    public string    Id              { get; set; } = string.Empty;
    public string    ItemId          { get; set; } = string.Empty;
    public string    ItemName        { get; set; } = string.Empty;
    public string    UserId          { get; set; } = string.Empty;
    public string    UserName        { get; set; } = string.Empty;
    public string    TransactionType { get; set; } = string.Empty;
    public int       Quantity        { get; set; } = 1;
    public string?   PhotoProofUrl   { get; set; } = null;
    public DateTime  CheckOutDate    { get; set; }
    public DateTime? CheckInDate     { get; set; }
    public string?   Status         { get; set; } = null;
}

public class StockInDto
{
    public string Barcode       { get; set; } = string.Empty;
    public int    Quantity      { get; set; } = 1;
    public string PhotoProofUrl { get; set; } = string.Empty;
}

public class StockOutDto
{
    public string Barcode       { get; set; } = string.Empty;
    public int    Quantity      { get; set; } = 1;
    public string PhotoProofUrl { get; set; } = string.Empty;
}

public class IssueItemDto
{
    public string Barcode { get; set; } = string.Empty;
}

public class ReturnItemDto
{
    public string Barcode { get; set; } = string.Empty;
}

public class ItemScanResultDto
{
    public string  ItemId    { get; set; } = string.Empty;
    public string  Barcode   { get; set; } = string.Empty;
    public string  ItemName  { get; set; } = string.Empty;
    public string  ItemType  { get; set; } = string.Empty;
    public string  ImageUrl  { get; set; } = string.Empty;
    public string  Status    { get; set; } = string.Empty; // "Available" | "Issued"
    public string? IssuedTo  { get; set; } = null;
}