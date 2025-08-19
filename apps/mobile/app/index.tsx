// apps/mobile/app/index.tsx
import { Link, Redirect } from 'expo-router'
import React, { useEffect, useState } from 'react'
import { Text, View, TextInput, Button } from 'react-native'
import { createPublicClient } from '@supa/supabase/src/client'

const supabase = createPublicClient()

export default function Index() {
  const [email, setEmail] = useState('')
  const [session, setSession] = useState<any>(null)

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setSession(data.session))
    const { data: sub } = supabase.auth.onAuthStateChange((_e, s) => setSession(s))
    return () => sub.subscription.unsubscribe()
  }, [])

  if (session) return <Redirect href="/app/home" />

  return (
    <View style={{ padding: 24, gap: 12 }}>
      <Text style={{ fontSize: 24, fontWeight: 'bold' }}>Sign in (magic link)</Text>
      <TextInput
        placeholder="you@example.com"
        value={email}
        onChangeText={setEmail}
        autoCapitalize="none"
        keyboardType="email-address"
        style={{ borderWidth: 1, padding: 12, borderRadius: 8 }}
      />
      <Button title="Send magic link" onPress={async () => {
        await supabase.auth.signInWithOtp({ email, options: { emailRedirectTo: 'supa-mobile://auth' } })
        alert('Check your email for a magic link')
      }} />
      <Link href="/app/home">Skip → App (dev only)</Link>
    </View>
  )
}
