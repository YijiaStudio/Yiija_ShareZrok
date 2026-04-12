/* Yiija ShareZrok: load ../share_urls.txt (sibling of node folder) and redirect. Inline script avoided for GitHub Pages / CSP. */
(function () {
  function run() {
    var body = document.body;
    if (!body) return;
    var svc = body.getAttribute("data-svc");
    if (!svc) return;
    svc = svc.trim();
    var svcL = svc.toLowerCase();
    var u = new URL("../share_urls.txt", location.href);
    u.searchParams.set("t", String(Date.now()));
    fetch(u.toString(), {
      cache: "no-store",
      headers: { "Cache-Control": "no-cache", Pragma: "no-cache" },
    })
      .then(function (r) {
        return r.text();
      })
      .then(function (t) {
        t = t.replace(/^\uFEFF/, "");
        var lines = t.split(/\r?\n/);
        for (var i = 0; i < lines.length; i++) {
          var line = lines[i].trim();
          if (!line || line.charAt(0) === "#") continue;
          line = line.replace(/^\uFEFF/, "");
          var p = line.indexOf("|");
          if (p < 1) continue;
          var svcName = line.substring(0, p).trim();
          if (svcName.toLowerCase() !== svcL) continue;
          var raw = line.substring(p + 1).trim();
          if (!raw) continue;
          try {
            location.replace(new URL(raw).href);
          } catch (e) {
            location.replace(raw);
          }
          return;
        }
        body.textContent = "No URL for " + svc + " in share_urls.txt";
      })
      .catch(function () {
        body.textContent = "Cannot load share_urls.txt";
      });
  }
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", run);
  } else {
    run();
  }
})();
