import { AppShell } from "@/components/AppShell";

// Korumali alan duzeni. Oturum kontrolu middleware'de yapilir.
export default function ProtectedLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return <AppShell>{children}</AppShell>;
}
