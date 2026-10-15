#!/usr/bin/env node
'use strict';

// Read-only verification of the deployed GAME-G030 Web Export against the
// checked-out develop build. CI/Pages job success is not live-delivery proof.
const fs = require('node:fs/promises');
const path = require('node:path');
const { createHash } = require('node:crypto');
const files = ['build.json', 'index.html', 'index.js', 'index.pck', 'index.wasm'];
const localDir = process.env.P021_G030_LOCAL_DIR || path.resolve(__dirname, '../games/orbit-switch-courier');
const defaultBase = 'https://kobitworks.github.io/autoai_poc/p021-game/games/orbit-switch-courier/';
const baseArg = process.argv[2] || defaultBase;
const sha256 = b => createHash('sha256').update(b).digest('hex');
const result = {
  game: 'GAME-G030', task: 'GAME-076', checkedAt: new Date().toISOString(),
  status: 'UNVERIFIED', publicBase: baseArg, files: []
};

function finish(status, error) {
  result.status = status;
  if (error) result.error = String(error.message || error);
  console.log(JSON.stringify(result, null, 2));
  process.exitCode = status === 'PASS_LIVE_BYTES' ? 0 : status === 'UNVERIFIED_FETCH' ? 2 : 1;
}

async function run() {
  try {
    const base = new URL(baseArg.endsWith('/') ? baseArg : baseArg + '/');
    const loopback = ['localhost', '127.0.0.1', '[::1]'].includes(base.hostname);
    if (base.protocol !== 'https:' && !(base.protocol === 'http:' && loopback)) {
      throw new Error('HTTPS required except for a local test server');
    }
    const metadata = JSON.parse(await fs.readFile(path.join(localDir, 'build.json'), 'utf8'));
    for (const field of ['source_commit', 'workflow_run_id', 'workflow_run_attempt', 'quality_target']) {
      if (!metadata[field]) throw new Error('Local build.json missing ' + field);
    }
    result.expected = {
      sourceCommit: metadata.source_commit, workflowRunId: metadata.workflow_run_id,
      workflowRunAttempt: metadata.workflow_run_attempt, qualityTarget: metadata.quality_target
    };
    for (const name of files) {
      const local = await fs.readFile(path.join(localDir, name));
      try {
        const response = await fetch(new URL(name, base), {
          signal: AbortSignal.timeout(20000), headers: { Accept: '*/*' }
        });
        if (!response.ok) throw new Error(name + ': HTTP ' + response.status);
        const remote = Buffer.from(await response.arrayBuffer());
        result.files.push({
          name, localBytes: local.length, liveBytes: remote.length,
          localSha256: sha256(local), liveSha256: sha256(remote), match: local.equals(remote)
        });
      } catch (error) {
        return finish('UNVERIFIED_FETCH', error);
      }
    }
    const mismatch = result.files.filter(x => !x.match).map(x => x.name);
    if (mismatch.length) return finish('FAIL_MISMATCH', 'Live bytes differ: ' + mismatch.join(', '));
    return finish('PASS_LIVE_BYTES');
  } catch (error) {
    return finish('ERROR_LOCAL_OR_ARGUMENTS', error);
  }
}
run();
