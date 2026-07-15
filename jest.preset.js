const { join } = require('node:path');
const nxPreset = require('@nx/jest/preset').default;

module.exports = {
  ...nxPreset,
  setupFilesAfterEnv: [
    ...(nxPreset.setupFilesAfterEnv || []),
    join(__dirname, 'jest.setup.dom.js'),
  ],
};
