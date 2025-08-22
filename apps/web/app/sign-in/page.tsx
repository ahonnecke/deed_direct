"use client";

// Tell Next: do NOT statically prerender this page
export const dynamic = "force-dynamic";

import { createPublicClient } from "@supa/supabase/src/client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import type { AppRouterInstance } from "next/dist/shared/lib/app-router-context.shared-runtime";

export default function SignIn() {
	const router = useRouter();
	const [email, setEmail] = useState("");
	const [password, setPassword] = useState("");
	const [authMethod, setAuthMethod] = useState<"password" | "magic-link">("password");
	const [sent, setSent] = useState(false);
	const [loading, setLoading] = useState(false);
	const [error, setError] = useState<string | null>(null);

	async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
		e.preventDefault();
		setError(null);
		setLoading(true);

		try {
			// Create the client only in the browser and only on user action
			const supabase = createPublicClient();

			if (authMethod === "magic-link") {
				// Sign in with magic link
				const { error } = await supabase.auth.signInWithOtp({
					email,
					options: { emailRedirectTo: `${window.location.origin}/app` },
				});
				if (error) throw error;
				setSent(true);
			} else {
				// Sign in with password
				const { data, error } = await supabase.auth.signInWithPassword({
					email,
					password,
				});
				if (error) throw error;
				
				// Redirect to profile page on successful sign in
				if (data?.user) {
					// Type assertion for router to avoid TypeScript errors
					(router as AppRouterInstance).push("/app/profile");
				}
			}
		} catch (err: any) {
			setError(err.message || "An error occurred during sign in");
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
		},
		tabButton: {
			padding: "8px 16px",
			margin: "0 8px 16px 0",
			border: "1px solid #ddd",
			borderRadius: "8px",
			cursor: "pointer",
			background: "transparent",
		},
		activeTab: {
			backgroundColor: "#0070f3",
			color: "white",
			borderColor: "#0070f3",
		}
	};

	return (
		<main style={{ padding: 24, maxWidth: 440, margin: "40px auto" }}>
			<h1>Sign in</h1>

			<div style={{ marginBottom: "20px" }}>
				<button 
					onClick={() => setAuthMethod("password")} 
					style={{
						...formStyles.tabButton,
						...(authMethod === "password" ? formStyles.activeTab : {})
					}}
				>
					Password
				</button>
				<button 
					onClick={() => setAuthMethod("magic-link")} 
					style={{
						...formStyles.tabButton,
						...(authMethod === "magic-link" ? formStyles.activeTab : {})
					}}
				>
					Magic Link
				</button>
			</div>

			{sent ? (
				<p>Check your email for a magic link.</p>
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

					{authMethod === "password" && (
						<div>
							<label htmlFor="password">Password</label>
							<input
								id="password"
								type="password"
								placeholder="Password"
								value={password}
								onChange={(e) => setPassword(e.target.value)}
								style={formStyles.input}
								required={authMethod === "password"}
							/>
						</div>
					)}

					<button 
						type="submit" 
						style={formStyles.button}
						disabled={loading}
					>
						{loading ? "Signing in..." : 
						 authMethod === "magic-link" ? "Send magic link" : "Sign in"}
					</button>

					{error && <p style={{ color: "crimson" }}>{error}</p>}

					<p style={{ marginTop: "20px" }}>
						Don't have an account?{" "}
						<a href="/sign-up" style={formStyles.link}>
							Sign up
						</a>
					</p>
				</form>
			)}
		</main>
	);
}
