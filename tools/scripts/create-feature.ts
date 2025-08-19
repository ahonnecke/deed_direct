#!/usr/bin/env tsx
// Usage: pnpm gen:feature path/to/feature.yaml
import fs from "fs-extra";
import path from "path";
import YAML from "yaml";

const ROOT = process.cwd();

type Column = {
	name: string;
	type: string;
	default?: string;
	nullable?: boolean;
	pk?: boolean;
};
type Table = { name: string; columns: Column[]; rls: string };
type Route = {
	platforms: ("web" | "mobile")[];
	path: string;
	auth: "public" | "protected";
	screens: string[];
};
type Spec = {
	name: string;
	description?: string;
	routes: Route[];
	tables: Table[];
};

function marker(name: string, file: string) {
	return `// @gen:start(${name}:${file})`;
}
const GEN_END = `// @gen:end`;

function insertBetweenMarkers(
	content: string,
	start: string,
	end: string,
	payload: string,
) {
	const s = content.indexOf(start);
	const e = content.indexOf(end, s + start.length);
	if (s === -1 || e === -1) {
		return content + `\n\n${start}\n${payload}\n${end}\n`;
	}
	return (
		content.slice(0, s + start.length) + `\n${payload}\n` + content.slice(e)
	);
}

function ensureFile(
	filePath: string,
	header: string,
	start: string,
	end: string,
) {
	if (!fs.existsSync(filePath)) {
		fs.ensureDirSync(path.dirname(filePath));
		fs.writeFileSync(filePath, `${header}\n\n${start}\n${end}\n`);
	}
}

function genSchema(name: string) {
	return `import { z } from 'zod'\n\nexport const ${name}FormSchema = z.object({\n  title: z.string().min(1),\n})\nexport type ${name}Form = z.infer<typeof ${name}FormSchema>\n`;
}

function genQueries(name: string) {
	return `export const ${name}Keys = {\n  all: ['${name}'] as const,\n}\n`;
}

function genComponent(name: string) {
	return `export default function ${name}Screen() {\n  return (<div>${name} works</div>)\n}\n`;
}

function toPascal(s: string) {
	return s
		.replace(/(^|[-_\\s])(\\w)/g, (_, __, c) => c.toUpperCase())
		.replace(/[^a-zA-Z0-9]/g, "");
}

function timestamp() {
	// YYYYMMDDHHmm
	const d = new Date();
	const pad = (n: number) => String(n).padStart(2, "0");
	return `${d.getUTCFullYear()}${pad(d.getUTCMonth() + 1)}${pad(d.getUTCDate())}${pad(d.getUTCHours())}${pad(d.getUTCMinutes())}`;
}

async function main() {
	const specPath = process.argv[2];
	if (!specPath) {
		console.error("Usage: pnpm gen:feature path/to/feature.yaml");
		process.exit(1);
	}
	const raw = await fs.readFile(specPath, "utf-8");
	const spec = YAML.parse(raw) as Spec;
	const feat = spec.name;
	const Pascal = toPascal(feat);

	// Shared feature skeleton
	const base = path.join(ROOT, "packages/shared/src/features", feat);
	fs.ensureDirSync(path.join(base, "components"));
	fs.ensureDirSync(path.join(base, "hooks"));

	// schemas.ts
	const schemasFile = path.join(base, "schemas.ts");
	const schemasStart = marker(feat, "schemas.ts");
	ensureFile(schemasFile, `// Schemas for ${feat}`, schemasStart, GEN_END);
	fs.writeFileSync(
		schemasFile,
		insertBetweenMarkers(
			await fs.readFile(schemasFile, "utf-8"),
			schemasStart,
			GEN_END,
			genSchema(Pascal),
		),
	);

	// queries.ts
	const queriesFile = path.join(base, "queries.ts");
	const queriesStart = marker(feat, "queries.ts");
	ensureFile(queriesFile, `// Query keys for ${feat}`, queriesStart, GEN_END);
	fs.writeFileSync(
		queriesFile,
		insertBetweenMarkers(
			await fs.readFile(queriesFile, "utf-8"),
			queriesStart,
			GEN_END,
			genQueries(feat),
		),
	);

	// component stub
	const compFile = path.join(base, "components", "Index.tsx");
	const compStart = marker(feat, "components/Index.tsx");
	ensureFile(compFile, `// Component for ${feat}`, compStart, GEN_END);
	fs.writeFileSync(
		compFile,
		insertBetweenMarkers(
			await fs.readFile(compFile, "utf-8"),
			compStart,
			GEN_END,
			genComponent(Pascal),
		),
	);

	// App routes (align with your protected area under /app)
	for (const r of spec.routes) {
		if (r.platforms.includes("web")) {
			const webPage = path.join(ROOT, "apps/web/app/app", feat, "page.tsx");
			const start = marker(feat, "web/page.tsx");
			ensureFile(webPage, `// Web page for ${feat}`, start, GEN_END);
			fs.writeFileSync(
				webPage,
				insertBetweenMarkers(
					await fs.readFile(webPage, "utf-8"),
					start,
					GEN_END,
					`export default function Page(){ return (<div>${feat} web page</div>) }`,
				),
			);
		}
		if (r.platforms.includes("mobile")) {
			const mobPage = path.join(
				ROOT,
				"apps/mobile/app/(protected)",
				feat,
				"index.tsx",
			);
			const start = marker(feat, "mobile/index.tsx");
			ensureFile(mobPage, `// Mobile screen for ${feat}`, start, GEN_END);
			fs.writeFileSync(
				mobPage,
				insertBetweenMarkers(
					await fs.readFile(mobPage, "utf-8"),
					start,
					GEN_END,
					`import React from 'react'\nimport { View, Text } from 'react-native'\nexport default function Screen(){ return (<View><Text>${feat} mobile screen</Text></View>) }`,
				),
			);
		}
	}

	// Migration for tables
	const stamp = timestamp();
	const migLines: string[] = [`-- ${stamp}__feature_${feat}.sql`];
	for (const t of spec.tables) {
		migLines.push(`create table if not exists public.${t.name} (`);
		const cols = t.columns.map((c) => {
			const parts = [c.name, c.type];
			if (c.pk) parts.push("primary key");
			if (c.nullable === false) parts.push("not null");
			if (c.default) parts.push(`default ${c.default}`);
			return "  " + parts.join(" ");
		});
		migLines.push(cols.join(",\n"));
		migLines.push(");");
		migLines.push(`alter table public.${t.name} enable row level security;`);
		if (t.rls?.trim()) migLines.push(t.rls.trim());
		migLines.push("");
	}
	const migPath = path.join(
		ROOT,
		"supabase/migrations",
		`${stamp}__feature_${feat}.sql`,
	);
	fs.ensureDirSync(path.dirname(migPath));
	fs.writeFileSync(migPath, migLines.join("\n"));

	console.log(`Generated feature '${feat}'.`);
}

main().catch((e) => {
	console.error(e);
	process.exit(1);
});
