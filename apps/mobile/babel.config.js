// apps/mobile/babel.config.js
module.exports = function(api) {
  api.cache(true)
  return {
    presets: ['expo-router/babel'],
    plugins: []
  }
}
