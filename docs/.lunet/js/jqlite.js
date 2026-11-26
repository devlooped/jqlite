// Theme switcher: cycles through system -> light -> dark on a single button, using the same
// storage key and attributes as lunet-io/templates.
(function () {
    const modes = ["system", "light", "dark"];
    const icons = {
        system: "bi-circle-half",
        light: "bi-sun-fill",
        dark: "bi-moon-stars-fill"
    };

    document.addEventListener("DOMContentLoaded", function () {
        const button = document.getElementById("theme-mode-toggle");
        if (!button) {
            return;
        }

        const root = document.documentElement;
        const storageKey = root.dataset.lunetThemeStorageKey || "lunet-theme";
        const mediaQuery = window.matchMedia("(prefers-color-scheme: dark)");
        const icon = button.querySelector("[data-lunet-theme-toggle-icon]");
        const label = button.querySelector("[data-lunet-theme-toggle-label]");
        const prefix = button.dataset.themeTogglePrefix || "Theme";
        const modeLabels = {
            system: label?.dataset.themeSystemLabel || "System",
            light: label?.dataset.themeLightLabel || "Light",
            dark: label?.dataset.themeDarkLabel || "Dark"
        };

        const currentMode = function () {
            const mode = root.getAttribute("data-lunet-theme-mode");
            return modes.indexOf(mode) >= 0 ? mode : "system";
        };

        const syncButton = function (mode) {
            const modeLabel = modeLabels[mode] || mode;
            const fullLabel = prefix + ": " + modeLabel;
            if (icon) {
                icon.className = "bi " + (icons[mode] || icons.system);
            }
            if (label) {
                label.textContent = modeLabel;
            }
            button.setAttribute("aria-label", fullLabel);
            button.setAttribute("title", fullLabel);
        };

        const applyMode = function (mode) {
            const resolved = mode === "system" ? (mediaQuery.matches ? "dark" : "light") : mode;
            root.setAttribute("data-lunet-theme-mode", mode);
            root.setAttribute("data-bs-theme", resolved);
            try {
                localStorage.setItem(storageKey, mode);
            } catch (_) {
            }
            syncButton(mode);
        };

        syncButton(currentMode());

        button.addEventListener("click", function () {
            const index = modes.indexOf(currentMode());
            const next = modes[(index + 1) % modes.length];
            applyMode(next);
        });
    });
})();

// Diagrams (```mermaid blocks, as in the porting guide). Mermaid is large, so it is not part of the
// bundle: config.scriban copies it beside this script, and a page that has a diagram loads it.
(function () {
    const script = document.currentScript;
    document.addEventListener("DOMContentLoaded", function () {
        if (!script || document.querySelector(".mermaid") === null) {
            return;
        }
        const mermaid = document.createElement("script");
        mermaid.src = new URL("mermaid.min.js", script.src).href;
        mermaid.onload = function () {
            const dark = document.documentElement.getAttribute("data-bs-theme") === "dark";
            window.mermaid.initialize({ startOnLoad: false, theme: dark ? "dark" : "default" });
            window.mermaid.run();
        };
        document.head.appendChild(mermaid);
    });
})();
