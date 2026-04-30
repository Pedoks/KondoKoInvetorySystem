using KondoKoInventorySystem_Backend.DTOs;
using KondoKoInventorySystem_Backend.Services;
using Microsoft.AspNetCore.Mvc;

namespace KondoKoInventorySystem_Backend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ItemsController : ControllerBase
{
    private readonly IItemService _itemService;

    public ItemsController(IItemService itemService)
    {
        _itemService = itemService;
    }

    // GET api/items
    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var items = await _itemService.GetAllAsync();
        return Ok(items);
    }

    // GET api/items/{id}
    [HttpGet("{id}")]
    public async Task<IActionResult> GetById(string id)
    {
        var item = await _itemService.GetByIdAsync(id);
        if (item == null) return NotFound(new { message = "Item not found." });
        return Ok(item);
    }

    // POST api/items
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] ItemDto dto)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        try
        {
            var created = await _itemService.CreateAsync(dto);
            return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }

    // PUT api/items/{id}
    [HttpPut("{id}")]
    public async Task<IActionResult> Update(string id, [FromBody] ItemDto dto)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var updated = await _itemService.UpdateAsync(id, dto);
        if (updated == null) return NotFound(new { message = "Item not found." });
        return Ok(updated);
    }

    // DELETE api/items/{id}
    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(string id)
    {
        var deleted = await _itemService.DeleteAsync(id);
        if (!deleted) return NotFound(new { message = "Item not found." });
        return Ok(new { message = "Item deleted successfully." });
    }
}