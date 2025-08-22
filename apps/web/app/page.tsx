// apps/web/app/page.tsx
import Link from 'next/link';

export default function HomePage() {
  return (
    <main style={{ padding: '2rem', maxWidth: '800px', margin: '0 auto' }}>
      <h1>Welcome to Supabase Auth Demo</h1>
      
      <div style={{ marginTop: '2rem' }}>
        <h2>Authentication</h2>
        <div style={{ display: 'flex', gap: '1rem', marginTop: '1rem' }}>
          <Link href={{ pathname: "/sign-in" }} style={{ padding: '0.5rem 1rem', backgroundColor: '#0070f3', color: 'white', borderRadius: '4px', textDecoration: 'none' }}>
            Sign In
          </Link>
          <Link href={{ pathname: "/sign-up" }} style={{ padding: '0.5rem 1rem', backgroundColor: '#0070f3', color: 'white', borderRadius: '4px', textDecoration: 'none' }}>
            Sign Up
          </Link>
        </div>
      </div>

      <div style={{ marginTop: '2rem' }}>
        <h2>Protected Area</h2>
        <div style={{ display: 'flex', gap: '1rem', marginTop: '1rem' }}>
          <Link href={{ pathname: "/app/profile" }} style={{ padding: '0.5rem 1rem', backgroundColor: '#34a853', color: 'white', borderRadius: '4px', textDecoration: 'none' }}>
            Profile (Protected)
          </Link>
        </div>
      </div>

      <div style={{ marginTop: '2rem' }}>
        <h2>Testing</h2>
        <div style={{ display: 'flex', gap: '1rem', marginTop: '1rem' }}>
          <Link href={{ pathname: "/test-auth" }} style={{ padding: '0.5rem 1rem', backgroundColor: '#ea4335', color: 'white', borderRadius: '4px', textDecoration: 'none' }}>
            Test Auth Flow
          </Link>
        </div>
      </div>
    </main>
  );
}
