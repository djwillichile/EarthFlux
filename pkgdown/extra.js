// The README logo is a <picture> with a dark-mode source for GitHub. The
// pkgdown site has a light theme only, so always show the light-background
// version regardless of the operating system colour scheme.
document.addEventListener("DOMContentLoaded", function () {
  document
    .querySelectorAll(".template-home .page-header picture source")
    .forEach(function (source) { source.remove(); });
});
