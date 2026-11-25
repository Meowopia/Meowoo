// SPDX-License-Identifier: GPL-3.0-only
// ==MiruExtension==
// @name         Blender 开放短片
// @package      meowoo.open-films
// @version      v1.0.0
// @author       Meowopia
// @license      GPL-3.0-only
// @lang         all
// @webSite      https://studio.blender.org/films/
// @description  Browse a curated selection of Blender Studio open films.
// @type         bangumi
// @apiVersion   2
// @nsfw         false
// ==/MiruExtension==

// Only links to fixed publisher-hosted media; no network calls or credentials.
// Store separate catalogue and stream URLs so saved items can survive a stream
// change. The only accepted final URLs are the bundled publisher URLs.
const items = [
  {
    "title": "Wing It!",
    "url": "https://video.blender.org/w/bd0084a5-1d26-4816-ab5e-1bad9e2fb990",
    "cover": "https://video.blender.org/lazy-static/thumbnails/4efa0a16-83b0-4c62-a4bc-4dcd30c05749.jpg",
    "desc": "2023 · Blender Studio",
    "label": "480p",
    "media": "https://video.blender.org/object-storage/web_videos/1be4c93c-1fd2-498d-adc7-50126823033e-480.mp4",
    "type": "mp4"
  },
  {
    "title": "Coffee Run",
    "url": "https://video.blender.org/w/ff8fe61b-026f-4f07-b66b-2a790d6f6ab1",
    "cover": "https://video.blender.org/lazy-static/thumbnails/ff8fe61b-026f-4f07-b66b-2a790d6f6ab1.jpg",
    "desc": "2020 · Blender Studio",
    "label": "720p",
    "media": "https://video.blender.org/object-storage/web_videos/ff8fe61b-026f-4f07-b66b-2a790d6f6ab1-720.mp4",
    "type": "mp4"
  },
  {
    "title": "Spring",
    "url": "https://video.blender.org/w/3d95fb3d-c866-42c8-9db1-fe82f48ccb95",
    "cover": "https://video.blender.org/lazy-static/thumbnails/3d95fb3d-c866-42c8-9db1-fe82f48ccb95.jpg",
    "desc": "2019 · Blender Studio",
    "label": "720p",
    "media": "https://video.blender.org/object-storage/web_videos/3d95fb3d-c866-42c8-9db1-fe82f48ccb95-720.mp4",
    "type": "mp4"
  },
  {
    "title": "Sintel",
    "url": "https://video.blender.org/w/0eb052d0-fd51-43e6-aa33-ecdbf77a5d40",
    "cover": "https://video.blender.org/lazy-static/thumbnails/0eb052d0-fd51-43e6-aa33-ecdbf77a5d40.jpg",
    "desc": "2010 · Blender Studio",
    "label": "720p",
    "media": "https://video.blender.org/object-storage/web_videos/0eb052d0-fd51-43e6-aa33-ecdbf77a5d40-720.mp4",
    "type": "mp4"
  },
  {
    "title": "Big Buck Bunny",
    "url": "https://video.blender.org/w/bf1f3fb5-b119-4f9f-9930-8e20e892b898",
    "cover": "https://video.blender.org/lazy-static/thumbnails/bf1f3fb5-b119-4f9f-9930-8e20e892b898.jpg",
    "desc": "2008 · Blender Studio",
    "label": "720p",
    "media": "https://video.blender.org/object-storage/web_videos/bf1f3fb5-b119-4f9f-9930-8e20e892b898-720.mp4",
    "type": "mp4"
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
    tags: ["Animation"],
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
