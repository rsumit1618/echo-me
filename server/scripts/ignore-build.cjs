const { execFileSync } = require('node:child_process');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');

function log(message) {
  console.log(`[deploy-gate] ${message}`);
}

function readCurrentVersion() {
  const packageJson = JSON.parse(
    readFileSync(join(process.cwd(), 'package.json'), 'utf8'),
  );

  return packageJson.version;
}

function readPreviousVersion() {
  const previousPackageJson = execFileSync(
    'git',
    ['show', 'HEAD^:server/package.json'],
    { encoding: 'utf8' },
  );

  return JSON.parse(previousPackageJson).version;
}

if (process.env.FORCE_VERCEL_DEPLOY === '1') {
  log('FORCE_VERCEL_DEPLOY=1, build can proceed.');
  process.exit(1);
}

if (process.env.VERCEL_ENV && process.env.VERCEL_ENV !== 'production') {
  log(`Skipping ${process.env.VERCEL_ENV} deployment.`);
  process.exit(0);
}

try {
  const currentVersion = readCurrentVersion();
  const previousVersion = readPreviousVersion();

  if (currentVersion !== previousVersion) {
    log(`Version changed ${previousVersion} -> ${currentVersion}, build can proceed.`);
    process.exit(1);
  }

  log(`Version unchanged at ${currentVersion}, skipping deployment.`);
  process.exit(0);
} catch (error) {
  log(`Could not compare versions, build can proceed: ${error.message}`);
  process.exit(1);
}
