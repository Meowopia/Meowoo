import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
import vm from 'node:vm';

const sources = [
  ['meowoo.open-films', 5, ['video.blender.org']],
  ['meowoo.playback-samples', 3, [
    'storage.googleapis.com',
    'devstreaming-cdn.apple.com',
  ]],
];

const streamTypes = new Set();
for (const [name, count, mediaHosts] of sources) {
  const asset = new URL(`../../assets/bundled_sources/${name}.js`, import.meta.url);
  const script = await readFile(asset, 'utf8');
  const pkg = script.match(/^\/\/ @package\s+(\S+)/m)?.[1];
  assert.equal(pkg, name);
  assert.match(script, /^\/\/ @apiVersion +2$/m);
  assert.match(script, /^\/\/ @nsfw +false$/m);
  // No network or host APIs are provided to these pure local fixtures.
  const source = vm.createContext({});
  vm.runInContext(script, source, { filename: name });
  const items = await source.latest(1);
  assert.equal(items.length, count);
  assert.equal((await source.latest(2)).length, 0);
  assert.equal((await source.search('missing item', 1)).length, 0);
  assert.equal((await source.search(items[0].title.toUpperCase(), 1)).length, 1);
  assert.equal(new Set(items.map((item) => item.url)).size, count);

  for (const item of items) {
    const detail = await source.detail(item.url);
    assert.equal(detail.title, item.title);
    const episode = detail.episodes[0].urls[0];
    const watch = await source.watch(episode.url);
    const { url } = watch.groups[0].mirrors[0];
    assert.notEqual(url, item.url);
    const stream = await source.mirror(url);
    assert.equal(stream.url, url);
    assert.ok(mediaHosts.includes(new URL(url).hostname));
    assert.equal(new URL(url).protocol, 'https:');
    assert.ok(['mp4', 'hls'].includes(stream.type));
    assert.equal(Object.keys(stream.headers).length, 0);
    streamTypes.add(stream.type);
  }
  const unlisted = 'https://example.invalid/';
  await assert.rejects(() => source.detail(unlisted), /Unknown catalogue entry/);
  await assert.rejects(() => source.watch(unlisted), /Unknown catalogue entry/);
  await assert.rejects(() => source.mirror(unlisted), /Unknown stream/);
  console.log(`${name}: ${count} entries passed the offline adapter contract checks`);
}
assert.ok(streamTypes.has('mp4') && streamTypes.has('hls'));
