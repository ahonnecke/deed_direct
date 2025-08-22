"use client";
export const dynamic = "force-dynamic";

import { createPublicClient } from "@supa/supabase/src/client.browser";
import { useEffect, useState } from "react";
import { useAuth } from "@supa/supabase/src/auth-context";
import { ProtectedRoute } from "@supa/supabase/src/auth-middleware";
// Use window.location for navigation instead of Next.js router to avoid type issues

type Profile = { id: string; full_name: string | null };

function ProfileContent() {
	const { user, signOut } = useAuth();
	const [loading, setLoading] = useState(true);
	const [error, setError] = useState<string | null>(null);
	const [profile, setProfile] = useState<Profile | null>(null);
	const [name, setName] = useState("");
	const [isSaving, setIsSaving] = useState(false);

	useEffect(() => {
		if (!user) return;
		
		const supabase = createPublicClient();
		(async () => {
			try {
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
		if (!user) {
			setError("Not signed in");
			return;
		}
		
		setError(null);
		setIsSaving(true);
		const supabase = createPublicClient();
		try {
			const { error } = await supabase
				.from("profiles")
				.upsert({ id: user.id, full_name: name }, { onConflict: "id" });
			if (error) throw error;
		} catch (err: any) {
			setError(err.message || "Failed to save profile");
		} finally {
			setIsSaving(false);
		}
	}

	if (loading) return <main style={{ padding: 24 }}>Loading…</main>;
	if (error)
		return (
			<main style={{ padding: 24, color: "crimson" }}>Error: {error}</main>
		);

	const handleSignOut = async () => {
		await signOut();
		window.location.href = "/sign-in";
	};

	const styles = {
		input: {
			width: "100%",
			padding: 12,
			margin: "12px 0",
			border: "1px solid #ddd",
			borderRadius: 8,
		},
		button: {
			padding: "10px 16px",
			backgroundColor: "#0070f3",
			color: "white",
			border: "none",
			borderRadius: 8,
			cursor: "pointer",
			marginRight: 10,
		},
		dangerButton: {
			padding: "10px 16px",
			backgroundColor: "#f44336",
			color: "white",
			border: "none",
			borderRadius: 8,
			cursor: "pointer",
			marginTop: 20,
		},
		userInfo: {
			backgroundColor: "#f5f5f5",
			padding: 16,
			borderRadius: 8,
			marginBottom: 20,
		},
	};

	return (
		<main style={{ padding: 24, maxWidth: 640, margin: "0 auto" }}>
			<h1>Profile</h1>
			
			<div style={styles.userInfo}>
				<p><strong>Email:</strong> {user?.email}</p>
				<p><strong>User ID:</strong> {user?.id}</p>
			</div>
			
			<form onSubmit={onSave}>
				<label htmlFor="fullName">Full Name</label>
				<input
					id="fullName"
					value={name}
					onChange={(e) => setName(e.target.value)}
					placeholder="Full name"
					style={styles.input}
				/>
				
				<div>
					<button 
						type="submit" 
						style={styles.button}
						disabled={isSaving}
					>
						{isSaving ? "Saving..." : "Save Profile"}
					</button>
				</div>
				
				{error && <p style={{ color: "crimson", marginTop: 10 }}>{error}</p>}
			</form>
			
			<button 
				onClick={handleSignOut} 
				style={styles.dangerButton}
			>
				Sign Out
			</button>
		</main>
	);
}

export default function ProfilePage() {
	return (
		<ProtectedRoute>
			<ProfileContent />
		</ProtectedRoute>
	);
}
