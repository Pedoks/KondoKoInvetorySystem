using KondoKoInventorySystem_Backend.DTOs;
using KondoKoInventorySystem_Backend.Services;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace KondoKoInventorySystem_Backend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ItemTransactionsController : ControllerBase
{
    private readonly IItemTransactionService _service;

    public ItemTransactionsController(IItemTransactionService service)
    {
        _service = service;
    }

    // GET api/itemtransactions/scan/{barcode}
    [HttpGet("scan/{barcode}")]
    public async Task<IActionResult> Scan(string barcode)
    {
        try
        {
            var result = await _service.ScanBarcodeAsync(barcode);
            return Ok(result);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }

    // POST api/itemtransactions/stockin
    [HttpPost("stockin")]
    public async Task<IActionResult> StockIn([FromBody] StockInDto dto)
    {
        var userId   = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "anonymous";
        var userName = User.FindFirstValue(ClaimTypes.GivenName)
                       ?? User.FindFirstValue(ClaimTypes.Email)
                       ?? "Unknown";
        try
        {
            var result = await _service.StockInAsync(
                dto.Barcode, userId, userName, dto.Quantity, dto.PhotoProofUrl);
            return Ok(result);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }

    // POST api/itemtransactions/stockout
    [HttpPost("stockout")]
    public async Task<IActionResult> StockOut([FromBody] StockOutDto dto)
    {
        var userId   = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "anonymous";
        var userName = User.FindFirstValue(ClaimTypes.GivenName)
                       ?? User.FindFirstValue(ClaimTypes.Email)
                       ?? "Unknown";
        try
        {
            var result = await _service.StockOutAsync(
                dto.Barcode, userId, userName, dto.Quantity, dto.PhotoProofUrl);
            return Ok(result);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }

    // POST api/itemtransactions/issue
    [HttpPost("issue")]
    public async Task<IActionResult> Issue([FromBody] IssueItemDto dto)
    {
        var userId   = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "anonymous";
        var userName = User.FindFirstValue(ClaimTypes.GivenName)
                       ?? User.FindFirstValue(ClaimTypes.Email)
                       ?? "Unknown";
        try
        {
            var result = await _service.IssueItemAsync(dto.Barcode, userId, userName);
            return Ok(result);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }

    // POST api/itemtransactions/return
    [HttpPost("return")]
    public async Task<IActionResult> Return([FromBody] ReturnItemDto dto)
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "anonymous";
        try
        {
            var result = await _service.ReturnItemAsync(dto.Barcode, userId);
            return Ok(result);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }

    // GET api/itemtransactions/my-issued
    [HttpGet("my-issued")]
    public async Task<IActionResult> GetMyIssued()
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "anonymous";
        var result = await _service.GetMyIssuedAsync(userId);
        return Ok(result);
    }

    // GET api/itemtransactions/my-history
    [HttpGet("my-history")]
    public async Task<IActionResult> GetMyHistory()
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "anonymous";
        var result = await _service.GetMyHistoryAsync(userId);
        return Ok(result);
    }

    // GET api/itemtransactions/global-history
    [HttpGet("global-history")]
    public async Task<IActionResult> GetGlobalHistory()
    {
        var result = await _service.GetGlobalHistoryAsync();
        return Ok(result);
    }
}