// Copy buttons for the Homebrew command.
document.querySelectorAll(".command").forEach((box) => {
  const button = box.querySelector(".copy");
  button.addEventListener("click", async () => {
    try {
      await navigator.clipboard.writeText(box.dataset.copy);
      button.textContent = "Copied";
    } catch {
      button.textContent = "Select the text";
    }
    setTimeout(() => { button.textContent = "Copy"; }, 1800);
  });
});

// Show the version of the latest release.
fetch("https://api.github.com/repos/SASUKE40/Lexa/releases/latest", { headers: { Accept: "application/vnd.github+json" } })
  .then((response) => (response.ok ? response.json() : null))
  .then((release) => {
    if (release && release.tag_name) {
      document.getElementById("version").textContent = `Version ${release.tag_name.replace(/^v/, "")}`;
    }
  })
  .catch(() => {});

// Appearance switch: automatic (system) → light → dark.
const themes = ["auto", "light", "dark"];
const icons = {
  auto: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M12 3a9 9 0 0 0 0 18z" fill="currentColor"/></svg>',
  light: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></svg>',
  dark: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round" aria-hidden="true"><path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/></svg>',
};
const labels = { auto: "Appearance: automatic", light: "Appearance: light", dark: "Appearance: dark" };
const toggle = document.getElementById("theme-toggle");

function applyTheme(theme) {
  if (theme === "auto") {
    delete document.documentElement.dataset.theme;
  } else {
    document.documentElement.dataset.theme = theme;
  }
  toggle.innerHTML = icons[theme];
  toggle.setAttribute("aria-label", labels[theme]);
  toggle.title = labels[theme];
}

let current = document.documentElement.dataset.theme || "auto";
applyTheme(current);
toggle.addEventListener("click", () => {
  current = themes[(themes.indexOf(current) + 1) % themes.length];
  try {
    if (current === "auto") localStorage.removeItem("theme"); else localStorage.setItem("theme", current);
  } catch {}
  applyTheme(current);
});
