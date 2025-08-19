import { useState, useEffect } from 'react';
import { Text, View, Button } from 'react-native';
import { createPublicClient } from 'supabase/client';

export default function App() {
  const [session, setSession] = useState<any>(null);
  const supabase = createPublicClient();

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setSession(data.session));
    const { data: sub } = supabase.auth.onAuthStateChange((_event, sess) => setSession(sess));
    return () => sub.subscription.unsubscribe();
  }, []);

  if (!session) {
    return (
      <View style={{flex:1,justifyContent:'center',alignItems:'center'}}>
        <Text>Not signed in</Text>
        <Button title="Sign In (Magic Link)" onPress={() => supabase.auth.signInWithOtp({ email: 'test@example.com' })} />
      </View>
    );
  }

  return (
    <View style={{flex:1,justifyContent:'center',alignItems:'center'}}>
      <Text>Welcome {session.user.email}</Text>
      <Button title="Sign out" onPress={() => supabase.auth.signOut()} />
    </View>
  );
}
