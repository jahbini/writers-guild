#!/usr/bin/env node
'use strict';

const fs = require('fs');

function readStdin() {
  return new Promise((resolve, reject) => {
    let data = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (chunk) => {
      data += chunk;
    });
    process.stdin.on('end', () => resolve(data));
    process.stdin.on('error', reject);
  });
}

function toJson(prompt) {
  const text = String(prompt || '');
  const chunkCount = (text.match(/"id":/g) || []).length;
  return {
    plot_atoms: [],
    meta: {
      engine: 'oracle_atoms_stub',
      prompt_chars: text.length,
      detected_chunk_count: chunkCount
    }
  };
}

readStdin()
  .then((prompt) => {
    process.stdout.write(JSON.stringify(toJson(prompt)));
  })
  .catch((err) => {
    process.stderr.write(String(err && err.message ? err.message : err));
    process.exit(1);
  });
