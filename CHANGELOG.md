# Changelog (PhobosEPRCleanup)

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog, and this project follows Semantic Versioning.

## [Unreleased]

## [1.0.0] - 2026-02-19

### Added
- Initial release of PhobosEPRCleanup utility mod
- **EPRC_CleanupSystem** (server-side):
  - Restores `ElecShutModifier` and `WaterShutModifier` to pre-EPR values via `getSandboxOptions():set()` + `toLua()` (persisted to disk)
  - Resets `setHasElectricity(false)` and `setHasWater(false)` on EPR-connected buildings
  - Strips all EPR world modData keys: `EPR_GridData`, `EPR_PowerController`, `EPR_GlobalData`, `EGO_GridData`
  - World modData guard flag prevents re-execution
  - `ForceRerun` sandbox option to re-execute if needed
- **EPRC_CleanupNotify** (client-side):
  - Modal dialog with full cleanup summary on completion
  - HaloText green indicator for quick visual feedback
- **Sandbox options**: `RunCleanup` (default ON), `RestoreSandboxVars` (default ON), `ForceRerun` (default OFF)
- Declared `incompatible=\EPR_B42` in mod.info to prevent co-loading with EPR
