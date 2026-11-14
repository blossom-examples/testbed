(() => {
  const byId = id => document.getElementById(id);
  byId("request-key").value = crypto.randomUUID();
  byId("theme").addEventListener("click", event => {
    const light = document.documentElement.dataset.theme !== "light";
    document.documentElement.dataset.theme = light ? "light" : "dark";
    event.target.textContent = light ? "Dark theme" : "Light theme";
    event.target.setAttribute("aria-label", `Switch to ${light ? "dark" : "light"} theme`);
  });
  async function refresh() {
    try {
      const response = await fetch("/qa", {cache: "no-store"});
      if (!response.ok) throw new Error("Status unavailable");
      const data = await response.json();
      for (const key of ["release", "service", "replica", "completed"]) byId(key).textContent = data[key];
    } catch (_) { byId("connection").textContent = "Status unavailable · retrying"; }
  }
  byId("job-form").addEventListener("submit", async event => {
    event.preventDefault();
    const button = event.target.querySelector("button");
    button.disabled = true;
    try {
      const response = await fetch("/api/jobs", {method: "POST", headers: {
        "Content-Type": "application/json", "Authorization": `Bearer ${byId("token").value}`
      }, body: JSON.stringify({request_key: byId("request-key").value})});
      const data = response.status === 401 ? {error: "Check the Testbed token."} : await response.json();
      byId("job-result").textContent = response.ok ? `Job ${data.id} ${data.completed ? "already completed" : "queued"}.` : data.error;
    } catch (_) { byId("job-result").textContent = "Connection interrupted. Retry with the same request key."; }
    finally { button.disabled = false; }
  });
  const identifier = JSON.stringify({channel: "EventsChannel"});
  function connect() {
    const socket = new WebSocket(`${location.protocol === "https:" ? "wss" : "ws"}://${location.host}/cable`, "actioncable-v1-json");
    socket.onopen = () => socket.send(JSON.stringify({command: "subscribe", identifier}));
    socket.onmessage = event => {
      const data = JSON.parse(event.data);
      if (!data.identifier || !data.message) return;
      byId("connection").textContent = "Cable connected";
      const item = document.createElement("li");
      item.textContent = `${new Date().toLocaleTimeString()} · ${JSON.stringify(data.message)}`;
      if (byId("events").children[0]?.textContent.startsWith("Waiting")) byId("events").replaceChildren();
      byId("events").prepend(item);
      while (byId("events").children.length > 20) byId("events").lastChild.remove();
      refresh();
    };
    socket.onclose = () => {
      byId("connection").textContent = "Cable reconnecting…";
      setTimeout(connect, 2000);
    };
  }
  refresh(); setInterval(refresh, 5000); connect();
})();
