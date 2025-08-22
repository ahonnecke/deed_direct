"use client";

import { useState } from "react";
import Link from "next/link";

export default function TestAuthFlow() {
  const [testResults, setTestResults] = useState<{[key: string]: string}>({});
  
  const styles = {
    container: {
      padding: "2rem",
      maxWidth: "800px",
      margin: "0 auto",
    },
    header: {
      marginBottom: "2rem",
    },
    section: {
      marginBottom: "2rem",
      padding: "1rem",
      border: "1px solid #ddd",
      borderRadius: "8px",
    },
    button: {
      padding: "0.5rem 1rem",
      backgroundColor: "#0070f3",
      color: "white",
      border: "none",
      borderRadius: "4px",
      cursor: "pointer",
      marginRight: "0.5rem",
    },
    link: {
      color: "#0070f3",
      textDecoration: "none",
      marginRight: "1rem",
    },
    result: {
      marginTop: "1rem",
      padding: "1rem",
      backgroundColor: "#f5f5f5",
      borderRadius: "4px",
    },
    success: {
      color: "green",
    },
    error: {
      color: "red",
    },
    testGrid: {
      display: "grid",
      gridTemplateColumns: "1fr 1fr",
      gap: "1rem",
    }
  };

  return (
    <div style={styles.container}>
      <div style={styles.header}>
        <h1>Authentication Flow Test</h1>
        <p>Use this page to test the complete authentication flow</p>
      </div>

      <div style={styles.section}>
        <h2>Test Links</h2>
        <div style={styles.testGrid}>
          <div>
            <h3>Authentication Pages</h3>
            <div>
              <Link href={{ pathname: "/sign-up" }} style={styles.link}>Sign Up</Link>
              <Link href={{ pathname: "/sign-in" }} style={styles.link}>Sign In</Link>
            </div>
          </div>
          <div>
            <h3>Protected Pages</h3>
            <div>
              <Link href={{ pathname: "/app/profile" }} style={styles.link}>Profile (Protected)</Link>
            </div>
          </div>
        </div>
      </div>

      <div style={styles.section}>
        <h2>Test Instructions</h2>
        <ol>
          <li>Start by clicking on <strong>Sign Up</strong> to create a new account</li>
          <li>After signing up, you should be redirected to the Profile page</li>
          <li>Sign out from the Profile page</li>
          <li>Try signing in with your password</li>
          <li>Sign out again</li>
          <li>Try signing in with a magic link</li>
          <li>Try accessing the Profile page directly - it should redirect you if not signed in</li>
        </ol>
      </div>

      <div style={styles.section}>
        <h2>Expected Behavior</h2>
        <ul>
          <li>Sign-up should create a new user and redirect to Profile</li>
          <li>Sign-in with password should authenticate and redirect to Profile</li>
          <li>Sign-in with magic link should send an email and authenticate on click</li>
          <li>Protected routes should redirect to sign-in when not authenticated</li>
          <li>Profile page should show user info and allow sign-out</li>
          <li>After sign-out, protected routes should be inaccessible</li>
        </ul>
      </div>
    </div>
  );
}
