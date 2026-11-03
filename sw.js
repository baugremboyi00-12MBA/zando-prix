// Mode hors ligne : réseau d'abord, puis dernière copie enregistrée si la connexion manque.
var CACHE = "zando-prix-v1";
var SHELL = ["./", "index.html", "config.js", "manifest.webmanifest", "data/estimations.json", "icons/icon-192.png", "icons/icon-512.png"];

self.addEventListener("install", function (e) {
  e.waitUntil(caches.open(CACHE).then(function (c) { return c.addAll(SHELL); }).then(function () { return self.skipWaiting(); }));
});

self.addEventListener("activate", function (e) {
  e.waitUntil(caches.keys().then(function (keys) {
    return Promise.all(keys.filter(function (k) { return k !== CACHE; }).map(function (k) { return caches.delete(k); }));
  }).then(function () { return self.clients.claim(); }));
});

self.addEventListener("fetch", function (e) {
  var url = new URL(e.request.url);
  if (e.request.method !== "GET" || url.origin !== self.location.origin) return;
  e.respondWith(
    new Promise(function (resolve) {
      var done = false;
      var fromCache = function () {
        return caches.match(e.request, { ignoreSearch: true }).then(function (hit) {
          return hit || (e.request.mode === "navigate" ? caches.match("index.html") : null);
        });
      };
      // Réseau trop lent : on affiche la copie sans attendre.
      var timer = setTimeout(function () {
        fromCache().then(function (hit) { if (hit && !done) { done = true; resolve(hit); } });
      }, 4000);
      fetch(e.request).then(function (res) {
        if (res.ok) { var copy = res.clone(); caches.open(CACHE).then(function (c) { c.put(e.request, copy); }); }
        clearTimeout(timer);
        if (!done) { done = true; resolve(res); }
      }).catch(function () {
        clearTimeout(timer);
        fromCache().then(function (hit) {
          if (!done) { done = true; resolve(hit || new Response("Hors connexion", { status: 503 })); }
        });
      });
    })
  );
});
