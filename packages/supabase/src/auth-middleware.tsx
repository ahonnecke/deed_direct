"use client";

import { useEffect, ReactNode } from "react";
import { useAuth } from "./auth-context";

interface ProtectedRouteProps {
  children: ReactNode;
}

export function ProtectedRoute({ children }: ProtectedRouteProps) {
  const { user, isLoading } = useAuth();
  // Use window.location for navigation instead of Next.js router to avoid type issues
  const pathname = typeof window !== 'undefined' ? window.location.pathname : '';

  useEffect(() => {
    // If not loading and no user, redirect to sign-in
    if (!isLoading && !user) {
      // Store the current path to redirect back after sign-in
      if (typeof window !== 'undefined') {
        sessionStorage.setItem("redirectAfterSignIn", pathname);
        window.location.href = "/sign-in";
      }
    }
  }, [user, isLoading, pathname]);

  // Show loading state while checking authentication
  if (isLoading) {
    return (
      <div style={{ display: "flex", justifyContent: "center", alignItems: "center", height: "100vh" }}>
        <p>Loading...</p>
      </div>
    );
  }

  // If authenticated, render children
  return user ? <>{children}</> : null;
}

interface PublicOnlyRouteProps {
  children: ReactNode;
}

export function PublicOnlyRoute({ children }: PublicOnlyRouteProps) {
  const { user, isLoading } = useAuth();

  useEffect(() => {
    // If authenticated, redirect to app home or stored redirect path
    if (!isLoading && user) {
      if (typeof window !== 'undefined') {
        const redirectPath = sessionStorage.getItem("redirectAfterSignIn") || "/app/profile";
        sessionStorage.removeItem("redirectAfterSignIn");
        window.location.href = redirectPath;
      }
    }
  }, [user, isLoading]);

  // Show loading state while checking authentication
  if (isLoading) {
    return (
      <div style={{ display: "flex", justifyContent: "center", alignItems: "center", height: "100vh" }}>
        <p>Loading...</p>
      </div>
    );
  }

  // If not authenticated, render children
  return !user ? <>{children}</> : null;
}
