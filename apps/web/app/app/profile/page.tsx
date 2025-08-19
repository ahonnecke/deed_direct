"use client";
export const dynamic = "force-dynamic";

import { createPublicClient } from "@supa/supabase/src/client.browser";
import { useEffect, useState } from "react";

type Profile = { id: string; full_name: string | null };

export default function ProfilePage() {
	const [loading, setLoading] = useState(true);
	const [error, setError] = useState<string | null>(null);
	const [profile, setProfile] = useState<Profile | null>(null);
	const [name, setName] = useState("");

	useEffect(() => {
		const supabase = createPublicClient();
		(async () => {
			try {
				const {
					data: { user },
				} = await supabase.auth.getUser();
				if (!user) {
					setError("Not signed in");
					setLoading(false);
					return;
				}
				const { data, error } = await supabase
					.from("profiles")
					.select("*")
					.eq("id", user.id)
					.maybeSingle();
				if (error) throw error;
				const p = data ?? ({ id: user.id, full_name: "" } as Profile);
				setProfile(p);
				setName(p.full_name ?? "");
			} catch (e: any) {
				setError(e.message ?? "Failed to load");
			} finally {
				setLoading(false);
			}
		})();
	}, []);

	async function onSave(e: React.FormEvent) {
		e.preventDefault();
		setError(null);
		const supabase = createPublicClient();
		const {
			data: { user },
		} = await supabase.auth.getUser();
		if (!user) {
			setError("Not signed in");
			return;
		}
		const { error } = await supabase
			.from("profiles")
			.upsert({ id: user.id, full_name: name }, { onConflict: "id" });
		if (error) setError(error.message);
	}

	if (loading) return <main style={{ padding: 24 }}>Loading…</main>;
	if (error)
		return (
			<main style={{ padding: 24, color: "crimson" }}>Error: {error}</main>
		);

	return (
		<main style={{ padding: 24, maxWidth: 640, margin: "0 auto" }}>
			<h1>Profile</h1>
			<form onSubmit={onSave}>
				<input
					value={name}
					onChange={(e) => setName(e.target.value)}
					placeholder="Full name"
					style={{
						width: "100%",
						padding: 12,
						margin: "12px 0",
						border: "1px solid #ddd",
						borderRadius: 8,
					}}
				/>
				<button type="submit">Save</button>
			</form>
		</main>
	);
}
