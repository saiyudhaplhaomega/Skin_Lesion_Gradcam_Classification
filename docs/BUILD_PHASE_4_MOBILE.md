# Phase 4: Mobile App Development (React Native + Expo)

**Step-by-step guide to building iOS and Android apps using React Native with Expo**

---

## Current Repo State

No native mobile app exists yet. Treat this guide as a future phase, not current implementation.

Build mobile after:

1. Backend `/predict`, `/explain`, auth, and consent endpoints are stable.
2. The web frontend proves the patient upload flow.
3. API response types are versioned and documented.
4. Image upload size limits and compression rules are known.

If you want mobile coverage earlier, build the web app as a PWA first. Native Expo should come after the API contract stops changing daily.

---

## Overview

The mobile app allows users to access the platform on the go. We need:
1. Patient app for image upload and prediction viewing
2. Doctor app for reviewing cases and adding expert opinions
3. Push notifications for important updates
4. Offline support for viewing history

### Why Expo?

Expo is a framework built on top of React Native that makes development easier:
- No need for Xcode or Android Studio for basic development
- Live reload and hot module replacement
- Easy access to device features (camera, notifications)
- Built-in build service (EAS Build) for App Store deployment

### Technology Stack
- **Framework**: Expo SDK 50 (React Native)
- **Language**: TypeScript
- **Navigation**: Expo Router (file-based routing)
- **State Management**: React Context + AsyncStorage
- **Auth**: AWS Cognito via AWS SDK
- **API Client**: Same as web (shared package)

---

## Step 1: Initialize Expo Project

```bash
# Create new Expo project
cd C:/Users/saiyu/Desktop/projects/KI_projects/Skin_Lesion_GRADCAM_Classification

npx create-expo-app@latest SkinLesionMobile --template blank-typescript

# When asked:
# - What is the app name? → SkinLesion
# - What is the app slug? → SkinLesionMobile
# - Choose a template: → blank (TypeScript)

cd SkinLesionMobile

# Install additional dependencies
npx expo install expo-image-picker     # For camera/gallery access
npx expo install expo-secure-store   # For secure token storage
npx expo install expo-notifications   # For push notifications
npx expo install @react-navigation/native @react-navigation/native-stack @react-navigation/bottom-tabs
npx expo install aws-amplify @aws-amplify/ui-react-native
npx expo install react-native-svg   # For heatmap visualization
npx expo install date-fns           # For date formatting
npx expo install react-native-paper  # Material Design components
```

Do not install the old global `expo-cli`; use `npx expo ...` and EAS CLI when needed. The global CLI is deprecated for modern Expo SDKs.

### Install Apple Developer Account (for iOS)

```bash
# You'll need to create an Apple Developer account
# https://developer.apple.com/programs/enroll/

# Create App Store Connect app
# https://appstoreconnect.apple.com/
```

### Install Google Play Developer Account (for Android)

```bash
# Create Google Play Developer account
# https://play.google.com/console/developers

# Create a new app in Google Play Console
```

---

## Step 2: Project Structure

### Create Directory Structure

```bash
mkdir -p app/(auth)
mkdir -p app/(app)
mkdir -p app/(app)/patient
mkdir -p app/(app)/doctor
mkdir -p app/(app)/admin
mkdir -p app/_layout
mkdir -p src/components
mkdir -p src/services
mkdir -p src/context
mkdir -p src/hooks
mkdir -p src/types
mkdir -p src/utils
mkdir -p src/navigation
```

### What This Structure Does

```
app/                    # Expo Router (file-based routing)
├── (auth)/            # Auth routes
│   ├── _layout.tsx   # Auth stack layout
│   ├── login.tsx
│   └── register.tsx
├── (app)/             # Main app routes
│   ├── _layout.tsx    # App layout (with auth check)
│   ├── patient/       # Patient screens
│   ├── doctor/        # Doctor screens
│   └── admin/         # Admin screens
├── _layout.tsx        # Root layout
└── index.tsx          # Entry point (redirects based on auth)

src/
├── components/        # Reusable UI components
├── services/          # API client, auth service
├── context/           # React Context providers
├── hooks/             # Custom hooks
├── types/             # TypeScript types
└── utils/             # Utilities
```

---

## Step 3: Type Definitions

Create `src/types/index.ts`:

```typescript
// Re-export web types (same types work for mobile)
export type {
  User,
  UserRole,
  PredictionResponse,
  ExplainResponse,
  FeedbackRequest,
  FeedbackResponse,
  ExpertOpinion,
  ExpertOpinionRequest,
  DoctorApprovalRequest,
  AdminStats,
} from "../../../frontend/types";

// Mobile-specific types
export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  idToken: string;
  expiresAt: number;
}

export interface NotificationPayload {
  title: string;
  body: string;
  data?: Record<string, unknown>;
}
```

---

## Step 4: API Client (Shared)

Create `src/services/api.ts`:

```typescript
import { api as webApi } from "./api-web";
import { getStoredToken } from "./secure-storage";
import { API_BASE_URL } from "../utils/constants";

const API_URL = API_BASE_URL || "http://localhost:8080";

class APIError extends Error {
  status: number;
  constructor(message: string, status: number) {
    super(message);
    this.status = status;
    this.name = "APIError";
  }
}

async function getAuthHeaders(): Promise<HeadersInit> {
  const token = await getStoredToken();
  return {
    "Content-Type": "application/json",
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
  };
}

async function handleResponse<T>(response: Response): Promise<T> {
  if (!response.ok) {
    const error = await response.json().catch(() => ({ detail: "Unknown error" }));
    throw new APIError(error.detail || "Request failed", response.status);
  }
  return response.json();
}

export const api = {
  async predict(imageUri: string): Promise<any> {
    const formData = new FormData();
    formData.append("image", {
      uri: imageUri,
      type: "image/jpeg",
      name: "image.jpg",
    } as any);

    const response = await fetch(`${API_URL}/api/v1/predict`, {
      method: "POST",
      headers: await getAuthHeaders(),
      body: formData,
    });

    return handleResponse(response);
  },

  async explain(predictionId: string, method: string): Promise<any> {
    const response = await fetch(`${API_URL}/api/v1/explain`, {
      method: "POST",
      headers: await getAuthHeaders(),
      body: JSON.stringify({ prediction_id: predictionId, method }),
    });
    return handleResponse(response);
  },

  async submitFeedback(predictionId: string, consent: true, userLabel?: string): Promise<any> {
    const response = await fetch(`${API_URL}/api/v1/feedback`, {
      method: "POST",
      headers: await getAuthHeaders(),
      body: JSON.stringify({
        prediction_id: predictionId,
        consent,
        user_label: userLabel,
      }),
    });
    return handleResponse(response);
  },

  async getCurrentUser(): Promise<any> {
    const response = await fetch(`${API_URL}/api/v1/users/me`, {
      headers: await getAuthHeaders(),
    });
    return handleResponse(response);
  },

  async getPredictionHistory(): Promise<any[]> {
    const response = await fetch(`${API_URL}/api/v1/users/me/predictions`, {
      headers: await getAuthHeaders(),
    });
    return handleResponse(response);
  },

  async getPendingPredictions(): Promise<any[]> {
    const response = await fetch(`${API_URL}/api/v1/predictions?status=pending`, {
      headers: await getAuthHeaders(),
    });
    return handleResponse(response);
  },

  async submitExpertOpinion(predictionId: string, diagnosis: string, notes?: string): Promise<any> {
    const response = await fetch(`${API_URL}/api/v1/expert-opinions`, {
      method: "POST",
      headers: await getAuthHeaders(),
      body: JSON.stringify({ prediction_id: predictionId, diagnosis, notes }),
    });
    return handleResponse(response);
  },

  async getAdminStats(): Promise<any> {
    const response = await fetch(`${API_URL}/api/v1/admin/stats`, {
      headers: await getAuthHeaders(),
    });
    return handleResponse(response);
  },

  async getPendingDoctors(): Promise<any[]> {
    const response = await fetch(`${API_URL}/api/v1/admin/doctors/pending`, {
      headers: await getAuthHeaders(),
    });
    return handleResponse(response);
  },

  async approveDoctor(doctorId: string, action: "approve" | "reject"): Promise<any> {
    const response = await fetch(`${API_URL}/api/v1/admin/doctors/approve`, {
      method: "POST",
      headers: await getAuthHeaders(),
      body: JSON.stringify({ doctor_id: doctorId, action }),
    });
    return handleResponse(response);
  },
};

export { APIError };
```

### Create Secure Storage Service

Create `src/services/secure-storage.ts`:

```typescript
import * as SecureStore from "expo-secure-store";

const TOKEN_KEY = "auth_tokens";

interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  idToken: string;
  expiresAt: number;
}

export async function storeTokens(tokens: AuthTokens): Promise<void> {
  await SecureStore.setItemAsync(TOKEN_KEY, JSON.stringify(tokens));
}

export async function getStoredToken(): Promise<string | null> {
  const data = await SecureStore.getItemAsync(TOKEN_KEY);
  if (!data) return null;

  const tokens: AuthTokens = JSON.parse(data);

  // Check if token is expired
  if (tokens.expiresAt < Date.now()) {
    // Try to refresh
    // In production, would call Cognito refresh endpoint
    await clearTokens();
    return null;
  }

  return tokens.idToken || tokens.accessToken;
}

export async function clearTokens(): Promise<void> {
  await SecureStore.deleteItemAsync(TOKEN_KEY);
}
```

### Create Constants

Create `src/utils/constants.ts`:

```typescript
export const API_BASE_URL = process.env.EXPO_PUBLIC_API_URL || "http://localhost:8080";
export const AWS_REGION = process.env.EXPO_PUBLIC_AWS_REGION || "us-east-1";
```

---

## Step 5: Authentication Context

Create `src/context/AuthContext.tsx`:

```typescript
import React, { createContext, useContext, useState, useEffect } from "react";
import * as SecureStore from "expo-secure-store";
import { User } from "../types";
import { api } from "../services/api";

interface AuthContextType {
  user: User | null;
  isLoading: boolean;
  isAuthenticated: boolean;
  login: (email: string, password: string) => Promise<void>;
  register: (email: string, password: string, role: string) => Promise<void>;
  logout: () => Promise<void>;
  refreshUser: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  const refreshUser = async () => {
    try {
      const currentUser = await api.getCurrentUser();
      setUser(currentUser);
    } catch (error) {
      setUser(null);
    }
  };

  useEffect(() => {
    refreshUser().finally(() => setIsLoading(false));
  }, []);

  const login = async (email: string, password: string) => {
    // In production, use AWS Cognito
    // For now, simulate login
    const response = await fetch(`${process.env.EXPO_PUBLIC_API_URL}/api/v1/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password }),
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.detail || "Login failed");
    }

    const tokens = await response.json();
    await SecureStore.setItemAsync("auth_tokens", JSON.stringify(tokens));
    await refreshUser();
  };

  const register = async (email: string, password: string, role: string) => {
    const response = await fetch(`${process.env.EXPO_PUBLIC_API_URL}/api/v1/auth/register`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password, role }),
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.detail || "Registration failed");
    }
  };

  const logout = async () => {
    await SecureStore.deleteItemAsync("auth_tokens");
    setUser(null);
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        isLoading,
        isAuthenticated: !!user,
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

## Step 6: Navigation Setup

### Root Layout

Create `app/_layout.tsx`:

```typescript
import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { AuthProvider } from "../src/context/AuthContext";

export default function RootLayout() {
  return (
    <AuthProvider>
      <StatusBar style="auto" />
      <Stack>
        <Stack.Screen name="index" options={{ headerShown: false }} />
        <Stack.Screen name="(auth)" options={{ headerShown: false }} />
        <Stack.Screen name="(app)" options={{ headerShown: false }} />
      </Stack>
    </AuthProvider>
  );
}
```

### Auth Layout

Create `app/(auth)/_layout.tsx`:

```typescript
import { Stack } from "expo-router";

export default function AuthLayout() {
  return (
    <Stack screenOptions={{ headerShown: false }}>
      <Stack.Screen name="login" />
      <Stack.Screen name="register" />
    </Stack>
  );
}
```

### App Layout (Protected)

Create `app/(app)/_layout.tsx`:

```typescript
import { Tabs } from "expo-router";
import { useAuth } from "../../src/context/AuthContext";
import { router } from "expo-router";
import { useEffect } from "react";

function TabIcon({ name, color }: { name: string; color: string }) {
  const icons: Record<string, string> = {
    home: "🏠",
    history: "📋",
    profile: "👤",
    patients: "👥",
    admin: "⚙️",
  };
  return <>{icons[name] || "•"}</>;
}

export default function AppLayout() {
  const { user, isLoading, isAuthenticated } = useAuth();

  useEffect(() => {
    if (!isLoading && !isAuthenticated) {
      router.replace("/(auth)/login");
    }
  }, [isLoading, isAuthenticated]);

  if (isLoading) {
    return null; // Or a loading screen
  }

  if (!user) {
    return null;
  }

  const isDoctor = user.role === "doctor";
  const isAdmin = user.role === "admin";
  const isPending = user.role === "doctor" && !user.approved;

  return (
    <Tabs>
      <Tabs.Screen
        name="index"
        options={{
          title: "Home",
          tabBarIcon: ({ color }) => <TabIcon name="home" color={color} />,
          href: isPending ? null : "/(app)/index",
        }}
      />
      <Tabs.Screen
        name="history"
        options={{
          title: "History",
          tabBarIcon: ({ color }) => <TabIcon name="history" color={color} />,
          href: isPending ? null : "/(app)/history",
        }}
      />
      {(isDoctor || isAdmin) && (
        <Tabs.Screen
          name="patients"
          options={{
            title: "Patients",
            tabBarIcon: ({ color }) => <TabIcon name="patients" color={color} />,
            href: "/(app)/patients",
          }}
        />
      )}
      {isAdmin && (
        <Tabs.Screen
          name="admin"
          options={{
            title: "Admin",
            tabBarIcon: ({ color }) => <TabIcon name="admin" color={color} />,
            href: "/(app)/admin",
          }}
        />
      )}
      <Tabs.Screen
        name="profile"
        options={{
          title: "Profile",
          tabBarIcon: ({ color }) => <TabIcon name="profile" color={color} />,
          href: "/(app)/profile",
        }}
      />
    </Tabs>
  );
}
```

### Index Redirect

Create `app/index.tsx`:

```typescript
import { useEffect } from "react";
import { router } from "expo-router";
import { useAuth } from "../src/context/AuthContext";

export default function Index() {
  const { isAuthenticated, isLoading } = useAuth();

  useEffect(() => {
    if (!isLoading) {
      if (isAuthenticated) {
        router.replace("/(app)/index");
      } else {
        router.replace("/(auth)/login");
      }
    }
  }, [isLoading, isAuthenticated]);

  return null;
}
```

---

## Step 7: Auth Screens

### Login Screen

Create `app/(auth)/login.tsx`:

```typescript
import { useState } from "react";
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  Alert,
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
} from "react-native";
import { useRouter, Link } from "expo-router";
import { useAuth } from "../../src/context/AuthContext";

export default function LoginScreen() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const { login } = useAuth();
  const router = useRouter();

  const handleLogin = async () => {
    if (!email || !password) {
      Alert.alert("Error", "Please fill in all fields");
      return;
    }

    setIsLoading(true);
    try {
      await login(email, password);
      router.replace("/(app)/index");
    } catch (error: any) {
      Alert.alert("Login Failed", error.message || "Please check your credentials");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === "ios" ? "padding" : "height"}
      style={styles.container}
    >
      <View style={styles.content}>
        <View style={styles.logoContainer}>
          <Text style={styles.logo}>🏥</Text>
          <Text style={styles.title}>Welcome Back</Text>
          <Text style={styles.subtitle}>Sign in to your account</Text>
        </View>

        <View style={styles.form}>
          <TextInput
            style={styles.input}
            placeholder="Email"
            value={email}
            onChangeText={setEmail}
            keyboardType="email-address"
            autoCapitalize="none"
            autoCorrect={false}
          />

          <TextInput
            style={styles.input}
            placeholder="Password"
            value={password}
            onChangeText={setPassword}
            secureTextEntry
          />

          <TouchableOpacity
            style={styles.button}
            onPress={handleLogin}
            disabled={isLoading}
          >
            {isLoading ? (
              <ActivityIndicator color="#fff" />
            ) : (
              <Text style={styles.buttonText}>Sign In</Text>
            )}
          </TouchableOpacity>

          <View style={styles.footer}>
            <Text style={styles.footerText}>Don't have an account? </Text>
            <Link href="/(auth)/register" asChild>
              <TouchableOpacity>
                <Text style={styles.link}>Sign up</Text>
              </TouchableOpacity>
            </Link>
          </View>
        </View>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#f5f5f5",
  },
  content: {
    flex: 1,
    justifyContent: "center",
    padding: 24,
  },
  logoContainer: {
    alignItems: "center",
    marginBottom: 32,
  },
  logo: {
    fontSize: 64,
    marginBottom: 16,
  },
  title: {
    fontSize: 28,
    fontWeight: "bold",
    color: "#333",
  },
  subtitle: {
    fontSize: 16,
    color: "#666",
    marginTop: 4,
  },
  form: {
    backgroundColor: "#fff",
    borderRadius: 16,
    padding: 24,
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    elevation: 4,
  },
  input: {
    backgroundColor: "#f5f5f5",
    borderRadius: 12,
    padding: 16,
    fontSize: 16,
    marginBottom: 16,
  },
  button: {
    backgroundColor: "#2563eb",
    borderRadius: 12,
    padding: 16,
    alignItems: "center",
    marginTop: 8,
  },
  buttonText: {
    color: "#fff",
    fontSize: 16,
    fontWeight: "600",
  },
  footer: {
    flexDirection: "row",
    justifyContent: "center",
    marginTop: 24,
  },
  footerText: {
    color: "#666",
    fontSize: 14,
  },
  link: {
    color: "#2563eb",
    fontSize: 14,
    fontWeight: "600",
  },
});
```

### Register Screen

Create `app/(auth)/register.tsx`:

```typescript
import { useState } from "react";
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  Alert,
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
} from "react-native";
import { useRouter, Link } from "expo-router";
import { useAuth } from "../../src/context/AuthContext";

export default function RegisterScreen() {
  const [formData, setFormData] = useState({
    email: "",
    password: "",
    confirmPassword: "",
    role: "patient",
    fullName: "",
    medicalLicense: "",
  });
  const [isLoading, setIsLoading] = useState(false);
  const { register } = useAuth();
  const router = useRouter();

  const handleRegister = async () => {
    if (formData.password !== formData.confirmPassword) {
      Alert.alert("Error", "Passwords do not match");
      return;
    }

    if (formData.password.length < 8) {
      Alert.alert("Error", "Password must be at least 8 characters");
      return;
    }

    if (formData.role === "doctor" && !formData.medicalLicense) {
      Alert.alert("Error", "Medical license is required for doctor accounts");
      return;
    }

    setIsLoading(true);
    try {
      await register(formData.email, formData.password, formData.role);
      router.replace("/(auth)/login");
    } catch (error: any) {
      Alert.alert("Registration Failed", error.message);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === "ios" ? "padding" : "height"}
      style={styles.container}
    >
      <ScrollView contentContainerStyle={styles.scrollContent}>
        <View style={styles.content}>
          <View style={styles.logoContainer}>
            <Text style={styles.logo}>🏥</Text>
            <Text style={styles.title}>Create Account</Text>
          </View>

          {/* Role Selection */}
          <View style={styles.roleContainer}>
            <TouchableOpacity
              style={[
                styles.roleButton,
                formData.role === "patient" && styles.roleButtonActive,
              ]}
              onPress={() => setFormData({ ...formData, role: "patient" })}
            >
              <Text style={styles.roleEmoji}>👤</Text>
              <Text
                style={[
                  styles.roleText,
                  formData.role === "patient" && styles.roleTextActive,
                ]}
              >
                Patient
              </Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={[
                styles.roleButton,
                formData.role === "doctor" && styles.roleButtonActive,
              ]}
              onPress={() => setFormData({ ...formData, role: "doctor" })}
            >
              <Text style={styles.roleEmoji}>👨‍⚕️</Text>
              <Text
                style={[
                  styles.roleText,
                  formData.role === "doctor" && styles.roleTextActive,
                ]}
              >
                Doctor
              </Text>
            </TouchableOpacity>
          </View>

          <View style={styles.form}>
            <TextInput
              style={styles.input}
              placeholder="Full Name"
              value={formData.fullName}
              onChangeText={(text) => setFormData({ ...formData, fullName: text })}
            />

            <TextInput
              style={styles.input}
              placeholder="Email"
              value={formData.email}
              onChangeText={(text) => setFormData({ ...formData, email: text })}
              keyboardType="email-address"
              autoCapitalize="none"
            />

            {formData.role === "doctor" && (
              <TextInput
                style={styles.input}
                placeholder="Medical License Number"
                value={formData.medicalLicense}
                onChangeText={(text) =>
                  setFormData({ ...formData, medicalLicense: text })
                }
              />
            )}

            <TextInput
              style={styles.input}
              placeholder="Password"
              value={formData.password}
              onChangeText={(text) => setFormData({ ...formData, password: text })}
              secureTextEntry
            />

            <TextInput
              style={styles.input}
              placeholder="Confirm Password"
              value={formData.confirmPassword}
              onChangeText={(text) =>
                setFormData({ ...formData, confirmPassword: text })
              }
              secureTextEntry
            />

            <TouchableOpacity
              style={styles.button}
              onPress={handleRegister}
              disabled={isLoading}
            >
              {isLoading ? (
                <ActivityIndicator color="#fff" />
              ) : (
                <Text style={styles.buttonText}>Create Account</Text>
              )}
            </TouchableOpacity>

            <View style={styles.footer}>
              <Text style={styles.footerText}>Already have an account? </Text>
              <Link href="/(auth)/login" asChild>
                <TouchableOpacity>
                  <Text style={styles.link}>Sign in</Text>
                </TouchableOpacity>
              </Link>
            </View>
          </View>
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#f5f5f5",
  },
  scrollContent: {
    flexGrow: 1,
  },
  content: {
    flex: 1,
    justifyContent: "center",
    padding: 24,
  },
  logoContainer: {
    alignItems: "center",
    marginBottom: 24,
  },
  logo: {
    fontSize: 48,
    marginBottom: 8,
  },
  title: {
    fontSize: 24,
    fontWeight: "bold",
    color: "#333",
  },
  roleContainer: {
    flexDirection: "row",
    gap: 12,
    marginBottom: 24,
  },
  roleButton: {
    flex: 1,
    backgroundColor: "#fff",
    borderRadius: 12,
    padding: 16,
    alignItems: "center",
    borderWidth: 2,
    borderColor: "#e5e5e5",
  },
  roleButtonActive: {
    borderColor: "#2563eb",
    backgroundColor: "#eff6ff",
  },
  roleEmoji: {
    fontSize: 32,
    marginBottom: 4,
  },
  roleText: {
    fontSize: 14,
    color: "#666",
  },
  roleTextActive: {
    color: "#2563eb",
    fontWeight: "600",
  },
  form: {
    backgroundColor: "#fff",
    borderRadius: 16,
    padding: 24,
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    elevation: 4,
  },
  input: {
    backgroundColor: "#f5f5f5",
    borderRadius: 12,
    padding: 16,
    fontSize: 16,
    marginBottom: 16,
  },
  button: {
    backgroundColor: "#2563eb",
    borderRadius: 12,
    padding: 16,
    alignItems: "center",
    marginTop: 8,
  },
  buttonText: {
    color: "#fff",
    fontSize: 16,
    fontWeight: "600",
  },
  footer: {
    flexDirection: "row",
    justifyContent: "center",
    marginTop: 24,
  },
  footerText: {
    color: "#666",
    fontSize: 14,
  },
  link: {
    color: "#2563eb",
    fontSize: 14,
    fontWeight: "600",
  },
});
```

---

## Step 8: Patient Screens

### Home/Upload Screen

Create `app/(app)/index.tsx`:

```typescript
import { useState, useCallback } from "react";
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Image,
  Alert,
  ActivityIndicator,
  ScrollView,
} from "react-native";
import * as ImagePicker from "expo-image-picker";
import { useAuth } from "../../src/context/AuthContext";
import { api } from "../../src/services/api";

const CAM_METHODS = ["gradcam", "gradcam_pp", "eigencam", "layercam"];

export default function PatientHome() {
  const { user } = useAuth();
  const [image, setImage] = useState<string | null>(null);
  const [prediction, setPrediction] = useState<any>(null);
  const [explanation, setExplanation] = useState<any>(null);
  const [selectedMethod, setSelectedMethod] = useState("gradcam");
  const [isLoading, setIsLoading] = useState(false);
  const [isExplaining, setIsExplaining] = useState(false);

  const pickImage = async () => {
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      allowsEditing: false,
      quality: 0.8,
    });

    if (!result.canceled && result.assets[0]) {
      setImage(result.assets[0].uri);
      setPrediction(null);
      setExplanation(null);

      // Auto-predict
      setIsLoading(true);
      try {
        const pred = await api.predict(result.assets[0].uri);
        setPrediction(pred);

        // Auto-explain
        const exp = await api.explain(pred.prediction_id, selectedMethod);
        setExplanation(exp);
      } catch (error: any) {
        Alert.alert("Error", error.message);
      } finally {
        setIsLoading(false);
      }
    }
  };

  const handleConsent = async () => {
    if (!prediction) return;

    try {
      await api.submitFeedback(prediction.prediction_id, true);
      Alert.alert("Thank You!", "Your contribution helps improve our AI.");
    } catch (error: any) {
      Alert.alert("Error", error.message);
    }
  };

  return (
    <ScrollView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.greeting}>
          Hello, {user?.full_name || "Patient"}
        </Text>
        <Text style={styles.subtitle}>Upload a dermoscopy image for analysis</Text>
      </View>

      {/* Upload Area */}
      <TouchableOpacity style={styles.uploadArea} onPress={pickImage}>
        {image ? (
          <Image source={{ uri: image }} style={styles.preview} />
        ) : (
          <>
            <Text style={styles.uploadIcon}>📤</Text>
            <Text style={styles.uploadText}>Tap to select image</Text>
            <Text style={styles.uploadHint}>JPG, PNG, or WEBP - max 10MB</Text>
          </>
        )}
      </TouchableOpacity>

      {/* Loading */}
      {isLoading && (
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color="#2563eb" />
          <Text style={styles.loadingText}>Analyzing image...</Text>
        </View>
      )}

      {/* Prediction Result */}
      {prediction && !isLoading && (
        <View style={styles.resultCard}>
          <View style={styles.resultHeader}>
            <Text
              style={[
                styles.diagnosis,
                prediction.diagnosis === "malignant"
                  ? styles.malignant
                  : styles.benign,
              ]}
            >
              {prediction.diagnosis.toUpperCase()}
            </Text>
            <Text style={styles.confidence}>
              {(prediction.confidence * 100).toFixed(0)}% confidence
            </Text>
          </View>

          {/* Confidence Bar */}
          <View style={styles.confidenceBar}>
            <View
              style={[
                styles.confidenceFill,
                {
                  width: `${prediction.confidence * 100}%`,
                  backgroundColor:
                    prediction.diagnosis === "malignant" ? "#ef4444" : "#10b981",
                },
              ]}
            />
          </View>

          {/* Method Selector */}
          <View style={styles.methodContainer}>
            <Text style={styles.methodLabel}>XAI Method:</Text>
            <ScrollView horizontal showsHorizontalScrollIndicator={false}>
              {CAM_METHODS.map((method) => (
                <TouchableOpacity
                  key={method}
                  style={[
                    styles.methodButton,
                    selectedMethod === method && styles.methodButtonActive,
                  ]}
                  onPress={() => setSelectedMethod(method)}
                >
                  <Text
                    style={[
                      styles.methodText,
                      selectedMethod === method && styles.methodTextActive,
                    ]}
                  >
                    {method.toUpperCase()}
                  </Text>
                </TouchableOpacity>
              ))}
            </ScrollView>
          </View>

          {/* Explanation */}
          {explanation && (
            <View style={styles.explanationContainer}>
              <Text style={styles.explanationTitle}>
                Focus Area: {(explanation.metrics.focus_area_percentage * 100).toFixed(1)}%
              </Text>
              <View style={styles.tripleView}>
                <View style={styles.viewItem}>
                  <Text style={styles.viewLabel}>Original</Text>
                  <Image
                    source={{ uri: `data:image/png;base64,${explanation.heatmaps.original}` }}
                    style={styles.viewImage}
                  />
                </View>
                <View style={styles.viewItem}>
                  <Text style={styles.viewLabel}>Heatmap</Text>
                  <Image
                    source={{ uri: `data:image/png;base64,${explanation.heatmaps.heatmap}` }}
                    style={styles.viewImage}
                  />
                </View>
                <View style={styles.viewItem}>
                  <Text style={styles.viewLabel}>Overlay</Text>
                  <Image
                    source={{ uri: `data:image/png;base64,${explanation.heatmaps.overlay}` }}
                    style={styles.viewImage}
                  />
                </View>
              </View>
            </View>
          )}

          {/* Consent */}
          <TouchableOpacity style={styles.consentButton} onPress={handleConsent}>
            <Text style={styles.consentButtonText}>
              Help improve the AI (opt-in)
            </Text>
          </TouchableOpacity>
        </View>
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#f5f5f5",
  },
  header: {
    padding: 20,
    backgroundColor: "#2563eb",
  },
  greeting: {
    fontSize: 24,
    fontWeight: "bold",
    color: "#fff",
  },
  subtitle: {
    fontSize: 14,
    color: "#bfdbfe",
    marginTop: 4,
  },
  uploadArea: {
    margin: 20,
    padding: 40,
    backgroundColor: "#fff",
    borderRadius: 16,
    alignItems: "center",
    borderWidth: 2,
    borderColor: "#e5e5e5",
    borderStyle: "dashed",
  },
  uploadIcon: {
    fontSize: 48,
    marginBottom: 12,
  },
  uploadText: {
    fontSize: 16,
    color: "#333",
    fontWeight: "500",
  },
  uploadHint: {
    fontSize: 12,
    color: "#999",
    marginTop: 4,
  },
  preview: {
    width: "100%",
    height: 200,
    borderRadius: 12,
    resizeMode: "cover",
  },
  loadingContainer: {
    alignItems: "center",
    padding: 40,
  },
  loadingText: {
    marginTop: 12,
    fontSize: 16,
    color: "#666",
  },
  resultCard: {
    margin: 20,
    padding: 20,
    backgroundColor: "#fff",
    borderRadius: 16,
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    elevation: 4,
  },
  resultHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: 16,
  },
  diagnosis: {
    fontSize: 24,
    fontWeight: "bold",
  },
  malignant: {
    color: "#ef4444",
  },
  benign: {
    color: "#10b981",
  },
  confidence: {
    fontSize: 16,
    color: "#666",
  },
  confidenceBar: {
    height: 8,
    backgroundColor: "#e5e5e5",
    borderRadius: 4,
    marginBottom: 16,
  },
  confidenceFill: {
    height: "100%",
    borderRadius: 4,
  },
  methodContainer: {
    marginBottom: 16,
  },
  methodLabel: {
    fontSize: 14,
    color: "#666",
    marginBottom: 8,
  },
  methodButton: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    backgroundColor: "#f5f5f5",
    borderRadius: 20,
    marginRight: 8,
  },
  methodButtonActive: {
    backgroundColor: "#2563eb",
  },
  methodText: {
    fontSize: 12,
    color: "#666",
  },
  methodTextActive: {
    color: "#fff",
    fontWeight: "600",
  },
  explanationContainer: {
    marginTop: 16,
  },
  explanationTitle: {
    fontSize: 14,
    color: "#666",
    marginBottom: 12,
  },
  tripleView: {
    flexDirection: "row",
    justifyContent: "space-between",
  },
  viewItem: {
    flex: 1,
    marginHorizontal: 4,
  },
  viewLabel: {
    fontSize: 10,
    color: "#999",
    textAlign: "center",
    marginBottom: 4,
  },
  viewImage: {
    width: "100%",
    aspectRatio: 1,
    borderRadius: 8,
    backgroundColor: "#f5f5f5",
  },
  consentButton: {
    marginTop: 20,
    padding: 16,
    backgroundColor: "#f5f5f5",
    borderRadius: 12,
    alignItems: "center",
  },
  consentButtonText: {
    fontSize: 14,
    color: "#2563eb",
    fontWeight: "500",
  },
});
```

### History Screen

Create `app/(app)/history.tsx`:

```typescript
import { useState, useEffect } from "react";
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TouchableOpacity,
  RefreshControl,
} from "react-native";
import { useAuth } from "../../src/context/AuthContext";
import { api } from "../../src/services/api";
import { format } from "date-fns";

export default function HistoryScreen() {
  const { user } = useAuth();
  const [predictions, setPredictions] = useState<any[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  const fetchHistory = async () => {
    try {
      const data = await api.getPredictionHistory();
      setPredictions(data);
    } catch (error) {
      console.error("Failed to fetch history:", error);
    } finally {
      setIsLoading(false);
      setRefreshing(false);
    }
  };

  useEffect(() => {
    fetchHistory();
  }, []);

  const onRefresh = () => {
    setRefreshing(true);
    fetchHistory();
  };

  const renderItem = ({ item }: { item: any }) => (
    <TouchableOpacity style={styles.predictionCard}>
      <View style={styles.predictionHeader}>
        <Text
          style={[
            styles.diagnosis,
            item.diagnosis === "malignant" ? styles.malignant : styles.benign,
          ]}
        >
          {item.diagnosis.toUpperCase()}
        </Text>
        <Text style={styles.date}>
          {format(new Date(item.created_at), "MMM d, yyyy")}
        </Text>
      </View>
      <View style={styles.confidenceContainer}>
        <Text style={styles.confidenceLabel}>Confidence</Text>
        <Text style={styles.confidence}>
          {(item.confidence * 100).toFixed(1)}%
        </Text>
      </View>
    </TouchableOpacity>
  );

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Prediction History</Text>
      </View>

      <FlatList
        data={predictions}
        keyExtractor={(item) => item.prediction_id}
        renderItem={renderItem}
        contentContainerStyle={styles.list}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
        }
        ListEmptyComponent={
          !isLoading ? (
            <View style={styles.empty}>
              <Text style={styles.emptyIcon}>📋</Text>
              <Text style={styles.emptyText}>No predictions yet</Text>
            </View>
          ) : null
        }
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#f5f5f5",
  },
  header: {
    padding: 20,
    backgroundColor: "#fff",
    borderBottomWidth: 1,
    borderBottomColor: "#e5e5e5",
  },
  title: {
    fontSize: 18,
    fontWeight: "600",
    color: "#333",
  },
  list: {
    padding: 16,
  },
  predictionCard: {
    backgroundColor: "#fff",
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 4,
    elevation: 2,
  },
  predictionHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: 12,
  },
  diagnosis: {
    fontSize: 16,
    fontWeight: "bold",
  },
  malignant: {
    color: "#ef4444",
  },
  benign: {
    color: "#10b981",
  },
  date: {
    fontSize: 12,
    color: "#999",
  },
  confidenceContainer: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
  },
  confidenceLabel: {
    fontSize: 14,
    color: "#666",
  },
  confidence: {
    fontSize: 14,
    fontWeight: "600",
    color: "#333",
  },
  empty: {
    alignItems: "center",
    padding: 40,
  },
  emptyIcon: {
    fontSize: 48,
    marginBottom: 12,
  },
  emptyText: {
    fontSize: 16,
    color: "#999",
  },
});
```


### Doctor Patient List Screen

Create `app/(app)/patients.tsx`:

```typescript
import { useState, useEffect } from "react";
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TouchableOpacity,
  RefreshControl,
  Image,
  Alert,
} from "react-native";
import { useAuth } from "../../src/context/AuthContext";
import { api } from "../../src/services/api";
import { format } from "date-fns";

interface PendingCase {
  case_id: string;
  prediction_id: string;
  image_url: string;
  ai_diagnosis: string;
  ai_confidence: number;
  created_at: string;
}

export default function PatientsScreen() {
  const { user } = useAuth();
  const [cases, setCases] = useState<PendingCase[]>([]);
  const [selectedCase, setSelectedCase] = useState<PendingCase | null>(null);
  const [doctorDiagnosis, setDoctorDiagnosis] = useState<"benign" | "malignant">("benign");
  const [notes, setNotes] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  const fetchCases = async () => {
    try {
      const data = await api.getPendingPredictions();
      setCases(data);
    } catch (error) {
      console.error("Failed to fetch cases:", error);
    } finally {
      setIsLoading(false);
      setRefreshing(false);
    }
  };

  useEffect(() => {
    fetchCases();
  }, []);

  const onRefresh = () => {
    setRefreshing(true);
    fetchCases();
  };

  const handleSubmitOpinion = async () => {
    if (!selectedCase) return;

    setIsSubmitting(true);
    try {
      await api.submitExpertOpinion(selectedCase.prediction_id, doctorDiagnosis, notes || undefined);
      Alert.alert("Success", "Expert opinion submitted. Case moved to admin review.");
      setSelectedCase(null);
      setNotes("");
      fetchCases();
    } catch (error: any) {
      Alert.alert("Error", error.message || "Failed to submit opinion");
    } finally {
      setIsSubmitting(false);
    }
  };

  const renderCase = ({ item }: { item: PendingCase }) => (
    <TouchableOpacity
      style={[styles.caseCard, selectedCase?.case_id === item.case_id && styles.caseCardSelected]}
      onPress={() => setSelectedCase(item)}
    >
      <Image source={{ uri: item.image_url }} style={styles.caseImage} />
      <View style={styles.caseInfo}>
        <Text style={styles.caseDiagnosis}>
          AI: {item.ai_diagnosis} ({item.ai_confidence.toFixed(0)}%)
        </Text>
        <Text style={styles.caseDate}>
          {format(new Date(item.created_at), "MMM d, yyyy")}
        </Text>
      </View>
    </TouchableOpacity>
  );

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Patient Cases</Text>
        <Text style={styles.subtitle}>{cases.length} pending review</Text>
      </View>

      <View style={styles.content}>
        {/* Case List */}
        <FlatList
          data={cases}
          keyExtractor={(item) => item.case_id}
          renderItem={renderCase}
          contentContainerStyle={styles.list}
          refreshControl={
            <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
          }
          ListEmptyComponent={
            !isLoading ? (
              <View style={styles.empty}>
                <Text style={styles.emptyIcon}>📋</Text>
                <Text style={styles.emptyText}>No cases pending review</Text>
              </View>
            ) : null
          }
        />

        {/* Case Detail Modal */}
        {selectedCase && (
          <View style={styles.detailCard}>
            <Text style={styles.detailTitle}>Review Case</Text>

            <Image source={{ uri: selectedCase.image_url }} style={styles.detailImage} />

            <View style={styles.aiResult}>
              <Text style={styles.aiLabel}>AI Prediction:</Text>
              <Text style={styles.aiDiagnosis}>
                {selectedCase.ai_diagnosis} ({selectedCase.ai_confidence.toFixed(0)}%)
              </Text>
            </View>

            <Text style={styles.inputLabel}>Your Diagnosis:</Text>
            <View style={styles.diagnosisButtons}>
              <TouchableOpacity
                style={[
                  styles.diagnosisButton,
                  doctorDiagnosis === "benign" && styles.diagnosisButtonActive,
                ]}
                onPress={() => setDoctorDiagnosis("benign")}
              >
                <Text style={[
                  styles.diagnosisButtonText,
                  doctorDiagnosis === "benign" && styles.diagnosisButtonTextActive,
                ]}>
                  Benign
                </Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={[
                  styles.diagnosisButton,
                  doctorDiagnosis === "malignant" && styles.diagnosisButtonActiveMalignant,
                ]}
                onPress={() => setDoctorDiagnosis("malignant")}
              >
                <Text style={[
                  styles.diagnosisButtonText,
                  doctorDiagnosis === "malignant" && styles.diagnosisButtonTextActive,
                ]}>
                  Malignant
                </Text>
              </TouchableOpacity>
            </View>

            <TouchableOpacity
              style={styles.submitButton}
              onPress={handleSubmitOpinion}
              disabled={isSubmitting}
            >
              <Text style={styles.submitButtonText}>
                {isSubmitting ? "Submitting..." : "Submit Opinion"}
              </Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={styles.cancelButton}
              onPress={() => setSelectedCase(null)}
            >
              <Text style={styles.cancelButtonText}>Cancel</Text>
            </TouchableOpacity>
          </View>
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#f5f5f5" },
  header: { padding: 20, backgroundColor: "#2563eb" },
  title: { fontSize: 20, fontWeight: "bold", color: "#fff" },
  subtitle: { fontSize: 14, color: "#bfdbfe", marginTop: 4 },
  content: { flex: 1 },
  list: { padding: 16 },
  caseCard: {
    flexDirection: "row",
    backgroundColor: "#fff",
    borderRadius: 12,
    padding: 12,
    marginBottom: 12,
    borderWidth: 2,
    borderColor: "#e5e5e5",
  },
  caseCardSelected: { borderColor: "#2563eb", backgroundColor: "#eff6ff" },
  caseImage: { width: 60, height: 60, borderRadius: 8 },
  caseInfo: { marginLeft: 12, justifyContent: "center" },
  caseDiagnosis: { fontSize: 16, fontWeight: "600", color: "#333" },
  caseDate: { fontSize: 12, color: "#999", marginTop: 4 },
  empty: { alignItems: "center", padding: 40 },
  emptyIcon: { fontSize: 48, marginBottom: 12 },
  emptyText: { fontSize: 16, color: "#999" },
  detailCard: {
    position: "absolute",
    bottom: 0,
    left: 0,
    right: 0,
    backgroundColor: "#fff",
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    padding: 24,
    maxHeight: "80%",
  },
  detailTitle: { fontSize: 20, fontWeight: "bold", color: "#333", marginBottom: 16 },
  detailImage: { width: "100%", height: 200, borderRadius: 12, resizeMode: "cover" },
  aiResult: { flexDirection: "row", justifyContent: "space-between", marginTop: 16 },
  aiLabel: { fontSize: 14, color: "#666" },
  aiDiagnosis: { fontSize: 14, fontWeight: "600" },
  inputLabel: { fontSize: 14, color: "#666", marginTop: 16, marginBottom: 8 },
  diagnosisButtons: { flexDirection: "row", gap: 12 },
  diagnosisButton: {
    flex: 1,
    padding: 16,
    borderRadius: 12,
    borderWidth: 2,
    borderColor: "#e5e5e5",
    alignItems: "center",
  },
  diagnosisButtonActive: { borderColor: "#10b981", backgroundColor: "#ecfdf5" },
  diagnosisButtonActiveMalignant: { borderColor: "#ef4444", backgroundColor: "#fef2f2" },
  diagnosisButtonText: { fontSize: 16, fontWeight: "600", color: "#666" },
  diagnosisButtonTextActive: { color: "#333" },
  submitButton: { backgroundColor: "#2563eb", padding: 16, borderRadius: 12, alignItems: "center", marginTop: 20 },
  submitButtonText: { color: "#fff", fontSize: 16, fontWeight: "600" },
  cancelButton: { padding: 16, alignItems: "center", marginTop: 8 },
  cancelButtonText: { color: "#666", fontSize: 16 },
});
```


### Admin Screen

Create `app/(app)/admin.tsx`:

```typescript
import { useState, useEffect } from "react";
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  Alert,
  ActivityIndicator,
} from "react-native";
import { useAuth } from "../../src/context/AuthContext";
import { api } from "../../src/services/api";

interface AdminStats {
  total_users: number;
  total_patients: number;
  total_doctors: number;
  pending_doctors: number;
  pool_size: number;
  ready_to_retrain: boolean;
}

export default function AdminScreen() {
  const { user } = useAuth();
  const [stats, setStats] = useState<AdminStats | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isRetraining, setIsRetraining] = useState(false);

  const fetchStats = async () => {
    try {
      const data = await api.getAdminStats();
      setStats(data);
    } catch (error) {
      console.error("Failed to fetch stats:", error);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchStats();
  }, []);

  const handleRetrain = async () => {
    setIsRetraining(true);
    try {
      await api.triggerRetraining();
      Alert.alert("Success", "Retraining triggered. Check MLflow for progress.");
    } catch (error: any) {
      Alert.alert("Error", error.message || "Failed to trigger retraining");
    } finally {
      setIsRetraining(false);
    }
  };

  if (isLoading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#2563eb" />
      </View>
    );
  }

  return (
    <ScrollView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Admin Dashboard</Text>
        <Text style={styles.subtitle}>Manage platform and training pool</Text>
      </View>

      {/* Stats Grid */}
      <View style={styles.statsGrid}>
        <View style={styles.statCard}>
          <Text style={styles.statValue}>{stats?.total_users || 0}</Text>
          <Text style={styles.statLabel}>Total Users</Text>
        </View>
        <View style={styles.statCard}>
          <Text style={styles.statValue}>{stats?.total_patients || 0}</Text>
          <Text style={styles.statLabel}>Patients</Text>
        </View>
        <View style={styles.statCard}>
          <Text style={styles.statValue}>{stats?.total_doctors || 0}</Text>
          <Text style={styles.statLabel}>Doctors</Text>
        </View>
        <View style={styles.statCard}>
          <Text style={[styles.statValue, { color: "#f59e0b" }]}>
            {stats?.pending_doctors || 0}
          </Text>
          <Text style={styles.statLabel}>Pending Doctors</Text>
        </View>
      </View>

      {/* Training Pool Section */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Training Pool</Text>

        <View style={styles.poolCard}>
          <View style={styles.poolHeader}>
            <Text style={styles.poolTitle}>Approved Cases</Text>
            <Text style={styles.poolValue}>{stats?.pool_size || 0}</Text>
          </View>

          <View style={styles.progressContainer}>
            <View style={styles.progressBar}>
              <View
                style={[
                  styles.progressFill,
                  { width: `${Math.min(((stats?.pool_size || 0) / 5000) * 100, 100)}%` },
                ]}
              />
            </View>
            <Text style={styles.progressText}>
              {stats?.pool_size || 0} / 5000 (min for retraining)
            </Text>
          </View>

          {stats?.ready_to_retrain ? (
            <View style={styles.readyCard}>
              <Text style={styles.readyText}>Ready for retraining!</Text>
              <TouchableOpacity
                style={styles.retrainButton}
                onPress={handleRetrain}
                disabled={isRetraining}
              >
                <Text style={styles.retrainButtonText}>
                  {isRetraining ? "Triggering..." : "Trigger Batch Retraining"}
                </Text>
              </TouchableOpacity>
            </View>
          ) : (
            <View style={styles.notReadyCard}>
              <Text style={styles.notReadyText}>
                Need {5000 - (stats?.pool_size || 0)} more approved cases
              </Text>
            </View>
          )}
        </View>
      </View>

      {/* Quick Actions */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Quick Actions</Text>

        <View style={styles.actionsGrid}>
          <TouchableOpacity style={styles.actionCard}>
            <Text style={styles.actionIcon}>👨‍⚕️</Text>
            <Text style={styles.actionLabel}>Approve Doctors</Text>
          </TouchableOpacity>

          <TouchableOpacity style={styles.actionCard}>
            <Text style={styles.actionIcon}>📊</Text>
            <Text style={styles.actionLabel}>View Analytics</Text>
          </TouchableOpacity>

          <TouchableOpacity style={styles.actionCard}>
            <Text style={styles.actionIcon}>⚙️</Text>
            <Text style={styles.actionLabel}>Settings</Text>
          </TouchableOpacity>

          <TouchableOpacity style={styles.actionCard}>
            <Text style={styles.actionIcon}>📧</Text>
            <Text style={styles.actionLabel}>Send Notification</Text>
          </TouchableOpacity>
        </View>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#f5f5f5" },
  loadingContainer: { flex: 1, justifyContent: "center", alignItems: "center" },
  header: { padding: 20, backgroundColor: "#2563eb" },
  title: { fontSize: 24, fontWeight: "bold", color: "#fff" },
  subtitle: { fontSize: 14, color: "#bfdbfe", marginTop: 4 },
  statsGrid: {
    flexDirection: "row",
    flexWrap: "wrap",
    padding: 12,
    gap: 12,
  },
  statCard: {
    width: "47%",
    backgroundColor: "#fff",
    borderRadius: 12,
    padding: 16,
    alignItems: "center",
  },
  statValue: { fontSize: 28, fontWeight: "bold", color: "#2563eb" },
  statLabel: { fontSize: 12, color: "#666", marginTop: 4 },
  section: { padding: 16 },
  sectionTitle: { fontSize: 18, fontWeight: "600", color: "#333", marginBottom: 12 },
  poolCard: { backgroundColor: "#fff", borderRadius: 12, padding: 16 },
  poolHeader: { flexDirection: "row", justifyContent: "space-between", marginBottom: 12 },
  poolTitle: { fontSize: 14, color: "#666" },
  poolValue: { fontSize: 24, fontWeight: "bold", color: "#10b981" },
  progressContainer: { marginBottom: 16 },
  progressBar: { height: 8, backgroundColor: "#e5e5e5", borderRadius: 4 },
  progressFill: { height: "100%", backgroundColor: "#10b981", borderRadius: 4 },
  progressText: { fontSize: 12, color: "#999", marginTop: 4, textAlign: "center" },
  readyCard: { alignItems: "center" },
  readyText: { fontSize: 14, color: "#10b981", fontWeight: "600", marginBottom: 12 },
  retrainButton: { backgroundColor: "#10b981", paddingHorizontal: 24, paddingVertical: 12, borderRadius: 8 },
  retrainButtonText: { color: "#fff", fontWeight: "600" },
  notReadyCard: { alignItems: "center" },
  notReadyText: { fontSize: 14, color: "#999" },
  actionsGrid: { flexDirection: "row", flexWrap: "wrap", gap: 12 },
  actionCard: {
    width: "47%",
    backgroundColor: "#fff",
    borderRadius: 12,
    padding: 16,
    alignItems: "center",
  },
  actionIcon: { fontSize: 32, marginBottom: 8 },
  actionLabel: { fontSize: 14, color: "#666", textAlign: "center" },
});
```


### Profile Screen

Create `app/(app)/profile.tsx`:

```typescript
import { useState } from "react";
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Alert,
  ScrollView,
  Switch,
} from "react-native";
import { useAuth } from "../../src/context/AuthContext";

export default function ProfileScreen() {
  const { user, logout } = useAuth();
  const [notifications, setNotifications] = useState(true);
  const [darkMode, setDarkMode] = useState(false);

  const handleLogout = () => {
    Alert.alert(
      "Logout",
      "Are you sure you want to logout?",
      [
        { text: "Cancel", style: "cancel" },
        { text: "Logout", style: "destructive", onPress: logout },
      ]
    );
  };

  const handleDeleteAccount = () => {
    Alert.alert(
      "Delete Account",
      "This action cannot be undone. All your data will be permanently deleted.",
      [
        { text: "Cancel", style: "cancel" },
        {
          text: "Delete",
          style: "destructive",
          onPress: () => {
            Alert.alert("Contact Support", "Please contact support@skinlesion.com to delete your account.");
          },
        },
      ]
    );
  };

  return (
    <ScrollView style={styles.container}>
      <View style={styles.header}>
        <View style={styles.avatar}>
          <Text style={styles.avatarText}>
            {user?.full_name?.charAt(0) || user?.email?.charAt(0) || "?"}
          </Text>
        </View>
        <Text style={styles.name}>{user?.full_name || "User"}</Text>
        <Text style={styles.email}>{user?.email}</Text>
        <View style={styles.roleBadge}>
          <Text style={styles.roleText}>{user?.role?.toUpperCase()}</Text>
        </View>
      </View>

      {/* Account Section */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Account</Text>

        <TouchableOpacity style={styles.menuItem}>
          <Text style={styles.menuLabel}>Edit Profile</Text>
          <Text style={styles.menuArrow}>→</Text>
        </TouchableOpacity>

        <TouchableOpacity style={styles.menuItem}>
          <Text style={styles.menuLabel}>Change Password</Text>
          <Text style={styles.menuArrow}>→</Text>
        </TouchableOpacity>

        {user?.role === "doctor" && (
          <TouchableOpacity style={styles.menuItem}>
            <Text style={styles.menuLabel}>Medical License</Text>
            <Text style={styles.menuValue}>
              {user.medical_license || "Not provided"}
            </Text>
          </TouchableOpacity>
        )}
      </View>

      {/* Preferences Section */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Preferences</Text>

        <View style={styles.menuItem}>
          <Text style={styles.menuLabel}>Push Notifications</Text>
          <Switch
            value={notifications}
            onValueChange={setNotifications}
            trackColor={{ false: "#e5e5e5", true: "#93c5fd" }}
            thumbColor={notifications ? "#2563eb" : "#fff"}
          />
        </View>

        <View style={styles.menuItem}>
          <Text style={styles.menuLabel}>Dark Mode</Text>
          <Switch
            value={darkMode}
            onValueChange={setDarkMode}
            trackColor={{ false: "#e5e5e5", true: "#93c5fd" }}
            thumbColor={darkMode ? "#2563eb" : "#fff"}
          />
        </View>
      </View>

      {/* Privacy Section */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Privacy</Text>

        <TouchableOpacity style={styles.menuItem}>
          <Text style={styles.menuLabel}>Privacy Policy</Text>
          <Text style={styles.menuArrow}>→</Text>
        </TouchableOpacity>

        <TouchableOpacity style={styles.menuItem}>
          <Text style={styles.menuLabel}>Terms of Service</Text>
          <Text style={styles.menuArrow}>→</Text>
        </TouchableOpacity>

        <TouchableOpacity style={styles.menuItem}>
          <Text style={styles.menuLabel}>Export My Data</Text>
          <Text style={styles.menuArrow}>→</Text>
        </TouchableOpacity>
      </View>

      {/* Support Section */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Support</Text>

        <TouchableOpacity style={styles.menuItem}>
          <Text style={styles.menuLabel}>Help Center</Text>
          <Text style={styles.menuArrow}>→</Text>
        </TouchableOpacity>

        <TouchableOpacity style={styles.menuItem}>
          <Text style={styles.menuLabel}>Contact Us</Text>
          <Text style={styles.menuArrow}>→</Text>
        </TouchableOpacity>

        <TouchableOpacity style={styles.menuItem}>
          <Text style={styles.menuLabel}>App Version</Text>
          <Text style={styles.menuValue}>1.0.0</Text>
        </TouchableOpacity>
      </View>

      {/* Danger Zone */}
      <View style={styles.section}>
        <TouchableOpacity style={styles.logoutButton} onPress={handleLogout}>
          <Text style={styles.logoutButtonText}>Logout</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.deleteButton}
          onPress={handleDeleteAccount}
        >
          <Text style={styles.deleteButtonText}>Delete Account</Text>
        </TouchableOpacity>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#f5f5f5" },
  header: { backgroundColor: "#2563eb", padding: 24, alignItems: "center" },
  avatar: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: "#fff",
    justifyContent: "center",
    alignItems: "center",
    marginBottom: 12,
  },
  avatarText: { fontSize: 32, fontWeight: "bold", color: "#2563eb" },
  name: { fontSize: 20, fontWeight: "bold", color: "#fff" },
  email: { fontSize: 14, color: "#bfdbfe", marginTop: 4 },
  roleBadge: {
    backgroundColor: "rgba(255,255,255,0.2)",
    paddingHorizontal: 12,
    paddingVertical: 4,
    borderRadius: 12,
    marginTop: 8,
  },
  roleText: { color: "#fff", fontSize: 12, fontWeight: "600" },
  section: { padding: 16 },
  sectionTitle: { fontSize: 12, fontWeight: "600", color: "#999", marginBottom: 8, textTransform: "uppercase" },
  menuItem: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    backgroundColor: "#fff",
    padding: 16,
    borderRadius: 12,
    marginBottom: 8,
  },
  menuLabel: { fontSize: 16, color: "#333" },
  menuValue: { fontSize: 14, color: "#999" },
  menuArrow: { fontSize: 16, color: "#999" },
  logoutButton: {
    backgroundColor: "#fff",
    padding: 16,
    borderRadius: 12,
    alignItems: "center",
    marginBottom: 8,
  },
  logoutButtonText: { fontSize: 16, color: "#2563eb", fontWeight: "600" },
  deleteButton: {
    backgroundColor: "#fff",
    padding: 16,
    borderRadius: 12,
    alignItems: "center",
  },
  deleteButtonText: { fontSize: 16, color: "#ef4444", fontWeight: "600" },
});
```


### Push Notifications Service

Create `src/services/notifications.ts`:

```typescript
import * as Notifications from "expo-notifications";
import * as Device from "expo-device";
import { Platform } from "react-native";

// Configure notification behavior
Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,
    shouldPlaySound: true,
    shouldSetBadge: true,
  }),
});

export async function registerForPushNotifications(): Promise<string | null> {
  let token: string | null = null;

  if (Platform.OS === "android") {
    await Notifications.setNotificationChannelAsync("default", {
      name: "default",
      importance: Notifications.AndroidImportance.MAX,
      vibrationPattern: [0, 250, 250, 250],
    });
  }

  if (Device.isDevice) {
    const { status: existingStatus } = await Notifications.getPermissionsAsync();
    let finalStatus = existingStatus;

    if (existingStatus !== "granted") {
      const { status } = await Notifications.requestPermissionsAsync();
      finalStatus = status;
    }

    if (finalStatus !== "granted") {
      console.log("Push notification permission not granted");
      return null;
    }

    // Get Expo push token
    const { data: tokenData } = await Notifications.getExpoPushTokenAsync();
    token = tokenData;
  } else {
    console.log("Push notifications require a physical device");
  }

  return token;
}

export async function schedulePushNotification(
  title: string,
  body: string,
  data?: Record<string, unknown>
): Promise<string> {
  return await Notifications.scheduleNotificationAsync({
    content: { title, body, data },
    trigger: null, // Immediate
  });
}

export async function scheduleDelayedNotification(
  title: string,
  body: string,
  seconds: number,
  data?: Record<string, unknown>
): Promise<string> {
  return await Notifications.scheduleNotificationAsync({
    content: { title, body, data },
    trigger: { seconds, type: Notifications.SchedulableTriggerInputTypes.TIME_INTERVAL },
  });
}

export function addNotificationReceivedListener(
  handler: (notification: Notifications.Notification) => void
): Notifications.Subscription {
  return Notifications.addNotificationReceivedListener(handler);
}

export function addNotificationResponseReceivedListener(
  handler: (response: Notifications.NotificationResponse) => void
): Notifications.Subscription {
  return Notifications.addNotificationResponseReceivedListener(handler);
}
```

### Offline Storage Service

Create `src/services/offline-storage.ts`:

```typescript
import AsyncStorage from "@react-native-async-storage/async-storage";

const PREDICTIONS_KEY = "cached_predictions";
const SETTINGS_KEY = "user_settings";

interface CachedPrediction {
  id: string;
  diagnosis: string;
  confidence: number;
  created_at: string;
  cached_at: number;
}

interface CachedSettings {
  notifications_enabled: boolean;
  dark_mode: boolean;
  last_sync: number;
}

export async function cachePrediction(prediction: CachedPrediction): Promise<void> {
  const existing = await getCachedPredictions();
  const updated = [prediction, ...existing.filter(p => p.id !== prediction.id)].slice(0, 100);
  await AsyncStorage.setItem(PREDICTIONS_KEY, JSON.stringify(updated));
}

export async function getCachedPredictions(): Promise<CachedPrediction[]> {
  try {
    const data = await AsyncStorage.getItem(PREDICTIONS_KEY);
    if (!data) return [];

    const predictions: CachedPrediction[] = JSON.parse(data);
    // Filter out predictions older than 7 days
    const sevenDaysAgo = Date.now() - 7 * 24 * 60 * 60 * 1000;
    return predictions.filter(p => p.cached_at > sevenDaysAgo);
  } catch {
    return [];
  }
}

export async function clearPredictionCache(): Promise<void> {
  await AsyncStorage.removeItem(PREDICTIONS_KEY);
}

export async function saveSettings(settings: Partial<CachedSettings>): Promise<void> {
  const existing = await getSettings();
  const updated = { ...existing, ...settings, last_sync: Date.now() };
  await AsyncStorage.setItem(SETTINGS_KEY, JSON.stringify(updated));
}

export async function getSettings(): Promise<CachedSettings> {
  try {
    const data = await AsyncStorage.getItem(SETTINGS_KEY);
    if (!data) {
      return {
        notifications_enabled: true,
        dark_mode: false,
        last_sync: Date.now(),
      };
    }
    return JSON.parse(data);
  } catch {
    return {
      notifications_enabled: true,
      dark_mode: false,
      last_sync: Date.now(),
    };
  }
}
```

---

## Step 9: Build Configuration

### app.json

Update `app.json`:

```json
{
  "expo": {
    "name": "SkinLesion",
    "slug": "SkinLesionMobile",
    "version": "1.0.0",
    "orientation": "portrait",
    "icon": "./assets/icon.png",
    "userInterfaceStyle": "light",
    "splash": {
      "image": "./assets/splash.png",
      "resizeMode": "contain",
      "backgroundColor": "#2563eb"
    },
    "assetBundlePatterns": ["**/*"],
    "ios": {
      "supportsTablet": true,
      "bundleIdentifier": "com.skinlesion.app",
      "infoPlist": {
        "NSCameraUsageDescription": "We need camera access to capture dermoscopy images",
        "NSPhotoLibraryUsageDescription": "We need photo library access to select images"
      }
    },
    "android": {
      "adaptiveIcon": {
        "foregroundImage": "./assets/adaptive-icon.png",
        "backgroundColor": "#2563eb"
      },
      "package": "com.skinlesion.app",
      "permissions": [
        "CAMERA",
        "READ_EXTERNAL_STORAGE",
        "WRITE_EXTERNAL_STORAGE"
      ]
    },
    "plugins": [
      "expo-secure-store",
      [
        "expo-notifications",
        {
          "icon": "./assets/notification-icon.png",
          "color": "#2563eb"
        }
      ]
    ],
    "extra": {
      "eas": {
        "projectId": "your-project-id"
      }
    }
  }
}
```

### EAS Build Configuration

Create `eas.json`:

```json
{
  "cli": {
    "version": ">= 5.0.0"
  },
  "build": {
    "development": {
      "developmentClient": true,
      "distribution": "internal"
    },
    "preview": {
      "distribution": "internal",
      "ios": {
        "simulator": false
      }
    },
    "production": {
      "ios": {
        "simulator": false
      }
    }
  },
  "submit": {
    "production": {
      "ios": {
        "appleTeamId": "your-apple-team-id",
        "ascAppId": "your-app-store-connect-app-id"
      },
      "android": {
        "serviceAccountKeyPath": "./path-to-service-account.json",
        "track": "production"
      }
    }
  }
}
```

---

## Mobile Summary

### Files Created

```
SkinLesionMobile/
├── app/
│   ├── _layout.tsx           # Root layout with AuthProvider
│   ├── index.tsx             # Auth redirect
│   ├── (auth)/
│   │   ├── _layout.tsx
│   │   ├── login.tsx
│   │   └── register.tsx
│   └── (app)/
│       ├── _layout.tsx      # Tab navigator
│       ├── index.tsx        # Patient home
│       ├── history.tsx      # Prediction history
│       ├── patients.tsx     # Doctor patient list
│       ├── admin.tsx        # Admin dashboard
│       └── profile.tsx      # User profile
├── src/
│   ├── context/
│   │   └── AuthContext.tsx
│   ├── services/
│   │   ├── api.ts           # API client
│   │   └── secure-storage.ts # Token storage
│   ├── types/
│   │   └── index.ts
│   └── utils/
│       └── constants.ts
├── app.json                  # Expo config
├── eas.json                  # EAS Build config
└── package.json
```

### Run Commands

```bash
# Start development
npx expo start

# Run on iOS Simulator
npx expo run:ios

# Run on Android Emulator
npx expo run:android

# Build for production
eas build --platform ios
eas build --platform android

# Submit to App Stores
eas submit --platform ios
eas submit --platform android
```

---

## Next Steps

**Phase 4 Complete!**

Next is **Phase 5: CI/CD and Deployment**

Proceed to: `BUILD_PHASE_5_CICD.md`
