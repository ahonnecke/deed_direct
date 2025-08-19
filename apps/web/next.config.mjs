// apps/web/next.config.mjs
import withTamagui from '@tamagui/next-plugin'

const withPlugins = withTamagui({
  config: '../../packages/ui/tamagui.config.ts',
  components: ['@supa/ui'],
  disableExtract: process.env.NODE_ENV === 'development',
})

export default withPlugins({
  transpilePackages: [
    'react-native-web',
    'tamagui',
    '@tamagui/*',
    '@supa/ui',
    '@supa/shared',
    '@supa/supabase',
  ],
  experimental: {
    scrollRestoration: true,
  },
})
