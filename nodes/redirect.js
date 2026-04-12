/* Yiija ShareZrok: load ../share_urls.txt then redirect to zrok URL.
 * Uses XHR + xhr.timeout (fetch + AbortController can hang on some networks / extensions). */
(function () {
  var FETCH_MS = 15000;

  function cleanTargetUrl(s) {
    return String(s || "")
      .trim()
      .replace(/\r/g, "")
      .replace(/\n/g, "");
  }

  function setMsg(body, s) {
    var el = document.getElementById("zrok-msg");
    if (el) {
      el.textContent = s;
    } else if (body) {
      body.textContent = s;
    }
  }

  /** Same-origin GET text; timeout enforced by xhr.timeout (reliable vs fetch hang). */
  function getTextWithTimeout(url, ms) {
    return new Promise(function (resolve, reject) {
      var xhr = new XMLHttpRequest();
      xhr.open("GET", url, true);
      xhr.timeout = ms;
      xhr.onreadystatechange = function () {
        if (xhr.readyState !== 4) return;
        if (xhr.status >= 200 && xhr.status < 300) {
          resolve(xhr.responseText);
        } else {
          reject(new Error("HTTP " + xhr.status));
        }
      };
      xhr.onerror = function () {
        reject(new Error("network"));
      };
      xhr.ontimeout = function () {
        reject(new Error("timeout"));
      };
      xhr.send();
    });
  }

  function go(urlStr) {
    var u = cleanTargetUrl(urlStr);
    if (!u) return;
    setTimeout(function () {
      try {
        window.location.replace(new URL(u).href);
      } catch (e) {
        window.location.replace(u);
      }
    }, 0);
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

    var urlStr = u.toString();
    setMsg(body, "Fetching share_urls.txt...");

    getTextWithTimeout(urlStr, FETCH_MS)
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
          go(raw);
          return;
        }
        setMsg(body, "No URL for " + svc + " in share_urls.txt");
      })
      .catch(function (e) {
        var detail = e && e.message ? e.message : String(e);
        var hint =
          " Cannot open: " +
          urlStr +
          " - If GitHub is slow, retry; or open that .txt link in a new tab.";
        setMsg(body, "Cannot load share_urls.txt (" + detail + ")." + hint);
      });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", run);
  } else {
    run();
  }
})();
