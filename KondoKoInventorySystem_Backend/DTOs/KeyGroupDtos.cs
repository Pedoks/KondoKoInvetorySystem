namespace KondoKoInventorySystem_Backend.DTOs;

public class KeyGroupResponseDto
{
    public string GroupId { get; set; } = string.Empty;
    public string OwnersName { get; set; } = string.Empty;
    public string Unit { get; set; } = string.Empty;
    public string UnitStatus { get; set; } = string.Empty;
    public string KeyHolder { get; set; } = string.Empty;
    public string KeyCode { get; set; } = string.Empty;
    public DateTime Date { get; set; }
    public int TotalKeys { get; set; }
    public int AvailableKeys { get; set; }
    public List<string> CheckedOutKeyIds { get; set; } = new(); // ← NEW
    public List<KeyResponseDto> Keys { get; set; } = new();
}

public class AddKeyToGroupDto
{
    public string GroupId { get; set; } = string.Empty;
    public string Barcode { get; set; } = string.Empty;
    public string KeyType { get; set; } = string.Empty;
}