"use client";

// Tell Next: do NOT statically prerender this page
export const dynamic = "force-dynamic";

import { createPublicClient } from "@supa/supabase/src/client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import type { AppRouterInstance } from "next/dist/shared/lib/app-router-context.shared-runtime";
import Link from "next/link";

export default function SignUp() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError(null);
    setLoading(true);

    // Validate passwords match
    if (password !== confirmPassword) {
      setError("Passwords do not match");
      setLoading(false);
      return;
    }

    try {
      // Create the client only in the browser and only on user action
      const supabase = createPublicClient();
      
      // Sign up with email and password
      const { data, error: signUpError } = await supabase.auth.signUp({
        email,
        password,
        options: {
          emailRedirectTo: `${window.location.origin}/app/profile`,
        },
      });

      if (signUpError) throw signUpError;

      // Check if user was created
      if (data?.user) {
        // Show success message
        setSuccess(true);
        
        // Redirect after a short delay
        setTimeout(() => {
          (router as AppRouterInstance).push("/app/profile");
        }, 2000);
      }
    } catch (err: any) {
      setError(err.message || "An error occurred during sign up");
    } finally {
      setLoading(false);
    }
  }

  const formStyles = {
    input: {
      width: "100%",
      padding: "12px",
      margin: "12px 0",
      border: "1px solid #ddd",
      borderRadius: "8px",
    },
    button: {
      padding: "12px 24px",
      backgroundColor: "#0070f3",
      color: "white",
      border: "none",
      borderRadius: "8px",
      cursor: "pointer",
      fontSize: "16px",
    },
    link: {
      color: "#0070f3",
      textDecoration: "none",
      marginTop: "20px",
      display: "inline-block",
    }
  };

  return (
    <main style={{ padding: 24, maxWidth: 440, margin: "40px auto" }}>
      <h1>Create an account</h1>
      
      {success ? (
        <div>
          <p style={{ color: "green" }}>
            Account created successfully! You will be redirected shortly.
          </p>
          <p>
            Check your email to confirm your account.
          </p>
        </div>
      ) : (
        <form onSubmit={onSubmit}>
          <div>
            <label htmlFor="email">Email</label>
            <input
              id="email"
              type="email"
              placeholder="you@example.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              style={formStyles.input}
              required
            />
          </div>
          
          <div>
            <label htmlFor="password">Password</label>
            <input
              id="password"
              type="password"
              placeholder="Password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              style={formStyles.input}
              required
              minLength={6}
            />
          </div>
          
          <div>
            <label htmlFor="confirmPassword">Confirm Password</label>
            <input
              id="confirmPassword"
              type="password"
              placeholder="Confirm Password"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              style={formStyles.input}
              required
              minLength={6}
            />
          </div>
          
          <button 
            type="submit" 
            style={formStyles.button}
            disabled={loading}
          >
            {loading ? "Creating account..." : "Sign Up"}
          </button>
          
          {error && <p style={{ color: "crimson" }}>{error}</p>}
          
          <p style={{ marginTop: "20px" }}>
            Already have an account?{" "}
            <a href="/sign-in" style={formStyles.link}>
              Sign in
            </a>
          </p>
        </form>
      )}
    </main>
  );
}
