// apps/web/next.config.mjs
export default {
  transpilePackages: [
    "react-native-web",
    "tamagui",
    "@tamagui/*",
    "@supa/ui",
    "@supa/shared",
    "@supa/supabase",
  ],
  experimental: {
    scrollRestoration: true,
  },
  output: "standalone",
};
