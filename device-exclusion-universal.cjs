'use strict';
const registry = require('./blade-device-registry.json');
const VID = 0x1532;
const bladeIds = new Set(registry.devices.map(d => d.productId));
function id(value) {
  if (Number.isInteger(value)) return value;
  if (typeof value !== 'string') return NaN;
  return /^(?:0x[0-9a-f]+|[0-9]+)$/i.test(value) ? Number(value) : NaN;
}
function blockedPath(value) {
  if (typeof value !== 'string') return false;
  const match = /(?:^|[\\/#])vid_([0-9a-f]{4})&pid_([0-9a-f]{4})(?=[&#\\]|$)/i.exec(value);
  return !!match && Number.parseInt(match[1],16) === VID && bladeIds.has(Number.parseInt(match[2],16));
}
function blockedDevice(value) {
  return !!value && ((id(value.vendorId) === VID && bladeIds.has(id(value.productId)))
    || blockedPath(value.path) || blockedPath(value.devicePath) || blockedPath(value.deviceId));
}
// Bounded process-local identity evidence from native discovery only.
// Retain detached identities so deferred cleanup cannot regain laptop access.
const observedContainers = new Map();
function containerKey(value) {
  if (!value || !bladeIds.has(id(value.productId))) return null;
  const raw = value.deviceContainerId;
  if (typeof raw !== 'string') return null;
  const match = /^(?:\{([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\}|([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}))$/i.exec(raw);
  const guid = (match?.[1] || match?.[2] || '').toLowerCase();
  // The live trial showed this placeholder shared by multiple internal devices.
  if (!guid || guid === '00000000-0000-0000-0000-000000000000'
      || guid === '00000000-0000-0000-ffff-ffffffffffff') return null;
  return id(value.productId) + ':' + guid;
}
function observeDevice(value) {
  const key = containerKey(value), vendor = id(value?.vendorId);
  if (!key || !Number.isInteger(vendor) || vendor <= 0 || vendor > 65535) return;
  if (observedContainers.has(key)) {
    if (observedContainers.get(key) !== vendor) observedContainers.set(key, null);
  } else if (observedContainers.size < 256) observedContainers.set(key, vendor);
}
function observedBladeDevice(value) {
  if (value?.vendorId !== undefined && id(value.vendorId) !== VID) return false;
  const key = containerKey(value);
  return key !== null && observedContainers.get(key) === VID;
}
function visibleDevices(value, trusted = true) {
  return Array.isArray(value) ? value.filter(device => { if (trusted) observeDevice(device); return !blockedDevice(device); }) : value;
}
function rejectOpen(args) {
  if (blockedPath(args[0]) || (id(args[0]) === VID && bladeIds.has(id(args[1])))) {
    const error = new Error('This Razer Blade laptop is excluded by the offline prototype.');
    error.code = 'OPENBLADE_DEVICE_EXCLUDED';
    throw error;
  }
}
module.exports = { observeDevice, observedBladeDevice, blockedPath, blockedDevice, visibleDevices, rejectOpen, isBladeProductId: value => bladeIds.has(id(value)) };
