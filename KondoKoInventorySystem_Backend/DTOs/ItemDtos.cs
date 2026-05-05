namespace KondoKoInventorySystem_Backend.DTOs;

public class ItemDto
{
    public string   Barcode          { get; set; } = string.Empty;
    public string   ItemName         { get; set; } = string.Empty;
    public string   ItemType         { get; set; } = string.Empty;

    // ── Unit of Measurement ───────────────────────────
    public string   UnitType         { get; set; } = string.Empty;
    public string   BaseUnit         { get; set; } = "pcs";
    public string   PreferredUnit    { get; set; } = "pcs"; // ← NEW
    public double   ConversionFactor { get; set; } = 1;

    // ── Stock (always in base unit) ───────────────────
    public double   Quantity         { get; set; } = 0;
    public double   MinStock         { get; set; } = 0;
    public double   MaxStock         { get; set; } = 0;

    public string   Description      { get; set; } = string.Empty;
    public string   ImageUrl         { get; set; } = string.Empty;
    public DateTime Date             { get; set; } = DateTime.UtcNow;
}

public class ItemResponseDto
{
    public string   Id               { get; set; } = string.Empty;
    public string   Barcode          { get; set; } = string.Empty;
    public string   ItemName         { get; set; } = string.Empty;
    public string   ItemType         { get; set; } = string.Empty;

    // ── Unit of Measurement ───────────────────────────
    public string   UnitType         { get; set; } = string.Empty;
    public string   BaseUnit         { get; set; } = "pcs";
    public string   PreferredUnit    { get; set; } = "pcs"; // ← NEW
    public double   ConversionFactor { get; set; } = 1;

    // ── Stock (in base unit) ──────────────────────────
    public double   Quantity         { get; set; } = 0;
    public double   MinStock         { get; set; } = 0;
    public double   MaxStock         { get; set; } = 0;

    public string   Description      { get; set; } = string.Empty;
    public string   ImageUrl         { get; set; } = string.Empty;
    public DateTime Date             { get; set; }
    public string   StockStatus      { get; set; } = string.Empty;
}

public class ItemTransactionResponseDto
{
    public string    Id              { get; set; } = string.Empty;
    public string    ItemId          { get; set; } = string.Empty;
    public string    ItemName        { get; set; } = string.Empty;
    public string    UserId          { get; set; } = string.Empty;
    public string    UserName        { get; set; } = string.Empty;
    public string    TransactionType { get; set; } = string.Empty;
    public double    Quantity        { get; set; } = 1;
    public string    BaseUnit        { get; set; } = "pcs";
    public string?   PhotoProofUrl   { get; set; } = null;
    public DateTime  CheckOutDate    { get; set; }
    public DateTime? CheckInDate     { get; set; }
    public string?   Status          { get; set; } = null;
}

public class StockInDto
{
    public string Barcode       { get; set; } = string.Empty;
    public double Quantity      { get; set; } = 1; // already in base unit
    public string PhotoProofUrl { get; set; } = string.Empty;
}

public class StockOutDto
{
    public string Barcode       { get; set; } = string.Empty;
    public double Quantity      { get; set; } = 1; // already in base unit
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
    public string  ItemId        { get; set; } = string.Empty;
    public string  Barcode       { get; set; } = string.Empty;
    public string  ItemName      { get; set; } = string.Empty;
    public string  ItemType      { get; set; } = string.Empty;
    public string  ImageUrl      { get; set; } = string.Empty;
    public string  Status        { get; set; } = string.Empty;
    public string? IssuedTo      { get; set; } = null;
}