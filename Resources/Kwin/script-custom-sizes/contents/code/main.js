// KWin Custom Sizes Script
// Assigns shortcuts to resize and center the active window based on your profiles

function getSizes(screenWidth) {
    // Desktop profile sizes (fallback/default for screens >= 2560)
    if (screenWidth >= 2560) {
        return {
            "Small": { w: 1000, h: 650 },
            "Tall":  { w: 1200, h: 1200 },
            "Wide":  { w: 2000, h: 1250 },
            "Boxy":  { w: 1500, h: 950 }
        };
    } 
    // Laptop profile sizes (for screens < 2560)
    else {
        return {
            "Small": { w: 800, h: 575 },
            "Tall":  { w: 900, h: 950 },
            "Wide":  { w: 1850, h: 950 },
            "Boxy":  { w: 900, h: 800 }
        };
    }
}

function applySize(sizeName) {
    var win = workspace.activeWindow;
    if (!win || win.fullScreen || win.maximized) {
        return; // Don't resize fullscreen or maximized windows
    }

    var output = win.output;
    if (!output) {
        return;
    }

    var geom = output.geometry;
    var sizes = getSizes(geom.width);
    var target = sizes[sizeName];

    if (!target) return;

    // Calculate centered position
    var newX = geom.x + Math.round((geom.width - target.w) / 2);
    var newY = geom.y + Math.round((geom.height - target.h) / 2);

    // Apply geometry
    win.frameGeometry = {
        x: newX,
        y: newY,
        width: target.w,
        height: target.h
    };
}

// Register Shortcuts
registerShortcut("CustomSizeSmall", "Resize Window to Small", "Meta+Alt+S", function() {
    applySize("Small");
});

registerShortcut("CustomSizeTall", "Resize Window to Tall", "Meta+Alt+T", function() {
    applySize("Tall");
});

registerShortcut("CustomSizeWide", "Resize Window to Wide", "Meta+Alt+W", function() {
    applySize("Wide");
});

registerShortcut("CustomSizeBoxy", "Resize Window to Boxy", "Meta+Alt+B", function() {
    applySize("Boxy");
});
