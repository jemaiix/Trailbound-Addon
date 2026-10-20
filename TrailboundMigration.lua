-- Optional legacy metadata loads the old SavedVariables before this addon.
-- The data keys remain stable; WoW saves them into Trailbound.lua on logout.
function TrailboundPrepareMigration()
 TrailboundMigrationDB=TrailboundMigrationDB or {}
 TrailboundMigrationDB.saved=true
 -- Retain the metadata loader: other characters may still have only old saves.
 -- New Trailbound SavedVariables load after the dependency and take precedence.
 -- No tables are copied, cleared or replaced here.
end
