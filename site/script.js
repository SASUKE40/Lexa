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
