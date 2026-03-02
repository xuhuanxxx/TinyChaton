local addonName, addon = ...

addon.PERFORMANCE_BUDGET = {
    ["ChatGateway.Inbound.Allow"] = 0.1,
    ["ChatGateway.Display.Transform"] = 1.0,
    ["ChatPipeline.Middleware.BLOCK"] = 0.5,
    ["ChatPipeline.Middleware.PERSIST"] = 2.0,
    ["ShelfService.RefreshShelf"] = 10,
}
