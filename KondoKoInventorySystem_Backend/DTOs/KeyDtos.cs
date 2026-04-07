namespace KondoKoInventorySystem_Backend.DTOs;

public class KeyDto
{
    public string   Barcode    { get; set; } = string.Empty;
    public string   OwnersName { get; set; } = string.Empty;
    public string   Unit       { get; set; } = string.Empty;
    public string   KeyType    { get; set; } = string.Empty;
    public string   UnitStatus { get; set; } = string.Empty;
    public string   KeyHolder  { get; set; } = string.Empty;
    public string   KeyCode    { get; set; } = string.Empty;
    public DateTime Date       { get; set; } = DateTime.UtcNow;
}

public class KeyResponseDto
{
    public string   Id         { get; set; } = string.Empty;
    public string   Barcode    { get; set; } = string.Empty;
    public string   OwnersName { get; set; } = string.Empty;
    public string   Unit       { get; set; } = string.Empty;
    public string   KeyType    { get; set; } = string.Empty;
    public string   UnitStatus { get; set; } = string.Empty;
    public string   KeyHolder  { get; set; } = string.Empty;
    public string   KeyCode    { get; set; } = string.Empty;
    public DateTime Date       { get; set; }
}