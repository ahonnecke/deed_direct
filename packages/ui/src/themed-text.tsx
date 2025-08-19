// packages/ui/src/themed-text.tsx
'use client'
import React from 'react'
import { Text } from 'react-native'

export default function ThemedText(props: React.ComponentProps<typeof Text>) {
  return <Text {...props} />
}
