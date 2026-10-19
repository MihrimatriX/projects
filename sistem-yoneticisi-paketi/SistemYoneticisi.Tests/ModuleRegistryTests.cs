using SistemYoneticisi.Modules;
using Xunit;

namespace SistemYoneticisi.Tests;

public class ModuleRegistryTests
{
    [Fact]
    public void BuiltInModules_registers_six_modules_in_order()
    {
        var registry = new ModuleRegistry();
        BuiltInModules.RegisterAll(registry);

        Assert.Equal(6, registry.Modules.Count);
        Assert.Equal("Home", registry.Modules[0].Id);
        Assert.Equal("Ana Sayfa", registry.Modules[0].NavLabel);
        Assert.Equal("Dashboard", registry.Modules[1].Id);
        Assert.Equal("Processes", registry.Modules[2].Id);
        Assert.Equal("Services", registry.Modules[3].Id);
        Assert.Equal("Startup", registry.Modules[4].Id);
        Assert.Equal("Network", registry.Modules[5].Id);
    }

    [Fact]
    public void TryGet_is_case_insensitive()
    {
        var registry = new ModuleRegistry();
        BuiltInModules.RegisterAll(registry);

        Assert.True(registry.TryGet("network", out var module));
        Assert.Equal("Network", module.Id);
    }
}
