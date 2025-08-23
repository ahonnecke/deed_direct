"use client";
export const dynamic = "force-dynamic";

import { createPublicClient } from "@supa/supabase/src/client";
import { useEffect, useState } from "react";
import { useAuth } from "@supa/supabase/src/auth-context";
import { ProtectedRoute } from "@supa/supabase/src/auth-middleware";
// Use window.location for navigation instead of Next.js router to avoid type issues

type Profile = { 
	id: string; 
	first_name: string | null; 
	last_name: string | null; 
	username: string | null; 
	avatar_url: string | null; 
	onboarded: boolean;
	timezone: string;
	locale: string;
	preferences: Record<string, any>;
};

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
				// Try to get the profile
				const { data, error } = await supabase
					.from("user_profiles")
					.select("*")
					.eq("id", user.id)
					.maybeSingle();
				
				if (error) throw error;
				
				// If profile doesn't exist, create a temporary local profile
				// We'll save it to the database when the user clicks Save
				if (!data) {
					const newProfile = {
						id: user.id,
						first_name: "",
						last_name: "",
						username: null,
						avatar_url: null,
						onboarded: false,
						timezone: "UTC",
						locale: "en-US",
						preferences: {}
					} as Profile;
					
					setProfile(newProfile);
					setName("");
				} else {
					// Use existing profile
					setProfile(data);
					setName(data.first_name ?? "");
				}
			} catch (e: any) {
				setError(e.message ?? "Failed to load or create profile");
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
				.from("user_profiles")
				.upsert({ id: user.id, first_name: name }, { onConflict: "id" });
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
				<label htmlFor="firstName">First Name</label>
				<input
					id="firstName"
					value={name}
					onChange={(e) => setName(e.target.value)}
					placeholder="First name"
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
