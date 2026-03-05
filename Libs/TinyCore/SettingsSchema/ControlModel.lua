local addonName, addon = ...

addon.TinyCoreSettingsSchemaControlModel = addon.TinyCoreSettingsSchemaControlModel or {}
local ControlModel = addon.TinyCoreSettingsSchemaControlModel

function ControlModel.TrackRuntimeSetting(addonTable, meta)
    if not meta or not meta.key then
        return
    end
    addonTable.RUNTIME_SETTING_REGISTRY = addonTable.RUNTIME_SETTING_REGISTRY or {}
    addonTable.RUNTIME_SETTING_REGISTRY[meta.key] = meta
end
