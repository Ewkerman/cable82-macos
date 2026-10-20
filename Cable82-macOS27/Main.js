"use strict";
const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");
const { createApp } = require("./server.js");

// macOS build: keep user media/config in a normal Finder-visible folder.
const dataRoot = process.env.CABLE82_DATA || path.join(os.homedir(), "Movies", "Cable82");
const channelsDir = process.env.CABLE82_CHANNELS || path.join(dataRoot, "channels");
const musicDir = path.join(dataRoot, "music");
const configPath = path.join(dataRoot, "config.json");
const videosDir = path.join(channelsDir, "Videos");
for (const dir of [dataRoot, musicDir]) fs.mkdirSync(dir, { recursive: true });
// The selected channels folder may live on an external drive. Only create it when its parent is available.
try { fs.mkdirSync(channelsDir, { recursive: true }); fs.mkdirSync(videosDir, { recursive: true }); } catch (e) { console.error("CHANNELS FOLDER ERROR:", e.message); }

const server = createApp({ configPath, channelsDir, musicDir, mediaDirs: [dataRoot], mediaScanDirs: [] });
let cfg = server.loadConfig() || {};
if (!Array.isArray(cfg.channels)) cfg.channels = [];
if (!cfg.channels.some((ch) => ch && ch.type === "video")) {
  const used = new Set(cfg.channels.map((ch) => Number(ch && ch.number)).filter(Number.isFinite));
  let number = 81; while (used.has(number) && number > 1) number--;
  cfg.channels.push({ number, type:"video", name:"VIDEOS", enabled:true, folder:"Videos", mode:"continuous", order:"sequence", offAir:"testcard", titles:"filename", schedule:[] });
  cfg.channels.sort((a,b) => Number(a.number)-Number(b.number));
  try { fs.writeFileSync(configPath, JSON.stringify(cfg, null, 2) + "\n"); } catch (e) { console.error(e); }
}

// Port 80 requires elevated privileges on macOS. 1982 runs as a normal app.
const port = Number(process.env.CABLE82_PORT) || 1982;
server.on("error", (err) => console.error("CABLE82 SERVER ERROR:", err));
server.listen(port, "0.0.0.0", () => {
  console.log("CABLE 82 macOS server running on port " + port);
  console.log("CABLE 82 data folder: " + dataRoot);
  console.log("CABLE 82 channels folder: " + channelsDir);
});
