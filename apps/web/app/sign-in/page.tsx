"use client";

// Tell Next: do NOT statically prerender this page
export const dynamic = "force-dynamic";

import { createPublicClient } from "@supa/supabase/src/client.browser";
import { useState } from "react";

export default function SignIn() {
	const [email, setEmail] = useState("");
	const [sent, setSent] = useState(false);
	const [error, setError] = useState<string | null>(null);

	async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
		e.preventDefault();
		setError(null);
		// Create the client only in the browser and only on user action
		const supabase = createPublicClient();
		const { error } = await supabase.auth.signInWithOtp({
			email,
			options: { emailRedirectTo: `${window.location.origin}/app` },
		});
		if (error) setError(error.message);
		else setSent(true);
	}

	return (
		<main style={{ padding: 24, maxWidth: 440, margin: "40px auto" }}>
			<h1>Sign in</h1>
			{sent ? (
				<p>Check your email for a magic link.</p>
			) : (
				<form onSubmit={onSubmit}>
					<input
						placeholder="you@example.com"
						value={email}
						onChange={(e) => setEmail(e.target.value)}
						style={{
							width: "100%",
							padding: 12,
							margin: "12px 0",
							border: "1px solid #ddd",
							borderRadius: 8,
						}}
					/>
					<button type="submit">Send magic link</button>
					{error && <p style={{ color: "crimson" }}>{error}</p>}
				</form>
			)}
		</main>
	);
}
