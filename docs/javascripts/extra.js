/* DevOps Learning Lab — scroll-triggered in-view observer.
   Adds .in-view to .in-view-target as they enter the viewport. */
(function () {
  if (typeof window === "undefined" || !("IntersectionObserver" in window)) return;
  var prefersReduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  function attach() {
    var targets = document.querySelectorAll(
      ".grid.cards > ul > li, .tool-grid .tool, .md-typeset .mermaid, .hero, .layout-asym > *"
    );
    targets.forEach(function (el) { el.classList.add("in-view-target"); });

    if (prefersReduced) {
      targets.forEach(function (el) { el.classList.add("in-view"); });
      return;
    }

    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) {
          e.target.classList.add("in-view");
          io.unobserve(e.target);
        }
      });
    }, { rootMargin: "0px 0px -10% 0px", threshold: 0.08 });

    targets.forEach(function (el) { io.observe(el); });
  }

  if (document.readyState !== "loading") attach();
  else document.addEventListener("DOMContentLoaded", attach);

  // Re-attach on Material instant navigation
  if (window.document$ && typeof window.document$.subscribe === "function") {
    window.document$.subscribe(attach);
  }
})();
