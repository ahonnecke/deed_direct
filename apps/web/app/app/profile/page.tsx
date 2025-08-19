"use client";
import { createPublicClient } from "@supa/supabase/src/client.browser";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { z } from "zod";

const ProfileSchema = z.object({ full_name: z.string().min(1, "Required") });

export default function ProfilePage() {
	const supabase = createPublicClient();
	const qc = useQueryClient();

	const { data, isLoading } = useQuery({
		queryKey: ["profile"],
		queryFn: async () => {
			const {
				data: { user },
			} = await supabase.auth.getUser();
			if (!user) throw new Error("Not signed in");
			const { data: rows, error } = await supabase
				.from("profiles")
				.select("*")
				.eq("id", user.id)
				.maybeSingle();
			if (error) throw error;
			return rows ?? { id: user.id, full_name: "" };
		},
	});

	const mutation = useMutation({
		mutationFn: async (values: { full_name: string }) => {
			const parsed = ProfileSchema.parse(values);
			const {
				data: { user },
			} = await supabase.auth.getUser();
			if (!user) throw new Error("Not signed in");
			const { error } = await supabase
				.from("profiles")
				.upsert(
					{ id: user.id, full_name: parsed.full_name },
					{ onConflict: "id" },
				);
			if (error) throw error;
		},
		onSuccess: () => qc.invalidateQueries({ queryKey: ["profile"] }),
	});

	if (isLoading) return <p style={{ padding: 24 }}>Loading…</p>;
	const name = data?.full_name ?? "";

	return (
		<main style={{ padding: 24, maxWidth: 640, margin: "0 auto" }}>
			<h1>Profile</h1>
			<form
				onSubmit={(e) => {
					e.preventDefault();
					const form = new FormData(e.currentTarget as HTMLFormElement);
					mutation.mutate({ full_name: String(form.get("full_name") || "") });
				}}
			>
				<input
					name="full_name"
					defaultValue={name}
					placeholder="Full name"
					style={{
						width: "100%",
						padding: 12,
						margin: "12px 0",
						border: "1px solid #ddd",
						borderRadius: 8,
					}}
				/>
				<button type="submit" disabled={mutation.isPending}>
					{mutation.isPending ? "Saving…" : "Save"}
				</button>
			</form>
		</main>
	);
}
