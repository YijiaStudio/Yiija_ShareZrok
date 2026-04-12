/* Yiija ShareZrok: load ../share_urls.txt and redirect. CSP-friendly external file. */
(function () {
  var FETCH_MS = 12000;

  function setMsg(body, s) {
    var el = document.getElementById("zrok-msg");
    if (el) {
      el.textContent = s;
    } else if (body) {
      body.textContent = s;
    }
  }

  function fetchWithTimeout(url, options, ms) {
    var ctrl = new AbortController();
    var t = setTimeout(function () {
      ctrl.abort();
    }, ms);
    var merged = Object.assign({}, options, { signal: ctrl.signal });
    return fetch(url, merged).finally(function () {
      clearTimeout(t);
    });
  }

  function run() {
    var body = document.body;
    if (!body) return;
    var svc = body.getAttribute("data-svc");
    if (!svc) return;
    svc = svc.trim();
    var svcL = svc.toLowerCase();
    var u = new URL("../share_urls.txt", location.href);
    u.searchParams.set("t", String(Date.now()));

    setMsg(body, "Fetching share_urls.txt...");

    fetchWithTimeout(
      u.toString(),
      {
        cache: "no-store",
        headers: { "Cache-Control": "no-cache", Pragma: "no-cache" },
      },
      FETCH_MS
    )
      .then(function (r) {
        if (!r.ok) {
          throw new Error("HTTP " + r.status);
        }
        return r.text();
      })
      .then(function (t) {
        setMsg(body, "Resolving URL...");
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
          setMsg(body, "Redirecting...");
          try {
            location.replace(new URL(raw).href);
          } catch (e) {
            location.replace(raw);
          }
          return;
        }
        setMsg(body, "No URL for " + svc + " in share_urls.txt");
      })
      .catch(function (e) {
        var extra = "";
        if (e && e.name === "AbortError") {
          extra = " (timeout " + FETCH_MS / 1000 + "s)";
        }
        setMsg(body, "Cannot load share_urls.txt" + extra);
      });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", run);
  } else {
    run();
  }
})();
