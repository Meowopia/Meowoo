// SPDX-License-Identifier: GPL-3.0-only
// ==MiruExtension==
// @name         Meowoo 播放测试样例
// @package      meowoo.playback-samples
// @version      v1.0.0
// @author       Meowopia
// @license      GPL-3.0-only
// @lang         all
// @webSite      https://developer.apple.com/streaming/examples/
// @description  Public AndroidX and Apple developer test streams.
// @type         bangumi
// @apiVersion   2
// @nsfw         false
// ==/MiruExtension==

// Only links to fixed publisher-hosted media; no network calls or credentials.
// Store separate catalogue and stream URLs so saved items can survive a stream
// change. The only accepted final URLs are the bundled publisher URLs.
const items = [
  {
    "title": "Android Screens (10s)",
    "url": "https://developer.android.com/media/media3#android-screens",
    "cover": "",
    "desc": "AndroidX Media3",
    "label": "MP4",
    "media": "https://storage.googleapis.com/exoplayer-test-media-1/mp4/android-screens-10s.mp4",
    "type": "mp4"
  },
  {
    "title": "Dizzy",
    "url": "https://developer.android.com/media/media3#dizzy",
    "cover": "",
    "desc": "AndroidX Media3",
    "label": "MP4",
    "media": "https://storage.googleapis.com/exoplayer-test-media-1/mp4/dizzy-with-tx3g.mp4",
    "type": "mp4"
  },
  {
    "title": "Apple basic stream",
    "url": "https://developer.apple.com/streaming/examples/#apple-basic-stream",
    "cover": "",
    "desc": "Apple HLS",
    "label": "HLS",
    "media": "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8",
    "type": "hls"
  }
];

function summary(item) {
  return { title: item.title, url: item.url, cover: item.cover };
}

function catalogueItem(url) {
  const item = items.find((row) => row.url === url);
  if (!item) throw new Error("Unknown catalogue entry");
  return item;
}

async function latest(page) {
  return Number(page) === 1 ? items.map(summary) : [];
}

async function search(keyword, page) {
  if (Number(page) !== 1) return [];
  const query = String(keyword ?? "").trim().toLowerCase();
  return items
    .filter((row) => (row.title + " " + row.desc).toLowerCase().includes(query))
    .map(summary);
}

async function detail(url) {
  const item = catalogueItem(url);
  return {
    ...summary(item),
    desc: item.desc,
    tags: ["Test"],
    episodes: [{ title: item.title, urls: [{ name: item.label, url: item.url }] }],
  };
}

async function watch(url) {
  const item = catalogueItem(url);
  return {
    groups: [{ title: item.desc, mirrors: [{ name: item.label, url: item.media }] }],
  };
}

async function mirror(url) {
  const item = items.find((row) => row.media === url);
  if (!item) throw new Error("Unknown stream");
  return { type: item.type, url: item.media, headers: {} };
}
