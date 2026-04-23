# Phase 3: Frontend Web Development

**Step-by-step guide to building the Next.js web application with authentication**

---

## Overview

The web frontend is where users interact with our application. We need:
1. Public pages (landing, login, register)
2. Patient dashboard (upload images, view history)
3. Doctor dashboard (view all predictions, add expert opinions)
4. Admin dashboard (approve doctors, view stats)
5. Authentication integration with AWS Cognito

### Technology Stack
- **Framework**: Next.js 14 (App Router)
- **Language**: TypeScript
- **Styling**: Tailwind CSS
- **State Management**: React Context + hooks
- **Auth**: AWS Cognito (via Amplify or custom)
- **API Client**: Native fetch with typed interfaces

---

## Step 1: Create Next.js Project

```bash
cd C:/Users/saiyu/Desktop/projects/KI_projects/Skin_Lesion_GRADCAM_Classification

# Create the frontend directory (if not exists)
mkdir -p Skin_Lesion_Classification_frontend

cd Skin_Lesion_Classification_frontend

# Create Next.js app
npx create-next-app@latest . \
    --typescript \
    --tailwind \
    --app \
    --no-src-dir \
    --import-alias "@/*" \
    --no-git

# When asked:
# - Would you like to customize the import alias? → No (@/*)
# - Use src/ directory? → No
```

### Install Additional Dependencies

```bash
npm install @aws-amplify/ui-react \
    @aws-amplify/auth \
    @chakra-ui/react \
    @emotion/react \
    @emotion/styled \
    framer-motion \
    react-hook-form \
    @hookform/resolvers \
    zod \
    date-fns \
    lucide-react
```

---

## Step 2: Project Structure

### Create Directory Structure

```bash
mkdir -p app/\(auth\)/login
mkdir -p app/\(auth\)/register
mkdir -p app/\(auth\)/verify
mkdir -p app/\(dashboard\)/patient
mkdir -p app/\(dashboard\)/doctor
mkdir -p app/\(dashboard\)/admin
mkdir -p app/api/predict
mkdir -p app/api/explain
mkdir -p app/api/feedback
mkdir -p app/api/admin
mkdir -p components/ui
mkdir -p components/auth
mkdir -p components/dashboard
mkdir -p components/prediction
mkdir -p context
mkdir -p hooks
mkdir -p lib
mkdir -p types
mkdir -p services
```

### What This Structure Does

```
app/
├── (auth)/               # Auth routes (login, register, verify)
│   ├── login/
│   ├── register/
│   └── verify/
├── (dashboard)/          # Protected dashboard routes
│   ├── patient/         # Patient dashboard
│   ├── doctor/          # Doctor dashboard
│   └── admin/           # Admin dashboard
├── api/                  # API route handlers (optional BFF pattern)
├── components/          # Reusable UI components
├── context/             # React Context providers
├── hooks/               # Custom hooks
├── lib/                 # Utilities
├── services/            # API client services
└── types/               # TypeScript types
```

### Why Use Route Groups?

Route groups `(auth)` and `(dashboard)` don't affect the URL path. They're just for organization:
- `(auth)/login/page.tsx` → `/login`
- `(dashboard)/patient/page.tsx` → `/patient`
- `(dashboard)/admin/page.tsx` → `/admin`

---

## Step 3: Type Definitions

Create `types/index.ts`:

```typescript
// ============ Auth Types ============

export type UserRole = "patient" | "doctor" | "admin";

export interface User {
  id: string;
  email: string;
  role: UserRole;
  approved: boolean;
  full_name?: string;
  medical_license?: string;
  created_at: string;
  last_login_at?: string;
}

export interface AuthState {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
}

// ============ Prediction Types ============

export interface PredictionResponse {
  prediction_id: string;
  diagnosis: "benign" | "malignant";
  confidence: number;
  class_probabilities: {
    benign: number;
    malignant: number;
  };
  model_version: string;
  processing_time_ms: number;
  created_at: string;
}

export interface ExplainResponse {
  explanation_id: string;
  method: string;
  heatmaps: {
    original: string;
    heatmap: string;
    overlay: string;
  };
  metrics: {
    focus_area_percentage: number;
    cam_max: number;
    cam_mean: number;
  };
}

export interface FeedbackRequest {
  prediction_id: string;
  consent: true;
  user_label?: "benign" | "malignant";
}

export interface FeedbackResponse {
  feedback_id: string;
  status: "queued";
  message: string;
}

// ============ Expert Opinion Types ============

export interface ExpertOpinion {
  id: string;
  prediction_id: string;
  doctor_id: string;
  doctor_name: string;
  diagnosis: "benign" | "malignant";
  notes?: string;
  created_at: string;
}

export interface ExpertOpinionRequest {
  prediction_id: string;
  diagnosis: "benign" | "malignant";
  notes?: string;
}

// ============ Admin Types ============

export interface DoctorApprovalRequest {
  doctor_id: string;
  action: "approve" | "reject";
  reason?: string;
}

export interface AdminStats {
  total_users: number;
  total_patients: number;
  total_doctors: number;
  pending_doctors: number;
  total_predictions: number;
  pool_size: number;
  last_retrain_date?: string;
}

// ============ API Error Types ============

export interface APIError {
  detail: string;
  status_code: number;
}
```

---

## Step 4: API Client

Create `lib/api.ts`:

```typescript
import {
  User,
  PredictionResponse,
  ExplainResponse,
  FeedbackRequest,
  FeedbackResponse,
  ExpertOpinionRequest,
  ExpertOpinion,
  DoctorApprovalRequest,
  AdminStats,
} from "@/types";

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8080";

class APIError extends Error {
  status: number;

  constructor(message: string, status: number) {
    super(message);
    this.status = status;
    this.name = "APIError";
  }
}

async function handleResponse<T>(response: Response): Promise<T> {
  if (!response.ok) {
    const error = await response.json().catch(() => ({ detail: "Unknown error" }));
    throw new APIError(error.detail || "Request failed", response.status);
  }
  return response.json();
}

export const api = {
  // ============ Auth ============

  async getCurrentUser(): Promise<User> {
    const response = await fetch(`${API_BASE_URL}/api/v1/users/me`, {
      credentials: "include",
    });
    return handleResponse<User>(response);
  },

  // ============ Predictions ============

  async predict(imageFile: File): Promise<PredictionResponse> {
    const formData = new FormData();
    formData.append("image", imageFile);

    const response = await fetch(`${API_BASE_URL}/api/v1/predict`, {
      method: "POST",
      body: formData,
      credentials: "include",
    });

    return handleResponse<PredictionResponse>(response);
  },

  async explain(
    predictionId: string,
    method: string
  ): Promise<ExplainResponse> {
    const response = await fetch(`${API_BASE_URL}/api/v1/explain`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ prediction_id: predictionId, method }),
      credentials: "include",
    });

    return handleResponse<ExplainResponse>(response);
  },

  async getPredictionHistory(): Promise<PredictionResponse[]> {
    const response = await fetch(`${API_BASE_URL}/api/v1/users/me/predictions`, {
      credentials: "include",
    });
    return handleResponse<PredictionResponse[]>(response);
  },

  async getPredictionDetail(predictionId: string): Promise<PredictionResponse & { expert_opinions: ExpertOpinion[] }> {
    const response = await fetch(
      `${API_BASE_URL}/api/v1/predictions/${predictionId}`,
      { credentials: "include" }
    );
    return handleResponse(response);
  },

  // ============ Expert Opinions (Doctor Validation) ============

  async submitExpertOpinion(request: ExpertOpinionRequest): Promise<ExpertOpinion> {
    const response = await fetch(`${API_BASE_URL}/api/v1/expert-opinions`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(request),
      credentials: "include",
    });
    return handleResponse<ExpertOpinion>(response);
  },

  async getPendingReviewCases(): Promise<any[]> {
    const response = await fetch(
      `${API_BASE_URL}/api/v1/predictions/pending-review`,
      { credentials: "include" }
    );
    return handleResponse<any[]>(response);
  },

  // ============ Consent (Patient) ============

  async submitConsent(request: FeedbackRequest): Promise<FeedbackResponse> {
    const response = await fetch(`${API_BASE_URL}/api/v1/feedback`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(request),
      credentials: "include",
    });
    return handleResponse<FeedbackResponse>(response);
  },

  async getFeedbackStats(): Promise<{
    pool_size: number;
    minimum_to_retrain: number;
    ready_to_retrain: boolean;
  }> {
    const response = await fetch(`${API_BASE_URL}/api/v1/feedback/stats`, {
      credentials: "include",
    });
    return handleResponse(response);
  },

  // ============ Admin Training Pool ============

  async getAdminStats(): Promise<AdminStats> {
    const response = await fetch(`${API_BASE_URL}/api/v1/admin/stats`, {
      credentials: "include",
    });
    return handleResponse<AdminStats>(response);
  },

  async getTrainingPoolPending(): Promise<any[]> {
    const response = await fetch(`${API_BASE_URL}/api/v1/admin/training-pool/pending`, {
      credentials: "include",
    });
    return handleResponse<any[]>(response);
  },

  async approveTrainingCase(caseId: string): Promise<{ message: string }> {
    const response = await fetch(
      `${API_BASE_URL}/api/v1/admin/training-pool/approve/${caseId}`,
      {
        method: "POST",
        credentials: "include",
      }
    );
    return handleResponse(response);
  },

  async rejectTrainingCase(caseId: string): Promise<{ message: string }> {
    const response = await fetch(
      `${API_BASE_URL}/api/v1/admin/training-pool/reject/${caseId}`,
      {
        method: "POST",
        credentials: "include",
      }
    );
    return handleResponse(response);
  },

  async triggerRetraining(): Promise<{ status: string; message: string }> {
    const response = await fetch(
      `${API_BASE_URL}/api/v1/admin/training-pool/retrain`,
      {
        method: "POST",
        credentials: "include",
      }
    );
    return handleResponse(response);
  },

  async getPendingDoctors(): Promise<User[]> {
    const response = await fetch(`${API_BASE_URL}/api/v1/admin/doctors/pending`, {
      credentials: "include",
    });
    return handleResponse<User[]>(response);
  },

  async approveDoctor(request: DoctorApprovalRequest): Promise<{ message: string }> {
    const response = await fetch(`${API_BASE_URL}/api/v1/admin/doctors/approve`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(request),
      credentials: "include",
    });
    return handleResponse(response);
  },

  // ============ GDPR ============

  async requestDataExport(): Promise<{ id: string; download_url: string }> {
    const response = await fetch(`${API_BASE_URL}/api/v1/users/me/export`, {
      method: "POST",
      credentials: "include",
    });
    return handleResponse(response);
  },

  // ============ Health ============

  async healthCheck(): Promise<{ status: string }> {
    const response = await fetch(`${API_BASE_URL}/api/v1/health`);
    return handleResponse(response);
  },

  async getMethods(): Promise<{ methods: string[] }> {
    const response = await fetch(`${API_BASE_URL}/api/v1/methods`);
    return handleResponse(response);
  },
};

export { APIError };
```

---

## Step 5: Authentication Context

Create `context/AuthContext.tsx`:

```typescript
"use client";

import React, { createContext, useContext, useState, useEffect, useCallback } from "react";
import { User, AuthState } from "@/types";
import { api } from "@/lib/api";

interface AuthContextType extends AuthState {
  login: (email: string, password: string) => Promise<void>;
  register: (email: string, password: string, role: string) => Promise<void>;
  logout: () => Promise<void>;
  refreshUser: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  const refreshUser = useCallback(async () => {
    try {
      const currentUser = await api.getCurrentUser();
      setUser(currentUser);
    } catch (error) {
      setUser(null);
    }
  }, []);

  useEffect(() => {
    // Check for existing session on mount
    refreshUser().finally(() => setIsLoading(false));
  }, [refreshUser]);

  const login = async (email: string, password: string) => {
    // In production, this would call Cognito
    // For now, we'll simulate it
    const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password }),
      credentials: "include",
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.detail || "Login failed");
    }

    await refreshUser();
  };

  const register = async (email: string, password: string, role: string) => {
    const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/auth/register`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password, role }),
      credentials: "include",
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.detail || "Registration failed");
    }
  };

  const logout = async () => {
    await fetch(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/auth/logout`, {
      method: "POST",
      credentials: "include",
    });
    setUser(null);
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        isAuthenticated: !!user,
        isLoading,
        login,
        register,
        logout,
        refreshUser,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return context;
}
```

---

## Step 6: Create Auth Layout

Create `app/(auth)/layout.tsx`:

```typescript
export default function AuthLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        <div className="bg-white rounded-2xl shadow-xl p-8">
          {children}
        </div>
      </div>
    </div>
  );
}
```

---

## Step 7: Login Page

Create `app/(auth)/login/page.tsx`:

```typescript
"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useAuth } from "@/context/AuthContext";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const { login } = useAuth();
  const router = useRouter();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setIsLoading(true);

    try {
      await login(email, password);
      router.push("/patient");  // Or determine role and redirect
    } catch (err) {
      setError(err instanceof Error ? err.message : "Login failed");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Logo and Title */}
      <div className="text-center">
        <div className="text-4xl mb-2">🏥</div>
        <h1 className="text-2xl font-bold text-gray-900">Welcome Back</h1>
        <p className="text-gray-600 mt-1">Sign in to your account</p>
      </div>

      {/* Error Message */}
      {error && (
        <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-xl">
          {error}
        </div>
      )}

      {/* Login Form */}
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label htmlFor="email" className="block text-sm font-medium text-gray-700 mb-1">
            Email
          </label>
          <input
            id="email"
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            placeholder="you@example.com"
            required
          />
        </div>

        <div>
          <label htmlFor="password" className="block text-sm font-medium text-gray-700 mb-1">
            Password
          </label>
          <input
            id="password"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            placeholder="••••••••"
            required
          />
        </div>

        <button
          type="submit"
          disabled={isLoading}
          className="w-full bg-blue-600 text-white py-3 rounded-xl font-medium hover:bg-blue-700 transition-colors disabled:opacity-50"
        >
          {isLoading ? "Signing in..." : "Sign In"}
        </button>
      </form>

      {/* Register Link */}
      <div className="text-center text-gray-600">
        Don't have an account?{" "}
        <Link href="/register" className="text-blue-600 font-medium hover:underline">
          Sign up
        </Link>
      </div>

      {/* Divider */}
      <div className="relative">
        <div className="absolute inset-0 flex items-center">
          <div className="w-full border-t border-gray-300"></div>
        </div>
        <div className="relative flex justify-center text-sm">
          <span className="px-2 bg-white text-gray-500">or</span>
        </div>
      </div>

      {/* Social Login */}
      <button
        onClick={() => {/* TODO: Implement Cognito social login */}}
        className="w-full border border-gray-300 py-3 rounded-xl font-medium hover:bg-gray-50 transition-colors flex items-center justify-center gap-2"
      >
        <svg className="w-5 h-5" viewBox="0 0 24 24">
          <path
            fill="currentColor"
            d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
          />
          <path
            fill="currentColor"
            d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
          />
          <path
            fill="currentColor"
            d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
          />
          <path
            fill="currentColor"
            d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
          />
        </svg>
        Continue with Google
      </button>
    </div>
  );
}
```

---

## Step 8: Registration Page

Create `app/(auth)/register/page.tsx`:

```typescript
"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useAuth } from "@/context/AuthContext";

export default function RegisterPage() {
  const [formData, setFormData] = useState({
    email: "",
    password: "",
    confirmPassword: "",
    role: "patient",
    fullName: "",
    medicalLicense: "",
  });
  const [error, setError] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const { register } = useAuth();
  const router = useRouter();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");

    if (formData.password !== formData.confirmPassword) {
      setError("Passwords do not match");
      return;
    }

    if (formData.password.length < 8) {
      setError("Password must be at least 8 characters");
      return;
    }

    if (formData.role === "doctor" && !formData.medicalLicense) {
      setError("Medical license is required for doctor accounts");
      return;
    }

    setIsLoading(true);

    try {
      await register(formData.email, formData.password, formData.role);
      router.push("/verify");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Registration failed");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Logo and Title */}
      <div className="text-center">
        <div className="text-4xl mb-2">🏥</div>
        <h1 className="text-2xl font-bold text-gray-900">Create Account</h1>
        <p className="text-gray-600 mt-1">Join our skin health platform</p>
      </div>

      {/* Error Message */}
      {error && (
        <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-xl">
          {error}
        </div>
      )}

      {/* Registration Form */}
      <form onSubmit={handleSubmit} className="space-y-4">
        {/* Role Selection */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            I am a...
          </label>
          <div className="grid grid-cols-2 gap-3">
            <button
              type="button"
              onClick={() => setFormData({ ...formData, role: "patient" })}
              className={`p-4 rounded-xl border-2 text-left transition-all ${
                formData.role === "patient"
                  ? "border-blue-500 bg-blue-50"
                  : "border-gray-200 hover:border-gray-300"
              }`}
            >
              <div className="text-2xl mb-1">👤</div>
              <div className="font-medium text-gray-900">Patient</div>
              <div className="text-xs text-gray-500">Upload images for analysis</div>
            </button>

            <button
              type="button"
              onClick={() => setFormData({ ...formData, role: "doctor" })}
              className={`p-4 rounded-xl border-2 text-left transition-all ${
                formData.role === "doctor"
                  ? "border-blue-500 bg-blue-50"
                  : "border-gray-200 hover:border-gray-300"
              }`}
            >
              <div className="text-2xl mb-1">👨‍⚕️</div>
              <div className="font-medium text-gray-900">Doctor</div>
              <div className="text-xs text-gray-500">Review and provide opinions</div>
            </button>
          </div>
        </div>

        <div>
          <label htmlFor="fullName" className="block text-sm font-medium text-gray-700 mb-1">
            Full Name
          </label>
          <input
            id="fullName"
            type="text"
            value={formData.fullName}
            onChange={(e) => setFormData({ ...formData, fullName: e.target.value })}
            className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            placeholder="Jane Smith"
            required
          />
        </div>

        {formData.role === "doctor" && (
          <div>
            <label htmlFor="medicalLicense" className="block text-sm font-medium text-gray-700 mb-1">
              Medical License Number
            </label>
            <input
              id="medicalLicense"
              type="text"
              value={formData.medicalLicense}
              onChange={(e) => setFormData({ ...formData, medicalLicense: e.target.value })}
              className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              placeholder="MD-123456"
              required
            />
            <p className="text-xs text-gray-500 mt-1">
              Your license will be verified by an administrator
            </p>
          </div>
        )}

        <div>
          <label htmlFor="email" className="block text-sm font-medium text-gray-700 mb-1">
            Email
          </label>
          <input
            id="email"
            type="email"
            value={formData.email}
            onChange={(e) => setFormData({ ...formData, email: e.target.value })}
            className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            placeholder="you@example.com"
            required
          />
        </div>

        <div>
          <label htmlFor="password" className="block text-sm font-medium text-gray-700 mb-1">
            Password
          </label>
          <input
            id="password"
            type="password"
            value={formData.password}
            onChange={(e) => setFormData({ ...formData, password: e.target.value })}
            className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            placeholder="••••••••"
            required
          />
        </div>

        <div>
          <label htmlFor="confirmPassword" className="block text-sm font-medium text-gray-700 mb-1">
            Confirm Password
          </label>
          <input
            id="confirmPassword"
            type="password"
            value={formData.confirmPassword}
            onChange={(e) => setFormData({ ...formData, confirmPassword: e.target.value })}
            className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            placeholder="••••••••"
            required
          />
        </div>

        <button
          type="submit"
          disabled={isLoading}
          className="w-full bg-blue-600 text-white py-3 rounded-xl font-medium hover:bg-blue-700 transition-colors disabled:opacity-50"
        >
          {isLoading ? "Creating account..." : "Create Account"}
        </button>
      </form>

      {/* Login Link */}
      <div className="text-center text-gray-600">
        Already have an account?{" "}
        <Link href="/login" className="text-blue-600 font-medium hover:underline">
          Sign in
        </Link>
      </div>
    </div>
  );
}
```

---

## Step 9: Dashboard Layout

Create `app/(dashboard)/layout.tsx`:

```typescript
"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/context/AuthContext";
import Link from "next/link";
import { usePathname } from "next/navigation";

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const { user, isAuthenticated, isLoading, logout } = useAuth();
  const router = useRouter();
  const pathname = usePathname();

  useEffect(() => {
    if (!isLoading && !isAuthenticated) {
      router.push("/login");
    }
  }, [isAuthenticated, isLoading, router]);

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <div className="text-4xl mb-4 animate-spin">⏳</div>
          <p className="text-gray-600">Loading...</p>
        </div>
      </div>
    );
  }

  if (!isAuthenticated || !user) {
    return null;
  }

  const isDoctor = user.role === "doctor";
  const isAdmin = user.role === "admin";
  const isPending = user.role === "doctor" && !user.approved;

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Navigation */}
      <nav className="bg-white shadow-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between h-16">
            {/* Logo */}
            <div className="flex items-center">
              <Link href="/" className="flex items-center gap-2">
                <span className="text-2xl">🏥</span>
                <span className="font-bold text-gray-900">SkinLesionAI</span>
              </Link>
            </div>

            {/* Navigation Links */}
            <div className="flex items-center gap-4">
              {isPending ? (
                <div className="bg-yellow-50 text-yellow-700 px-4 py-2 rounded-lg text-sm">
                  ⏳ Account pending approval
                </div>
              ) : (
                <div className="flex items-center gap-4">
                  <Link
                    href="/patient"
                    className={`px-3 py-2 rounded-lg text-sm font-medium ${
                      pathname === "/patient"
                        ? "bg-blue-100 text-blue-700"
                        : "text-gray-600 hover:bg-gray-100"
                    }`}
                  >
                    Dashboard
                  </Link>

                  {(isDoctor || isAdmin) && (
                    <Link
                      href="/doctor"
                      className={`px-3 py-2 rounded-lg text-sm font-medium ${
                        pathname === "/doctor"
                          ? "bg-blue-100 text-blue-700"
                          : "text-gray-600 hover:bg-gray-100"
                      }`}
                    >
                      Doctor View
                    </Link>
                  )}

                  {isAdmin && (
                    <Link
                      href="/admin"
                      className={`px-3 py-2 rounded-lg text-sm font-medium ${
                        pathname === "/admin"
                          ? "bg-blue-100 text-blue-700"
                          : "text-gray-600 hover:bg-gray-100"
                      }`}
                    >
                      Admin
                    </Link>
                  )}
                </div>
              )}

              {/* User Menu */}
              <div className="flex items-center gap-4">
                <div className="text-sm text-right">
                  <div className="font-medium text-gray-900">{user.full_name || user.email}</div>
                  <div className="text-gray-500 capitalize">{user.role}</div>
                </div>
                <button
                  onClick={logout}
                  className="text-gray-400 hover:text-gray-600"
                >
                  Logout
                </button>
              </div>
            </div>
          </div>
        </div>
      </nav>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
        {isPending ? (
          <div className="text-center py-12">
            <div className="text-6xl mb-4">⏳</div>
            <h2 className="text-2xl font-bold text-gray-900 mb-2">Account Pending Approval</h2>
            <p className="text-gray-600 max-w-md mx-auto">
              Your doctor account is waiting for administrator approval.
              You'll be able to access the platform once approved.
            </p>
          </div>
        ) : (
          children
        )}
      </main>
    </div>
  );
}
```

---

## Step 10: Patient Dashboard

Create `app/(dashboard)/patient/page.tsx`:

```typescript
"use client";

import { useState, useCallback } from "react";
import { useAuth } from "@/context/AuthContext";
import { api } from "@/lib/api";
import { PredictionResponse, ExplainResponse } from "@/types";
import ImageUploader from "@/components/prediction/ImageUploader";
import PredictionDisplay from "@/components/prediction/PredictionDisplay";
import XAIViewer from "@/components/prediction/XAIViewer";
import MethodSelector from "@/components/prediction/MethodSelector";
import FeedbackConsent from "@/components/prediction/FeedbackConsent";
import { HISTORY, CAM_METHODS } from "@/lib/constants";

const DEFAULT_METHOD = "gradcam";

export default function PatientDashboard() {
  const { user } = useAuth();
  const [selectedImage, setSelectedImage] = useState<File | null>(null);
  const [prediction, setPrediction] = useState<PredictionResponse | null>(null);
  const [explanation, setExplanation] = useState<ExplainResponse | null>(null);
  const [selectedMethod, setSelectedMethod] = useState(DEFAULT_METHOD);
  const [isPredicting, setIsPredicting] = useState(false);
  const [isExplaining, setIsExplaining] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleImageSelect = useCallback(async (file: File) => {
    setSelectedImage(file);
    setPrediction(null);
    setExplanation(null);
    setError(null);

    setIsPredicting(true);
    try {
      const result = await api.predict(file);
      setPrediction(result);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Prediction failed");
    } finally {
      setIsPredicting(false);
    }
  }, []);

  const handleExplain = useCallback(async () => {
    if (!prediction) return;

    setIsExplaining(true);
    try {
      const result = await api.explain(prediction.prediction_id, selectedMethod);
      setExplanation(result);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Explanation failed");
    } finally {
      setIsExplaining(false);
    }
  }, [prediction, selectedMethod]);

  const handleMethodChange = useCallback((method: string) => {
    setSelectedMethod(method);
  }, []);

  // Fetch explanation when method changes
  useState(() => {
    if (prediction && !isPredicting) {
      handleExplain();
    }
  });

  const handleFeedbackSubmit = useCallback(async () => {
    if (!prediction) return;

    try {
      await api.submitFeedback({
        prediction_id: prediction.prediction_id,
        consent: true,
      });
      alert("Thank you for your contribution!");
    } catch (err) {
      alert(err instanceof Error ? err.message : "Feedback failed");
    }
  }, [prediction]);

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900">
          Welcome, {user?.full_name || user?.email}
        </h1>
        <p className="text-gray-600">Upload a dermoscopy image for AI analysis</p>
      </div>

      {/* Upload Section */}
      <div className="bg-white rounded-xl shadow-sm p-6">
        <ImageUploader onImageSelect={handleImageSelect} />
      </div>

      {/* Error Message */}
      {error && (
        <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-xl">
          {error}
        </div>
      )}

      {/* Loading State */}
      {isPredicting && (
        <div className="bg-white rounded-xl shadow-sm p-8 text-center">
          <div className="text-4xl mb-4 animate-spin">⏳</div>
          <p className="text-gray-600">Analyzing image...</p>
        </div>
      )}

      {/* Prediction Result */}
      {prediction && !isPredicting && (
        <div className="space-y-6">
          <div className="bg-white rounded-xl shadow-sm p-6">
            <h2 className="text-lg font-semibold text-gray-900 mb-4">Prediction Result</h2>
            <PredictionDisplay
              diagnosis={prediction.diagnosis}
              confidence={prediction.confidence}
              classProbabilities={prediction.class_probabilities}
            />
          </div>

          {/* XAI Section */}
          <div className="bg-white rounded-xl shadow-sm p-6">
            <h2 className="text-lg font-semibold text-gray-900 mb-4">Explainability</h2>

            <div className="mb-4">
              <MethodSelector
                selectedMethod={selectedMethod}
                onMethodChange={handleMethodChange}
                disabled={isExplaining}
              />
            </div>

            {isExplaining ? (
              <div className="text-center py-8">
                <div className="text-4xl mb-4 animate-spin">🔄</div>
                <p className="text-gray-600">Generating heatmap...</p>
              </div>
            ) : explanation ? (
              <XAIViewer
                original={explanation.heatmaps.original}
                heatmap={explanation.heatmaps.heatmap}
                overlay={explanation.heatmaps.overlay}
                method={explanation.method}
                focusAreaPercentage={explanation.metrics.focus_area_percentage}
              />
            ) : null}
          </div>

          {/* Feedback Section */}
          <div className="bg-white rounded-xl shadow-sm p-6">
            <FeedbackConsent
              predictionId={prediction.prediction_id}
              onSubmit={handleFeedbackSubmit}
            />
          </div>
        </div>
      )}

      {/* History Section */}
      <div className="bg-white rounded-xl shadow-sm p-6">
        <h2 className="text-lg font-semibold text-gray-900 mb-4">Your Prediction History</h2>
        {/* TODO: Add history list */}
        <p className="text-gray-500 text-sm">No predictions yet</p>
      </div>
    </div>
  );
}
```

---

## Step 11: Create UI Components

### ImageUploader Component

Create `components/prediction/ImageUploader.tsx`:

```typescript
"use client";

import { useState, useCallback } from "react";

interface ImageUploaderProps {
  onImageSelect: (file: File) => void;
}

export default function ImageUploader({ onImageSelect }: ImageUploaderProps) {
  const [isDragging, setIsDragging] = useState(false);

  const handleFile = useCallback((file: File) => {
    if (!file.type.startsWith("image/")) {
      alert("Please select an image file (JPG, PNG, or WEBP)");
      return;
    }
    if (file.size > 10 * 1024 * 1024) {
      alert("File too large. Maximum size is 10MB.");
      return;
    }
    onImageSelect(file);
  }, [onImageSelect]);

  const handleDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
    const file = e.dataTransfer.files[0];
    if (file) handleFile(file);
  }, [handleFile]);

  const handleDragOver = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(true);
  }, []);

  const handleDragLeave = useCallback(() => {
    setIsDragging(false);
  }, []);

  const handleInputChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) handleFile(file);
  }, [handleFile]);

  return (
    <div
      className={`border-2 border-dashed rounded-2xl p-8 text-center transition-colors cursor-pointer ${
        isDragging ? "border-blue-500 bg-blue-50" : "border-gray-300 hover:border-gray-400"
      }`}
      onDrop={handleDrop}
      onDragOver={handleDragOver}
      onDragLeave={handleDragLeave}
      onClick={() => document.getElementById("file-input")?.click()}
    >
      <input
        id="file-input"
        type="file"
        accept="image/jpeg,image/png,image/webp"
        className="hidden"
        onChange={handleInputChange}
      />

      <div className="text-6xl mb-4">📤</div>
      <p className="text-lg font-medium text-gray-700">Drag and drop your image here</p>
      <p className="text-sm text-gray-500 mt-1">or click to browse (JPG, PNG, WEBP - max 10MB)</p>
    </div>
  );
}
```

### PredictionDisplay Component

Create `components/prediction/PredictionDisplay.tsx`:

```typescript
interface PredictionDisplayProps {
  diagnosis: "benign" | "malignant";
  confidence: number;
  classProbabilities: {
    benign: number;
    malignant: number;
  };
}

export default function PredictionDisplay({
  diagnosis,
  confidence,
  classProbabilities,
}: PredictionDisplayProps) {
  const isBenign = diagnosis === "benign";
  const highConfidence = confidence >= 0.7;

  const colorClass = isBenign
    ? "text-green-600 bg-green-50 border-green-200"
    : "text-red-600 bg-red-50 border-red-200";

  const confidenceColor = isBenign ? "bg-green-500" : "bg-red-500";

  return (
    <div className={`rounded-2xl border-2 p-6 ${colorClass}`}>
      <div className="flex items-center justify-between mb-4">
        <span className="text-2xl font-bold uppercase tracking-wide">
          {diagnosis}
        </span>
        <span className="text-lg font-semibold">
          {(confidence * 100).toFixed(0)}% confidence
        </span>
      </div>

      <div className="h-4 w-full bg-white rounded-full overflow-hidden mb-4">
        <div
          className={`h-full ${confidenceColor} transition-all duration-500`}
          style={{ width: `${confidence * 100}%` }}
        />
      </div>

      <div className="grid grid-cols-2 gap-4 text-sm">
        <div className="bg-white/50 rounded-lg p-3">
          <p className="text-gray-500">Benign</p>
          <p className="font-semibold text-lg">
            {(classProbabilities.benign * 100).toFixed(1)}%
          </p>
        </div>
        <div className="bg-white/50 rounded-lg p-3">
          <p className="text-gray-500">Malignant</p>
          <p className="font-semibold text-lg">
            {(classProbabilities.malignant * 100).toFixed(1)}%
          </p>
        </div>
      </div>

      {!highConfidence && (
        <div className="mt-4 p-3 bg-yellow-50 border border-yellow-200 rounded-lg">
          <p className="text-sm text-yellow-800">
            ⚠️ Low confidence. Please consult a dermatologist for professional evaluation.
          </p>
        </div>
      )}
    </div>
  );
}
```

### XAIViewer Component

Create `components/prediction/XAIViewer.tsx`:

```typescript
interface XAIViewerProps {
  original: string;
  heatmap: string;
  overlay: string;
  method: string;
  focusAreaPercentage: number;
}

export default function XAIViewer({
  original,
  heatmap,
  overlay,
  method,
  focusAreaPercentage,
}: XAIViewerProps) {
  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h3 className="font-semibold text-gray-900">
          {method.toUpperCase()} Explanation
        </h3>
        <p className="text-sm text-gray-500">
          Focus area: {(focusAreaPercentage * 100).toFixed(1)}%
        </p>
      </div>

      <div className="grid grid-cols-3 gap-4">
        {[
          { label: "Original", src: original },
          { label: "Heatmap", src: heatmap },
          { label: "Overlay", src: overlay },
        ].map(({ label, src }) => (
          <div key={label} className="space-y-2">
            <p className="text-sm font-medium text-gray-700 text-center">{label}</p>
            <div className="aspect-square bg-gray-100 rounded-xl overflow-hidden">
              <img
                src={`data:image/png;base64,${src}`}
                alt={label}
                className="w-full h-full object-contain"
              />
            </div>
          </div>
        ))}
      </div>

      <div className="bg-blue-50 border border-blue-200 rounded-xl p-4">
        <h4 className="font-semibold text-blue-900 mb-1">How to Read This</h4>
        <p className="text-sm text-blue-800">
          Red regions show where the AI focused most. A smaller focus area suggests
          confident prediction. A larger area may indicate uncertainty.
        </p>
      </div>
    </div>
  );
}
```

### MethodSelector Component

Create `components/prediction/MethodSelector.tsx`:

```typescript
interface MethodSelectorProps {
  selectedMethod: string;
  onMethodChange: (method: string) => void;
  disabled?: boolean;
}

const METHODS = [
  { id: "gradcam", name: "Grad-CAM", desc: "Standard gradient-weighted CAM" },
  { id: "gradcam_pp", name: "Grad-CAM++", desc: "Improved localization" },
  { id: "eigencam", name: "EigenCAM", desc: "Eigenvector-based" },
  { id: "layercam", name: "LayerCAM", desc: "Layer-wise gradient" },
];

export default function MethodSelector({
  selectedMethod,
  onMethodChange,
  disabled,
}: MethodSelectorProps) {
  return (
    <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
      {METHODS.map(({ id, name, desc }) => (
        <button
          key={id}
          onClick={() => onMethodChange(id)}
          disabled={disabled}
          className={`p-3 rounded-xl border-2 text-left transition-all ${
            selectedMethod === id
              ? "border-blue-500 bg-blue-50"
              : "border-gray-200 hover:border-gray-300"
          } ${disabled ? "opacity-50 cursor-not-allowed" : ""}`}
        >
          <p className="font-semibold text-gray-900">{name}</p>
          <p className="text-xs text-gray-500">{desc}</p>
        </button>
      ))}
    </div>
  );
}
```

### FeedbackConsent Component

Create `components/prediction/FeedbackConsent.tsx`:

```typescript
"use client";

import { useState } from "react";

interface FeedbackConsentProps {
  predictionId: string;
  onSubmit: () => Promise<void>;
}

export default function FeedbackConsent({ predictionId, onSubmit }: FeedbackConsentProps) {
  const [consent, setConsent] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submitted, setSubmitted] = useState(false);

  const handleSubmit = async () => {
    if (!consent) return;
    setIsSubmitting(true);
    try {
      await onSubmit();
      setSubmitted(true);
    } finally {
      setIsSubmitting(false);
    }
  };

  if (submitted) {
    return (
      <div className="bg-green-50 border border-green-200 rounded-xl p-4 text-center">
        <div className="text-4xl mb-2">✅</div>
        <p className="text-green-800 font-medium">Thank you!</p>
        <p className="text-green-600 text-sm">Your contribution helps improve our AI.</p>
      </div>
    );
  }

  return (
    <div className="bg-gray-50 rounded-xl p-4">
      <div className="flex items-start gap-3">
        <input
          type="checkbox"
          id="consent"
          checked={consent}
          onChange={(e) => setConsent(e.target.checked)}
          className="mt-1 w-5 h-5 rounded border-gray-300 text-blue-600"
        />
        <label htmlFor="consent" className="flex-1">
          <p className="font-medium text-gray-900">Help improve the model</p>
          <p className="text-sm text-gray-500">
            I consent to share my anonymized image for AI training purposes.
            I understand I can request deletion at any time.
          </p>
        </label>
      </div>

      <div className="mt-4 flex justify-end">
        <button
          onClick={handleSubmit}
          disabled={!consent || isSubmitting}
          className={`px-4 py-2 rounded-lg font-medium text-sm transition-colors ${
            consent && !isSubmitting
              ? "bg-blue-600 text-white hover:bg-blue-700"
              : "bg-gray-200 text-gray-400 cursor-not-allowed"
          }`}
        >
          {isSubmitting ? "Submitting..." : "Submit Feedback"}
        </button>
      </div>
    </div>
  );
}
```

---

## Step 12: Doctor Dashboard (Training Data Validation)

Create `app/(dashboard)/doctor/page.tsx`:

```typescript
"use client";

import { useState, useEffect } from "react";
import { useAuth } from "@/context/AuthContext";
import { api } from "@/lib/api";

interface PendingCase {
  case_id: string;
  prediction_id: string;
  diagnosis: string;
  confidence: number;
  image_url: string;
  created_at: string;
}

export default function DoctorDashboard() {
  const { user } = useAuth();
  const [pendingCases, setPendingCases] = useState<PendingCase[]>([]);
  const [selectedCase, setSelectedCase] = useState<PendingCase | null>(null);
  const [doctorDiagnosis, setDoctorDiagnosis] = useState<"benign" | "malignant">("benign");
  const [notes, setNotes] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  useEffect(() => {
    loadPendingCases();
  }, []);

  const loadPendingCases = async () => {
    try {
      const cases = await api.getPendingReviewCases();
      setPendingCases(cases);
    } catch (err) {
      console.error("Failed to load cases:", err);
    }
  };

  const handleSubmitOpinion = async () => {
    if (!selectedCase) return;

    setIsSubmitting(true);
    try {
      await api.submitExpertOpinion({
        prediction_id: selectedCase.prediction_id,
        diagnosis: doctorDiagnosis,
        notes: notes || undefined,
      });
      alert("Expert opinion submitted. Case moved to admin review.");
      setSelectedCase(null);
      setNotes("");
      loadPendingCases();
    } catch (err) {
      alert(err instanceof Error ? err.message : "Failed to submit opinion");
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Doctor Validation Dashboard</h1>
        <p className="text-gray-600">Review patient-consented cases and provide expert opinions</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Case List */}
        <div className="bg-white rounded-xl shadow-sm p-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">
            Pending Review ({pendingCases.length})
          </h2>
          <div className="space-y-3">
            {pendingCases.length === 0 ? (
              <p className="text-gray-500 text-center py-8">No cases pending review</p>
            ) : (
              pendingCases.map((c) => (
                <div
                  key={c.case_id}
                  onClick={() => setSelectedCase(c)}
                  className={`p-4 rounded-xl border-2 cursor-pointer transition-all ${
                    selectedCase?.case_id === c.case_id
                      ? "border-blue-500 bg-blue-50"
                      : "border-gray-200 hover:border-gray-300"
                  }`}
                >
                  <div className="flex items-center gap-4">
                    <div className="w-16 h-16 bg-gray-200 rounded-lg overflow-hidden">
                      <img src={c.image_url} alt="Case" className="w-full h-full object-cover" />
                    </div>
                    <div>
                      <p className="font-medium text-gray-900">
                        AI: {c.diagnosis} ({c.confidence}%)
                      </p>
                      <p className="text-sm text-gray-500">
                        {new Date(c.created_at).toLocaleDateString()}
                      </p>
                    </div>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>

        {/* Case Detail */}
        {selectedCase && (
          <div className="bg-white rounded-xl shadow-sm p-6">
            <h2 className="text-lg font-semibold text-gray-900 mb-4">Case Review</h2>

            <div className="space-y-4">
              <div className="aspect-square bg-gray-100 rounded-xl overflow-hidden">
                <img
                  src={selectedCase.image_url}
                  alt="Case"
                  className="w-full h-full object-contain"
                />
              </div>

              <div className="p-4 bg-gray-50 rounded-xl">
                <p className="text-sm text-gray-500">AI Prediction</p>
                <p className="font-semibold text-lg">
                  {selectedCase.diagnosis} ({selectedCase.confidence}%)
                </p>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Your Diagnosis
                </label>
                <div className="grid grid-cols-2 gap-3">
                  <button
                    onClick={() => setDoctorDiagnosis("benign")}
                    className={`p-3 rounded-xl border-2 font-medium ${
                      doctorDiagnosis === "benign"
                        ? "border-green-500 bg-green-50 text-green-700"
                        : "border-gray-200 text-gray-600"
                    }`}
                  >
                    Benign
                  </button>
                  <button
                    onClick={() => setDoctorDiagnosis("malignant")}
                    className={`p-3 rounded-xl border-2 font-medium ${
                      doctorDiagnosis === "malignant"
                        ? "border-red-500 bg-red-50 text-red-700"
                        : "border-gray-200 text-gray-600"
                    }`}
                  >
                    Malignant
                  </button>
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Notes (optional)
                </label>
                <textarea
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                  className="w-full px-4 py-3 border border-gray-300 rounded-xl"
                  rows={3}
                  placeholder="Add clinical observations..."
                />
              </div>

              <button
                onClick={handleSubmitOpinion}
                disabled={isSubmitting}
                className="w-full bg-blue-600 text-white py-3 rounded-xl font-medium hover:bg-blue-700 disabled:opacity-50"
              >
                {isSubmitting ? "Submitting..." : "Submit Expert Opinion"}
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
```

---

## Step 13: Admin Dashboard (Training Pool Approval)

Create `app/(dashboard)/admin/page.tsx`:

```typescript
"use client";

import { useState, useEffect } from "react";
import { useAuth } from "@/context/AuthContext";
import { api } from "@/lib/api";

interface TrainingPoolStats {
  approved_count: number;
  pending_doctor_review: number;
  pending_admin_review: number;
  minimum_for_retraining: number;
  ready_for_retraining: boolean;
}

interface PendingAdminCase {
  case_id: string;
  prediction_id: string;
  ai_diagnosis: string;
  doctor_diagnosis: string;
  doctor_notes?: string;
  image_url: string;
}

export default function AdminDashboard() {
  const { user } = useAuth();
  const [stats, setStats] = useState<TrainingPoolStats | null>(null);
  const [pendingCases, setPendingCases] = useState<PendingAdminCase[]>([]);
  const [selectedCase, setSelectedCase] = useState<PendingAdminCase | null>(null);
  const [isProcessing, setIsProcessing] = useState(false);

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      const [statsData, casesData] = await Promise.all([
        api.getAdminStats(),
        api.getTrainingPoolPending(),
      ]);
      setStats(statsData);
      setPendingCases(casesData);
    } catch (err) {
      console.error("Failed to load data:", err);
    }
  };

  const handleApprove = async (caseId: string) => {
    setIsProcessing(true);
    try {
      await api.approveTrainingCase(caseId);
      alert("Case approved for training pool.");
      setSelectedCase(null);
      loadData();
    } catch (err) {
      alert(err instanceof Error ? err.message : "Failed to approve case");
    } finally {
      setIsProcessing(false);
    }
  };

  const handleReject = async (caseId: string) => {
    setIsProcessing(true);
    try {
      await api.rejectTrainingCase(caseId);
      alert("Case rejected and removed.");
      setSelectedCase(null);
      loadData();
    } catch (err) {
      alert(err instanceof Error ? err.message : "Failed to reject case");
    } finally {
      setIsProcessing(false);
    }
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Admin Dashboard</h1>
        <p className="text-gray-600">Manage training pool and model retraining</p>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="bg-white rounded-xl shadow-sm p-6">
          <p className="text-sm text-gray-500">Approved Cases</p>
          <p className="text-3xl font-bold text-gray-900">{stats?.approved_count || 0}</p>
        </div>
        <div className="bg-white rounded-xl shadow-sm p-6">
          <p className="text-sm text-gray-500">Pending Doctor Review</p>
          <p className="text-3xl font-bold text-yellow-600">{stats?.pending_doctor_review || 0}</p>
        </div>
        <div className="bg-white rounded-xl shadow-sm p-6">
          <p className="text-sm text-gray-500">Pending Admin Approval</p>
          <p className="text-3xl font-bold text-blue-600">{stats?.pending_admin_review || 0}</p>
        </div>
        <div className="bg-white rounded-xl shadow-sm p-6">
          <p className="text-sm text-gray-500">Ready for Retraining</p>
          <p className={`text-3xl font-bold ${stats?.ready_for_retraining ? "text-green-600" : "text-gray-400"}`}>
            {stats?.ready_for_retraining ? "Yes" : "No"}
          </p>
          <p className="text-xs text-gray-500">Min: {stats?.minimum_for_retraining || 5000}</p>
        </div>
      </div>

      {/* Retraining Section */}
      {stats?.ready_for_retraining && (
        <div className="bg-green-50 border border-green-200 rounded-xl p-6">
          <h2 className="text-lg font-semibold text-green-900 mb-2">Ready for Batch Retraining</h2>
          <p className="text-green-700 mb-4">
            You have {stats.approved_count} approved cases. You can now trigger batch retraining.
          </p>
          <button
            onClick={async () => {
              try {
                await api.triggerRetraining();
                alert("Retraining triggered. Check MLflow for progress.");
              } catch (err) {
                alert(err instanceof Error ? err.message : "Failed to trigger retraining");
              }
            }}
            className="bg-green-600 text-white px-6 py-3 rounded-xl font-medium hover:bg-green-700"
          >
            Trigger Batch Retraining
          </button>
        </div>
      )}

      {/* Pending Admin Cases */}
      <div className="bg-white rounded-xl shadow-sm p-6">
        <h2 className="text-lg font-semibold text-gray-900 mb-4">
          Pending Admin Approval ({pendingCases.length})
        </h2>
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Case List */}
          <div className="space-y-3">
            {pendingCases.length === 0 ? (
              <p className="text-gray-500 text-center py-8">No cases pending approval</p>
            ) : (
              pendingCases.map((c) => (
                <div
                  key={c.case_id}
                  onClick={() => setSelectedCase(c)}
                  className={`p-4 rounded-xl border-2 cursor-pointer ${
                    selectedCase?.case_id === c.case_id
                      ? "border-blue-500 bg-blue-50"
                      : "border-gray-200 hover:border-gray-300"
                  }`}
                >
                  <div className="flex items-center gap-4">
                    <div className="w-12 h-12 bg-gray-200 rounded-lg overflow-hidden">
                      <img src={c.image_url} alt="Case" className="w-full h-full object-cover" />
                    </div>
                    <div>
                      <p className="font-medium">
                        AI: {c.ai_diagnosis} → Doctor: {c.doctor_diagnosis}
                      </p>
                      <p className="text-sm text-gray-500">
                        {c.doctor_notes || "No notes"}
                      </p>
                    </div>
                  </div>
                </div>
              ))
            )}
          </div>

          {/* Case Detail */}
          {selectedCase && (
            <div className="border-2 border-gray-200 rounded-xl p-4">
              <div className="aspect-square bg-gray-100 rounded-lg overflow-hidden mb-4">
                <img
                  src={selectedCase.image_url}
                  alt="Case"
                  className="w-full h-full object-contain"
                />
              </div>

              <div className="space-y-3">
                <div className="flex justify-between items-center">
                  <span className="text-sm text-gray-500">AI Prediction:</span>
                  <span className="font-medium">{selectedCase.ai_diagnosis}</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-sm text-gray-500">Doctor Diagnosis:</span>
                  <span className="font-medium text-blue-600">{selectedCase.doctor_diagnosis}</span>
                </div>
                {selectedCase.doctor_notes && (
                  <div>
                    <span className="text-sm text-gray-500">Doctor Notes:</span>
                    <p className="text-sm mt-1 p-2 bg-gray-50 rounded">{selectedCase.doctor_notes}</p>
                  </div>
                )}

                <div className="flex gap-3 pt-3">
                  <button
                    onClick={() => handleApprove(selectedCase.case_id)}
                    disabled={isProcessing}
                    className="flex-1 bg-green-600 text-white py-2 rounded-lg font-medium hover:bg-green-700 disabled:opacity-50"
                  >
                    Approve
                  </button>
                  <button
                    onClick={() => handleReject(selectedCase.case_id)}
                    disabled={isProcessing}
                    className="flex-1 bg-red-600 text-white py-2 rounded-lg font-medium hover:bg-red-700 disabled:opacity-50"
                  >
                    Reject
                  </button>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
```

---

## Step 14: Environment Configuration

Create `.env.local`:

```bash
# API
NEXT_PUBLIC_API_URL=http://localhost:8080

# AWS Cognito (for production)
NEXT_PUBLIC_AWS_REGION=us-east-1
NEXT_PUBLIC_COGNITO_PATIENT_POOL_ID=
NEXT_PUBLIC_COGNITO_DOCTOR_POOL_ID=
NEXT_PUBLIC_COGNITO_IDENTITY_POOL_ID=
```

Create `.env.example`:

```bash
# API URL
NEXT_PUBLIC_API_URL=http://localhost:8080

# AWS Region
NEXT_PUBLIC_AWS_REGION=us-east-1

# Cognito User Pool IDs (from Phase 1)
NEXT_PUBLIC_COGNITO_PATIENT_POOL_ID=us-east-1_xxxxx
NEXT_PUBLIC_COGNITO_DOCTOR_POOL_ID=us-east-1_xxxxx
NEXT_PUBLIC_COGNITO_IDENTITY_POOL_ID=us-east-1:xxxxx
```

---

## Frontend Summary

### Files Created

```
frontend/
├── app/
│   ├── (auth)/
│   │   ├── layout.tsx          # Auth layout (centered card)
│   │   ├── login/page.tsx      # Login page
│   │   └── register/page.tsx   # Registration page
│   ├── (dashboard)/
│   │   ├── layout.tsx          # Dashboard layout (nav + auth)
│   │   ├── patient/page.tsx    # Patient dashboard
│   │   ├── doctor/page.tsx     # Doctor validation dashboard
│   │   └── admin/page.tsx      # Admin training pool dashboard
│   ├── layout.tsx              # Root layout
│   ├── page.tsx                # Landing page
│   └── globals.css             # Global styles
├── components/
│   ├── prediction/
│   │   ├── ImageUploader.tsx
│   │   ├── PredictionDisplay.tsx
│   │   ├── XAIViewer.tsx
│   │   ├── MethodSelector.tsx
│   │   └── FeedbackConsent.tsx
│   └── ui/
├── context/
│   └── AuthContext.tsx         # Auth state management
├── lib/
│   ├── api.ts                  # API client
│   └── constants.ts            # Constants
├── types/
│   └── index.ts                # TypeScript types
├── .env.local                  # Environment (local)
├── .env.example                 # Environment (template)
└── package.json
```

### Run Commands

```bash
# Development
npm run dev

# Build
npm run build

# Type check
npm run type-check

# Lint
npm run lint

# Test
npm test
```

---

## Next Steps

**Phase 3 Complete!**

Next is **Phase 4: Mobile App Development**

Proceed to: `BUILD_PHASE_4_MOBILE.md`