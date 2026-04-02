# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a yabai window manager configuration repository. Yabai is a tiling window manager for macOS that provides advanced window management capabilities through shell script configuration.

## Architecture

The repository contains a single configuration file:

- `yabairc` - Main yabai configuration script that sets up window management behavior, visual styling, and application-specific rules

## Configuration Structure

The yabairc file is organized into three main sections:

1. **Global Settings** (lines 4-24): Core window management behavior including focus, opacity, borders, and mouse interactions
2. **Space Settings** (lines 27-32): Layout type (BSP - Binary Space Partitioning) and padding/gap configurations  
3. **Application Rules** (lines 35-46): Per-application window management overrides for apps that should float or have special behavior

## Key Configuration Details

- Uses BSP (Binary Space Partitioning) layout for automatic window tiling
- Window opacity: 85% for normal windows, 100% for active window
- Border styling with Nordic blue color scheme (0xFF88C0D0)
- Mouse modifier key: `fn` for window manipulation
- Specific rules disable tiling for system apps, floating windows, and utility apps

## Common Operations

- **Reload configuration**: `yabai --restart-service` or restart yabai service
- **Test configuration**: Execute `./yabairc` directly to apply settings
- **Validate syntax**: Check shell script syntax with `sh -n yabairc`

## Application Rules Pattern

Rules follow the pattern: `yabai -m rule --add app="^AppName$" [options]`
Common options include `manage=off` (disable tiling), `layer=above/below`, and `sticky=on`.