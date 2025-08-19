"use client";
import { createPublicClient } from "@supa/supabase/src/client.browser";
import { useState } from "react";

export default function SignIn() {
	const [email, setEmail] = useState("");
	const [sent, setSent] = useState(false);
	const supabase = createPublicClient();
	return (
		<main style={{ padding: 24, maxWidth: 440, margin: "40px auto" }}>
			<h1>Sign in</h1>
			{sent ? (
				<p>Check your email for a magic link.</p>
			) : (
				<form
					onSubmit={async (e) => {
						e.preventDefault();
						await supabase.auth.signInWithOtp({
							email,
							options: { emailRedirectTo: `${window.location.origin}/app` },
						});
						setSent(true);
					}}
				>
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
				</form>
			)}
		</main>
	);
}
