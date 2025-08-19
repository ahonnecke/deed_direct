import { createServerClient } from "@supabase/ssr";

export function createSSRClient(cookies: {
	get: (name: string) => string | undefined;
	set?: (name: string, value: string, options?: any) => void;
	remove?: (name: string, options?: any) => void;
}) {
	const url = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL!;
	const key =
		process.env.SUPABASE_ANON_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;
	return createServerClient(url, key, { cookies });
}
