using KondoKoInventorySystem_Backend.DTOs;
using KondoKoInventorySystem_Backend.Services;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace KondoKoInventorySystem_Backend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class KeyTransactionsController : ControllerBase
{
    private readonly IKeyTransactionService _service;

    public KeyTransactionsController(IKeyTransactionService service)
    {
        _service = service;
    }

    // GET api/keytransactions/scan/{barcode}
    // Returns key info + current status (Available or CheckedOut)
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

    // POST api/keytransactions/checkout
    [HttpPost("checkout")]
    public async Task<IActionResult> CheckOut([FromBody] CheckOutDto dto)
    {
        var userId   = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "anonymous";
        var userName = User.FindFirstValue(ClaimTypes.GivenName)
                       ?? User.FindFirstValue(ClaimTypes.Email)
                       ?? "Unknown";
        try
        {
            var result = await _service.CheckOutAsync(dto.Barcode, userId, userName);
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

    // POST api/keytransactions/checkin
    [HttpPost("checkin")]
    public async Task<IActionResult> CheckIn([FromBody] CheckInDto dto)
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "anonymous";
        try
        {
            var result = await _service.CheckInAsync(dto.Barcode, userId);
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

    // GET api/keytransactions/my-active
    [HttpGet("my-active")]
    public async Task<IActionResult> GetMyActive()
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "anonymous";
        var result = await _service.GetMyActiveAsync(userId);
        return Ok(result);
    }

    // GET api/keytransactions/my-history
    [HttpGet("my-history")]
    public async Task<IActionResult> GetMyHistory()
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "anonymous";
        var result = await _service.GetMyHistoryAsync(userId);
        return Ok(result);
    }

    // GET api/keytransactions/global-history
    [HttpGet("global-history")]
    public async Task<IActionResult> GetGlobalHistory()
    {
        var result = await _service.GetGlobalHistoryAsync();
        return Ok(result);
    }
}