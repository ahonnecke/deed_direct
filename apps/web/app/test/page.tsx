"use client";

import { useState, useEffect } from "react";

export default function TestPage() {
  const [envVars, setEnvVars] = useState<Record<string, string | undefined>>({});
  const [buildTimeVars, setBuildTimeVars] = useState<Record<string, string>>({});
  
  useEffect(() => {
    // Collect all environment variables that start with NEXT_PUBLIC
    const vars: Record<string, string | undefined> = {};
    
    // Add the Supabase environment variables
    vars["NEXT_PUBLIC_SUPABASE_URL"] = process.env.NEXT_PUBLIC_SUPABASE_URL;
    vars["NEXT_PUBLIC_SUPABASE_ANON_KEY"] = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
    
    // Add Node environment
    vars["NODE_ENV"] = process.env.NODE_ENV;
    
    // Add all process.env keys
    Object.keys(process.env).forEach(key => {
      vars[key] = process.env[key];
    });
    
    setEnvVars(vars);
    
    // These are build-time variables that are injected by Next.js
    setBuildTimeVars({
      // @ts-ignore - these are injected at build time
      NEXT_PUBLIC_SUPABASE_URL: process.env.NEXT_PUBLIC_SUPABASE_URL || "Not set at build time",
      // @ts-ignore - these are injected at build time
      NEXT_PUBLIC_SUPABASE_ANON_KEY: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ? "[REDACTED]" : "Not set at build time"
    });
  }, []);

  return (
    <div style={{ padding: "20px", fontFamily: "monospace" }}>
      <h1>Environment Variable Test</h1>
      
      <div style={{ marginTop: "20px" }}>
        <h2>Runtime Environment Variables:</h2>
        <pre style={{ 
          background: "#f5f5f5", 
          padding: "15px", 
          borderRadius: "5px",
          overflow: "auto"
        }}>
          {JSON.stringify(envVars, null, 2)}
        </pre>
      </div>
      
      <div style={{ marginTop: "20px" }}>
        <h2>Build Time Variables:</h2>
        <pre style={{ 
          background: "#f5f5f5", 
          padding: "15px", 
          borderRadius: "5px",
          overflow: "auto"
        }}>
          {JSON.stringify(buildTimeVars, null, 2)}
        </pre>
      </div>
      
      <div style={{ marginTop: "20px" }}>
        <h2>Validation Results:</h2>
        <ul>
          {Object.entries(envVars).filter(([key]) => 
            key.startsWith("NEXT_PUBLIC_") || key === "NODE_ENV"
          ).map(([key, value]) => (
            <li key={key} style={{ 
              marginBottom: "10px",
              color: value ? "green" : "red" 
            }}>
              {key}: {value ? "✓ Available" : "✗ Missing"}
              {value && key !== "NEXT_PUBLIC_SUPABASE_ANON_KEY" && 
                <span style={{ opacity: 0.7 }}> 
                  ({typeof value === 'string' && value.length > 10 ? `${value.substring(0, 10)}...` : value})
                </span>
              }
              {value && key === "NEXT_PUBLIC_SUPABASE_ANON_KEY" && 
                <span style={{ opacity: 0.7 }}> (REDACTED)</span>
              }
            </li>
          ))}
        </ul>
      </div>
      
      <div style={{ marginTop: "20px" }}>
        <h2>Next.js Environment:</h2>
        <ul>
          <li>NODE_ENV: {process.env.NODE_ENV}</li>
          <li>NEXT_RUNTIME: {process.env.NEXT_RUNTIME || "Not set"}</li>
        </ul>
      </div>
    </div>
  );
}
