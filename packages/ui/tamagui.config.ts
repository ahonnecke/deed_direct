// packages/ui/tamagui.config.ts
import { createTamagui } from 'tamagui'
import { tokens } from '@tamagui/theme-base'

export const config = createTamagui({
  tokens,
  themes: {
    light: { bg: 'white', color: 'black' },
    dark: { bg: 'black', color: 'white' },
  },
})

export type AppConfig = typeof config
declare module 'tamagui' {
  interface TamaguiCustomConfig extends AppConfig {}
}
