'use strict';
const path = require('node:path');
const exclusion = require('./openblade-device-exclusion.cjs');
// Reviewed native artifact names only. Other versions need additional evidence.
const artifactNames = new Set(['blade2native_v1.0.46.0.dll','blade2nativeapp_v1.0.1.0.exe']);
function knownBladeFile(value) {
  if (typeof value !== 'string') return false;
  const p = path.win32.normalize(value).toLowerCase();
  return /(?:^|\\)apps\\common\\bladecommon\\/.test(p) && artifactNames.has(path.win32.basename(p));
}
function bladeUrl(value) {
  try {
    const url = new URL(value);
    const match = /^\/products\/([0-9]+)(?:\/|$)/.exec(url.pathname) || /^\/synapse\/products\/([0-9]+)(?:\/|$)/.exec(url.pathname);
    return url.protocol === 'https:' && url.hostname === 'apps.razer.com' && !!match && exclusion.isBladeProductId(match[1]);
  } catch { return false; }
}
function bladeSender(event) {
  // A child frame may belong to a product even when its window is shared.
  // Read independently: Electron can dispose a frame during navigation.
  let frameUrl, windowUrl;
  try { frameUrl = event?.senderFrame?.url; } catch {}
  try { windowUrl = event?.sender?.getURL(); } catch {}
  return bladeUrl(frameUrl) || bladeUrl(windowUrl);
}
const lifecycleRegistrations = new Set(['SetAPIToCallWhenExitDevice','SetAPIToCallWhenShutdown','SetAPIToCallWhenSuspend']);
const ffiRoutes = new Set(['ffiPreload','ffiPreloadAsync','ffiSubPreloadAsync']);
function assertAllowed(route, event, request) {
  const p = request?.payload;
  const launchPath = p?.folderName && p?.filePath ? path.win32.join(p.folderName, p.filePath) : p?.filePath;
  const targetMapping = route === 'mappingEngineAction' && (exclusion.blockedDevice(p?.usbDevice) || exclusion.blockedDevice(p?.device));
  const targetLifecycle = ffiRoutes.has(route) && lifecycleRegistrations.has(request?.action)
    && (exclusion.blockedDevice(p) || exclusion.observedBladeDevice(p));
  if (targetLifecycle || bladeSender(event) || knownBladeFile(p?.dllPath) || knownBladeFile(launchPath) || targetMapping) {
    const error = new Error('Blade-specific native request excluded by the offline prototype.');
    error.code = 'OPENBLADE_NATIVE_DEVICE_EXCLUDED';
    throw error;
  }
}
module.exports = { assertAllowed, knownBladeFile, bladeSender };
