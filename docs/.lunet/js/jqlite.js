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
